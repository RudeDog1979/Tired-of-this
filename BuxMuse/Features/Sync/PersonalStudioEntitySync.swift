//
//  PersonalStudioEntitySync.swift
//  BuxMuse
//

import Foundation

enum PersonalStudioEntitySync {
    private static let assetByteThreshold = 100_000

    @MainActor
    static func exportAll(from store: StudioStore) -> [PersonalSyncEntityRecord] {
        let snapshot = store.currentSnapshot()
        let revision = store.lastPersistedAt ?? Date()
        let deviceId = PersonalSyncDeviceIdentity.currentDeviceId
        var records: [PersonalSyncEntityRecord] = []

        records.append(makeRecord(
            kind: .profileBundle,
            entityId: "profile-bundle",
            encodable: StudioProfileBundleEntity(
                profile: snapshot.profile,
                taxProfile: snapshot.taxProfile,
                invoiceSettings: snapshot.invoiceSettings
            ),
            revision: revision,
            deviceId: deviceId
        ))

        records.append(makeRecord(
            kind: .taxEnvelope,
            entityId: "tax-envelope",
            encodable: snapshot.taxEnvelope,
            revision: revision,
            deviceId: deviceId
        ))

        records.append(makeRecord(
            kind: .businessCardLibrary,
            entityId: "business-card-library",
            encodable: snapshot.businessCardLibrary,
            revision: revision,
            deviceId: deviceId
        ))

        for client in snapshot.clients {
            records.append(makeRecord(kind: .client, entityId: client.id.uuidString, encodable: client, revision: revision, deviceId: deviceId))
        }
        for invoice in snapshot.invoices {
            records.append(makeRecord(kind: .invoice, entityId: invoice.id.uuidString, encodable: invoice, revision: revision, deviceId: deviceId))
        }
        for project in snapshot.projects {
            records.append(makeRecord(kind: .project, entityId: project.id.uuidString, encodable: project, revision: revision, deviceId: deviceId))
        }
        for receipt in snapshot.receipts {
            records.append(makeRecord(kind: .receipt, entityId: receipt.id.uuidString, encodable: receipt, revision: revision, deviceId: deviceId))
        }
        for draft in snapshot.agreementDrafts {
            records.append(makeRecord(kind: .agreement, entityId: draft.id.uuidString, encodable: draft, revision: revision, deviceId: deviceId))
        }
        for entry in snapshot.mileageEntries {
            records.append(makeRecord(kind: .mileage, entityId: entry.id.uuidString, encodable: entry, revision: revision, deviceId: deviceId))
        }
        return records
    }

    static func merge(
        local: [PersonalSyncEntityRecord],
        remote: [PersonalSyncEntityRecord]
    ) -> (merged: [PersonalSyncEntityRecord], conflicts: [PersonalSyncConflict]) {
        PersonalEntityMergeEngine.mergeEntities(
            local: local,
            remote: remote,
            kind: .studioEntity,
            defaultTitleKey: "Studio item conflict"
        )
    }

    @MainActor
    static func apply(_ records: [PersonalSyncEntityRecord], to store: StudioStore) {
        var snapshot = store.currentSnapshot()

        for record in records where record.entityKind.hasPrefix("studio.") {
            guard !record.isDeleted else {
                removeEntity(record, from: &snapshot)
                continue
            }
            applyEntity(record, to: &snapshot)
        }

        store.apply(snapshot)
        store.save(notifyCloudSync: false)
    }

    static func entityHasUserData(_ record: PersonalSyncEntityRecord) -> Bool {
        guard !record.isDeleted else { return false }
        if record.entityKind == PersonalStudioEntityKind.profileBundle.cloudKind { return record.payloadJSON.count > 80 }
        return record.payloadJSON.count > 24
    }

    static func recordName(for record: PersonalSyncEntityRecord) -> String {
        "personal-studio-\(record.entityKind)-\(record.entityId)"
    }

    // MARK: - Private

    private struct StudioProfileBundleEntity: Codable {
        var profile: StudioProfile
        var taxProfile: StudioTaxProfile
        var invoiceSettings: StudioInvoiceSettings
    }

    private static func makeRecord<T: Encodable>(
        kind: PersonalStudioEntityKind,
        entityId: String,
        encodable: T,
        revision: Date,
        deviceId: String
    ) -> PersonalSyncEntityRecord {
        let encoder = JSONEncoder()
        let data = (try? encoder.encode(encodable)) ?? Data()
        let json = String(data: data, encoding: .utf8) ?? "{}"
        return PersonalSyncEntityRecord(
            entityKind: kind.cloudKind,
            entityId: entityId,
            payloadJSON: json,
            updatedAt: revision,
            deviceId: deviceId,
            contentHash: PersonalSyncContentHash.hash(json: json),
            usesExternalAsset: data.count >= assetByteThreshold
        )
    }

