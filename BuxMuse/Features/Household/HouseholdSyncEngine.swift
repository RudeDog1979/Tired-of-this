//
//  HouseholdSyncEngine.swift
//  BuxMuse
//  Features/Household/
//
//  CloudKit household sharing — create/join, push shared expenses, pull changes.
//

import CloudKit
import SwiftUI
import UIKit
import Combine

@MainActor
final class HouseholdSyncEngine: ObservableObject {
    static let shared = HouseholdSyncEngine()

    static let containerIdentifier = "iCloud.com.buxmuse.app"

    @Published private(set) var syncStatus: HouseholdSyncStatus = .notConfigured
    @Published private(set) var isHouseholdActive = false

    private let container: CKContainer
    private let privateDatabase: CKDatabase
    private let sharedDatabase: CKDatabase
    private var brain: BuxMuseBrain?
    private var settingsStore: SettingsStore { SettingsStore.shared }

    private init() {
        container = CKContainer(identifier: Self.containerIdentifier)
        privateDatabase = container.privateCloudDatabase
        sharedDatabase = container.sharedCloudDatabase
        refreshHouseholdStateFromSettings()
    }

    func attach(brain: BuxMuseBrain) {
        self.brain = brain
        Task { await bootstrapIfNeeded() }
    }

    func refreshHouseholdStateFromSettings() {
        isHouseholdActive = settingsStore.householdCloudRecordName != nil
        if !isHouseholdActive {
            syncStatus = .notConfigured
        }
    }

    // MARK: - Account

    func checkAccountStatus() async -> HouseholdSyncStatus {
        do {
            let status = try await container.accountStatus()
            switch status {
            case .available:
                if isHouseholdActive {
                    syncStatus = .idle
                } else {
                    syncStatus = .notConfigured
                }
            case .noAccount:
                syncStatus = .noAccount
            case .restricted, .temporarilyUnavailable:
                syncStatus = .error("iCloud is temporarily unavailable.")
            case .couldNotDetermine:
                syncStatus = .error("Could not verify iCloud account.")
            @unknown default:
                syncStatus = .error("Unknown iCloud status.")
            }
        } catch {
            syncStatus = .error(error.localizedDescription)
        }
        return syncStatus
    }

    private func bootstrapIfNeeded() async {
        _ = await checkAccountStatus()
        guard isHouseholdActive else { return }
        await pullRemoteChanges()
    }

    // MARK: - Create household

    func createHousehold(displayName: String) async throws -> URL {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw HouseholdSyncError.invalidName
        }

        syncStatus = .syncing
        let recordID = CKRecord.ID(recordName: UUID().uuidString)
        let record = CKRecord(recordType: HouseholdCloudRecordType.household, recordID: recordID)
        record[HouseholdCloudField.displayName] = trimmed as CKRecordValue

        let saved = try await privateDatabase.save(record)
        let share = CKShare(rootRecord: saved)
        share[CKShare.SystemFieldKey.title] = trimmed as CKRecordValue
        share.publicPermission = .none

        _ = try await privateDatabase.modifyRecords(saving: [saved, share], deleting: [])

        settingsStore.householdCloudRecordName = saved.recordID.recordName
        settingsStore.householdDisplayName = trimmed
        settingsStore.householdSharedZoneName = saved.recordID.zoneID.zoneName
        settingsStore.householdSharedZoneOwner = saved.recordID.zoneID.ownerName
        settingsStore.save()
        isHouseholdActive = true
        syncStatus = .lastSynced(Date())

        guard let url = share.url else {
            throw HouseholdSyncError.missingShareURL
        }
        settingsStore.householdShareURL = url.absoluteString
        settingsStore.save()
        return url
    }

    // MARK: - Join / invite

    func acceptShare(metadata: CKShare.Metadata) async throws {
        _ = try await container.accept(metadata)
        guard let rootID = metadata.hierarchicalRootRecordID else {
            throw HouseholdSyncError.missingShareRoot
        }
        settingsStore.householdCloudRecordName = rootID.recordName
        settingsStore.householdSharedZoneName = rootID.zoneID.zoneName
        settingsStore.householdSharedZoneOwner = rootID.zoneID.ownerName
        if let shareTitle = metadata.share[CKShare.SystemFieldKey.title] as? String {
            settingsStore.householdDisplayName = shareTitle
        }
        if let url = metadata.share.url {
            settingsStore.householdShareURL = url.absoluteString
        }
        settingsStore.save()
        isHouseholdActive = true
        syncStatus = .lastSynced(Date())
        await pullRemoteChanges()
    }

    func leaveHousehold() async {
        settingsStore.householdCloudRecordName = nil
        settingsStore.householdShareURL = nil
        settingsStore.householdDisplayName = nil
        settingsStore.sharedEnvelopeProfileId = nil
        settingsStore.householdSharedZoneName = nil
        settingsStore.householdSharedZoneOwner = nil
        settingsStore.save()
        isHouseholdActive = false
        syncStatus = .notConfigured
    }

    // MARK: - Push shared expense

    func pushSharedExpenseIfNeeded(_ record: ExpenseRecord) async {
        guard record.householdScope == .shared else { return }
        guard isHouseholdActive else { return }
        guard let zoneID = activeSharedZoneID() else { return }

        syncStatus = .syncing
        let deviceName = UIDevice.current.name
        let payload = SharedExpensePayload(from: record, authorDeviceName: deviceName)
        guard let json = try? JSONEncoder().encode(payload) else { return }

        let recordID = CKRecord.ID(recordName: "expense-\(record.id.uuidString)", zoneID: zoneID)
        let cloudRecord = CKRecord(recordType: HouseholdCloudRecordType.sharedExpense, recordID: recordID)
        cloudRecord[HouseholdCloudField.expenseId] = record.id.uuidString as CKRecordValue
        cloudRecord[HouseholdCloudField.payloadJSON] = String(data: json, encoding: .utf8) as CKRecordValue?
        cloudRecord[HouseholdCloudField.updatedAt] = record.updatedAt as CKRecordValue

        do {
            _ = try await sharedDatabase.save(cloudRecord)
            syncStatus = .lastSynced(Date())
        } catch {
            syncStatus = .error(error.localizedDescription)
        }
    }

    // MARK: - Pull remote changes

    func pullRemoteChanges() async {
        guard isHouseholdActive, let brain else { return }
        guard let zoneID = activeSharedZoneID() else { return }

        syncStatus = .syncing
        let predicate = NSPredicate(value: true)
        let query = CKQuery(recordType: HouseholdCloudRecordType.sharedExpense, predicate: predicate)

        do {
            let (results, _) = try await sharedDatabase.records(matching: query, inZoneWith: zoneID)
            for (_, result) in results {
                guard case .success(let record) = result,
                      let jsonString = record[HouseholdCloudField.payloadJSON] as? String,
                      let data = jsonString.data(using: .utf8),
                      let payload = try? JSONDecoder().decode(SharedExpensePayload.self, from: data) else {
                    continue
                }
                let local = payload.toExpenseRecord()
                if let existing = try? brain.fetchExpenseRecord(id: local.id),
                   existing.updatedAt >= local.updatedAt {
                    continue
                }
                _ = try? brain.saveExpenseRecord(local, merchantSelection: nil)
            }
            await pullSharedEnvelopeProfile(zoneID: zoneID)
            syncStatus = .lastSynced(Date())
        } catch {
            syncStatus = .error(error.localizedDescription)
        }
    }

    func syncNow() async {
        await pullRemoteChanges()
    }

    // MARK: - Shared envelope profile

    func pushSharedEnvelopeProfile() async {
        guard isHouseholdActive else { return }
        guard let zoneID = activeSharedZoneID() else { return }
        guard let profileId = settingsStore.sharedEnvelopeProfileId,
              let profile = settingsStore.customBudgetProfiles.first(where: { $0.id == profileId }),
              let json = try? JSONEncoder().encode(profile) else { return }

        syncStatus = .syncing
        let recordID = CKRecord.ID(recordName: "envelope-profile", zoneID: zoneID)
        let record = CKRecord(recordType: HouseholdCloudRecordType.envelopeProfile, recordID: recordID)
        record[HouseholdCloudField.profileId] = profileId.uuidString as CKRecordValue
        record[HouseholdCloudField.profileJSON] = String(data: json, encoding: .utf8) as CKRecordValue?
        record[HouseholdCloudField.updatedAt] = Date() as CKRecordValue

        do {
            _ = try await sharedDatabase.save(record)
            syncStatus = .lastSynced(Date())
        } catch {
            syncStatus = .error(error.localizedDescription)
        }
    }

    private func pullSharedEnvelopeProfile(zoneID: CKRecordZone.ID) async {
        let recordID = CKRecord.ID(recordName: "envelope-profile", zoneID: zoneID)
        do {
            let record = try await sharedDatabase.record(for: recordID)
            guard let jsonString = record[HouseholdCloudField.profileJSON] as? String,
                  let data = jsonString.data(using: .utf8),
                  let profile = try? JSONDecoder().decode(CustomBudgetProfile.self, from: data) else {
                return
            }
            var profiles = settingsStore.customBudgetProfiles
            if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
                profiles[index] = profile
            } else {
                profiles.append(profile)
            }
            settingsStore.customBudgetProfiles = profiles
            settingsStore.save()
        } catch let error as CKError where error.code == .unknownItem {
            return
        } catch {
            syncStatus = .error(error.localizedDescription)
        }
    }

    // MARK: - Helpers

    private func activeSharedZoneID() -> CKRecordZone.ID? {
        guard let zoneName = settingsStore.householdSharedZoneName,
              let owner = settingsStore.householdSharedZoneOwner else {
            return nil
        }
        return CKRecordZone.ID(zoneName: zoneName, ownerName: owner)
    }

    var inviteShareURL: URL? {
        guard let raw = settingsStore.householdShareURL else { return nil }
        return URL(string: raw)
    }
}

enum HouseholdSyncError: LocalizedError {
    case invalidName
    case missingShareURL
    case missingShareRoot

    var errorDescription: String? {
        switch self {
        case .invalidName: return "Enter a household name."
        case .missingShareURL: return "Could not create invite link."
        case .missingShareRoot: return "Could not read household share details from iCloud."
        }
    }
}