    @MainActor
    private static func applyEntity(_ record: PersonalSyncEntityRecord, to snapshot: inout StudioSnapshot) {
        guard let kind = PersonalStudioEntityKind(cloudKind: record.entityKind) else { return }
        let decoder = JSONDecoder()
        guard let data = record.payloadJSON.data(using: .utf8) else { return }
        switch kind {
        case .profileBundle:
            guard let bundle = try? decoder.decode(StudioProfileBundleEntity.self, from: data) else { return }
            snapshot.profile = bundle.profile
            snapshot.taxProfile = bundle.taxProfile
            snapshot.invoiceSettings = bundle.invoiceSettings
        case .taxEnvelope:
            snapshot.taxEnvelope = (try? decoder.decode(TaxEnvelopeState.self, from: data)) ?? snapshot.taxEnvelope
        case .businessCardLibrary:
            snapshot.businessCardLibrary = (try? decoder.decode(ProBusinessCardLibrary.self, from: data)) ?? snapshot.businessCardLibrary
        case .client:
            upsert(id: record.entityId, in: &snapshot.clients, decode: StudioClient.self, from: data, decoder: decoder)
        case .invoice:
            upsert(id: record.entityId, in: &snapshot.invoices, decode: StudioInvoice.self, from: data, decoder: decoder)
        case .project:
            upsert(id: record.entityId, in: &snapshot.projects, decode: StudioProject.self, from: data, decoder: decoder)
        case .receipt:
            upsert(id: record.entityId, in: &snapshot.receipts, decode: StudioReceipt.self, from: data, decoder: decoder)
        case .agreement:
            upsert(id: record.entityId, in: &snapshot.agreementDrafts, decode: AgreementDraft.self, from: data, decoder: decoder)
        case .mileage:
            upsert(id: record.entityId, in: &snapshot.mileageEntries, decode: MileageEntry.self, from: data, decoder: decoder)
        }
    }

    private static func removeEntity(_ record: PersonalSyncEntityRecord, from snapshot: inout StudioSnapshot) {
        guard let kind = PersonalStudioEntityKind(cloudKind: record.entityKind),
              let uuid = UUID(uuidString: record.entityId) else { return }
        switch kind {
        case .client: snapshot.clients.removeAll { $0.id == uuid }
        case .invoice: snapshot.invoices.removeAll { $0.id == uuid }
        case .project: snapshot.projects.removeAll { $0.id == uuid }
        case .receipt: snapshot.receipts.removeAll { $0.id == uuid }
        case .agreement: snapshot.agreementDrafts.removeAll { $0.id == uuid }
        case .mileage: snapshot.mileageEntries.removeAll { $0.id == uuid }
        default: break
        }
    }

    private static func upsert<T: Codable & Identifiable>(
        id: String,
        in array: inout [T],
        decode: T.Type,
        from data: Data,
        decoder: JSONDecoder
    ) where T.ID == UUID {
        guard let value = try? decoder.decode(T.self, from: data) else { return }
        if let index = array.firstIndex(where: { $0.id.uuidString == id }) {
            array[index] = value
        } else {
            array.append(value)
        }
    }
}

extension PersonalStudioEntityKind {
    var cloudKind: String { "studio.\(rawValue)" }

    init?(cloudKind: String) {
        guard cloudKind.hasPrefix("studio."), let raw = cloudKind.split(separator: ".").last else { return nil }
        self.init(rawValue: String(raw))
    }
}

enum PersonalEntityMergeEngine {
    static func mergeEntities(
        local: [PersonalSyncEntityRecord],
        remote: [PersonalSyncEntityRecord],
        kind: PersonalSyncConflictKind,
        defaultTitleKey: String
    ) -> (merged: [PersonalSyncEntityRecord], conflicts: [PersonalSyncConflict]) {
        var byKey: [String: PersonalSyncEntityRecord] = Dictionary(uniqueKeysWithValues: local.map { ($0.id, $0) })
        var conflicts: [PersonalSyncConflict] = []

        for remoteRecord in remote {
            let key = remoteRecord.id
            guard let localRecord = byKey[key] else {
                byKey[key] = remoteRecord
                continue
            }
            let localHas = localRecord.payloadJSON.count > 12 && !localRecord.isDeleted
            let remoteHas = remoteRecord.payloadJSON.count > 12 && !remoteRecord.isDeleted
            if localHas && !remoteHas { continue }
            if !localHas && remoteHas {
                byKey[key] = remoteRecord
                continue
            }
            if remoteRecord.isDeleted && !localRecord.isDeleted && remoteRecord.updatedAt >= localRecord.updatedAt {
                byKey[key] = remoteRecord
                continue
            }
            if remoteRecord.updatedAt > localRecord.updatedAt {
                byKey[key] = remoteRecord
            } else if remoteRecord.updatedAt < localRecord.updatedAt {
                continue
            } else if remoteRecord.contentHash != localRecord.contentHash {
                conflicts.append(
                    PersonalSyncConflict(
                        kind: kind,
                        entityKey: key,
                        titleKey: defaultTitleKey,
                        localUpdatedAt: localRecord.updatedAt,
                        remoteUpdatedAt: remoteRecord.updatedAt,
                        localSummary: localRecord.entityId,
                        remoteSummary: remoteRecord.entityId
                    )
                )
            }
        }
        return (Array(byKey.values), conflicts)
    }

    static func shouldApplyRemote(
        remote: PersonalSyncEntityRecord,
        local: PersonalSyncEntityRecord?,
        localHasContent: Bool,
        remoteHasContent: Bool
    ) -> Bool {
        guard let local else { return remoteHasContent || remote.isDeleted }
        if localHasContent && !remoteHasContent && !remote.isDeleted { return false }
        if !localHasContent && remoteHasContent { return true }
        if remote.isDeleted { return remote.updatedAt >= local.updatedAt }
        return remote.updatedAt >= local.updatedAt
    }

    static func shouldPushLocal(
        local: PersonalSyncEntityRecord,
        remote: PersonalSyncEntityRecord?
    ) -> Bool {
        guard !local.isDeleted else { return true }
        guard local.payloadJSON.count > 12 else { return false }
        guard let remote else { return true }
        let remoteHas = remote.payloadJSON.count > 12 && !remote.isDeleted
        if !remoteHas { return true }
        return local.updatedAt > remote.updatedAt
    }
}
