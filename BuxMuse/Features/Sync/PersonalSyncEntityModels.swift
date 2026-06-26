//
//  PersonalSyncEntityModels.swift
//  BuxMuse
//
//  Entity-first iCloud sync models — settings domains, studio entities, manifest, conflicts.
//

import CryptoKit
import Foundation
import UIKit

// MARK: - Schema

nonisolated enum PersonalSyncSchema {
    static let currentVersion = 3
}

// MARK: - Generic entity envelope

nonisolated struct PersonalSyncEntityRecord: Codable, Equatable, Identifiable, Sendable {
    var entityKind: String
    var entityId: String
    var payloadJSON: String
    var updatedAt: Date
    var deviceId: String
    var contentHash: String
    var isDeleted: Bool
    /// When non-nil, large binary lives in CKAsset field `payloadAsset`.
    var usesExternalAsset: Bool
    /// In-memory binary attachment for push/pull; not persisted in conflict JSON.
    var attachmentData: Data?

    var id: String { "\(entityKind):\(entityId)" }

    enum CodingKeys: String, CodingKey {
        case entityKind
        case entityId
        case payloadJSON
        case updatedAt
        case deviceId
        case contentHash
        case isDeleted
        case usesExternalAsset
    }

    init(
        entityKind: String,
        entityId: String,
        payloadJSON: String,
        updatedAt: Date,
        deviceId: String,
        contentHash: String,
        isDeleted: Bool = false,
        usesExternalAsset: Bool = false,
        attachmentData: Data? = nil
    ) {
        self.entityKind = entityKind
        self.entityId = entityId
        self.payloadJSON = payloadJSON
        self.updatedAt = updatedAt
        self.deviceId = deviceId
        self.contentHash = contentHash
        self.isDeleted = isDeleted
        self.usesExternalAsset = usesExternalAsset
        self.attachmentData = attachmentData
    }

    static func == (lhs: PersonalSyncEntityRecord, rhs: PersonalSyncEntityRecord) -> Bool {
        lhs.entityKind == rhs.entityKind
            && lhs.entityId == rhs.entityId
            && lhs.payloadJSON == rhs.payloadJSON
            && lhs.updatedAt == rhs.updatedAt
            && lhs.deviceId == rhs.deviceId
            && lhs.contentHash == rhs.contentHash
            && lhs.isDeleted == rhs.isDeleted
            && lhs.usesExternalAsset == rhs.usesExternalAsset
    }
}

// MARK: - Settings domains

enum PersonalSettingsDomainID: String, Codable, CaseIterable, Sendable {
    case profile
    case regional
    case appearance
    case budget
    case studioFlags
    case debt
    case notifications
    case security
    case household
    case dataBackup
    case featureFlags
    case greeting
    case subscriptions
}

nonisolated struct PersonalSettingsDomainRecord: Codable, Equatable, Identifiable, Sendable {
    let domainId: String
    var data: Data
    var updatedAt: Date
    var deviceId: String
    var contentHash: String

    var id: String { domainId }

    init(domain: PersonalSettingsDomainID, data: Data, updatedAt: Date, deviceId: String, contentHash: String) {
        self.domainId = domain.rawValue
        self.data = data
        self.updatedAt = updatedAt
        self.deviceId = deviceId
        self.contentHash = contentHash
    }
}

// MARK: - Studio entity kinds

enum PersonalStudioEntityKind: String, Codable, CaseIterable {
    case profileBundle
    case client
    case invoice
    case project
    case receipt
    case agreement
    case agreementFile
    case mileage
    case taxEnvelope
    case businessCardLibrary
}

enum PersonalSimpleStudioEntityKind: String, Codable, CaseIterable {
    case entry
    case customer
    case invoice
    case businessCard
    case hourlyRateHint
}

enum PersonalHustleEntityKind: String {
    case hustle
    case selection
}

// MARK: - Manifest

nonisolated struct PersonalCloudBackupSummary: Equatable, Sendable {
    var lastBackupAt: Date?
    var expenseRecordCount: Int
    var hasConfiguredSettings: Bool
    var registeredDeviceCount: Int
    var sourceDeviceName: String?
    var recommendedSourceDeviceId: String?
    var registeredDevices: [PersonalSyncRegisteredDevice]

    init(
        lastBackupAt: Date?,
        expenseRecordCount: Int,
        hasConfiguredSettings: Bool,
        registeredDeviceCount: Int,
        sourceDeviceName: String?,
        recommendedSourceDeviceId: String? = nil,
        registeredDevices: [PersonalSyncRegisteredDevice] = []
    ) {
        self.lastBackupAt = lastBackupAt
        self.expenseRecordCount = expenseRecordCount
        self.hasConfiguredSettings = hasConfiguredSettings
        self.registeredDeviceCount = registeredDeviceCount
        self.sourceDeviceName = sourceDeviceName
        self.recommendedSourceDeviceId = recommendedSourceDeviceId
        self.registeredDevices = registeredDevices
    }

    var hasBackupContent: Bool {
        expenseRecordCount > 0
            || hasConfiguredSettings
            || !registeredDevices.isEmpty
            || lastBackupAt != nil
    }

    var sortedDevices: [PersonalSyncRegisteredDevice] {
        registeredDevices.sorted { $0.lastSeenAt > $1.lastSeenAt }
    }

    /// Other devices in the shared backup — excludes this iPad/iPhone.
    func peerDevices(excludingDeviceId: String) -> [PersonalSyncRegisteredDevice] {
        sortedDevices.filter { $0.deviceId != excludingDeviceId }
    }

    func displayName(for device: PersonalSyncRegisteredDevice) -> String {
        let nameCount = registeredDevices.filter { $0.name == device.name }.count
        guard nameCount > 1 else { return device.name }
        return "\(device.name) (\(String(device.deviceId.suffix(4))))"
    }
}

nonisolated struct PersonalSyncRegisteredDevice: Codable, Equatable, Sendable {
    var deviceId: String
    var name: String
    var lastSeenAt: Date
}

nonisolated struct PersonalSyncManifestPayload: Codable, Equatable, Sendable {
    var schemaVersion: Int
    var dualDeviceReconcileCompletedVersion: Int?
    var lastFullReconcileAt: Date?
    var registeredDeviceIds: [String]
    var registeredDevices: [PersonalSyncRegisteredDevice]
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case dualDeviceReconcileCompletedVersion
        case lastFullReconcileAt
        case registeredDeviceIds
        case registeredDevices
        case updatedAt
    }

    init(
        schemaVersion: Int,
        dualDeviceReconcileCompletedVersion: Int?,
        lastFullReconcileAt: Date?,
        registeredDeviceIds: [String],
        registeredDevices: [PersonalSyncRegisteredDevice],
        updatedAt: Date
    ) {
        self.schemaVersion = schemaVersion
        self.dualDeviceReconcileCompletedVersion = dualDeviceReconcileCompletedVersion
        self.lastFullReconcileAt = lastFullReconcileAt
        self.registeredDeviceIds = registeredDeviceIds
        self.registeredDevices = registeredDevices
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedUpdatedAt = try container.decode(Date.self, forKey: .updatedAt)
        let decodedDeviceIds = try container.decodeIfPresent([String].self, forKey: .registeredDeviceIds) ?? []
        let decodedDevices: [PersonalSyncRegisteredDevice]
        if let devices = try container.decodeIfPresent([PersonalSyncRegisteredDevice].self, forKey: .registeredDevices) {
            decodedDevices = devices
        } else {
            decodedDevices = decodedDeviceIds.map { deviceId in
                PersonalSyncRegisteredDevice(
                    deviceId: deviceId,
                    name: PersonalSyncDeviceIdentity.legacyDeviceLabel,
                    lastSeenAt: decodedUpdatedAt
                )
            }
        }
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        dualDeviceReconcileCompletedVersion = try container.decodeIfPresent(Int.self, forKey: .dualDeviceReconcileCompletedVersion)
        lastFullReconcileAt = try container.decodeIfPresent(Date.self, forKey: .lastFullReconcileAt)
        updatedAt = decodedUpdatedAt
        registeredDevices = decodedDevices
        registeredDeviceIds = decodedDeviceIds.isEmpty ? decodedDevices.map(\.deviceId) : decodedDeviceIds
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encodeIfPresent(dualDeviceReconcileCompletedVersion, forKey: .dualDeviceReconcileCompletedVersion)
        try container.encodeIfPresent(lastFullReconcileAt, forKey: .lastFullReconcileAt)
        try container.encode(registeredDevices.map(\.deviceId), forKey: .registeredDeviceIds)
        try container.encode(registeredDevices, forKey: .registeredDevices)
        try container.encode(updatedAt, forKey: .updatedAt)
    }

    static func fresh(deviceId: String, deviceName: String) -> PersonalSyncManifestPayload {
        let now = Date()
        let device = PersonalSyncRegisteredDevice(deviceId: deviceId, name: deviceName, lastSeenAt: now)
        return PersonalSyncManifestPayload(
            schemaVersion: PersonalSyncSchema.currentVersion,
            dualDeviceReconcileCompletedVersion: nil,
            lastFullReconcileAt: nil,
            registeredDeviceIds: [deviceId],
            registeredDevices: [device],
            updatedAt: now
        )
    }

    func registeringDevice(id deviceId: String, name deviceName: String, at date: Date = Date()) -> PersonalSyncManifestPayload {
        var manifest = self
        if let index = manifest.registeredDevices.firstIndex(where: { $0.deviceId == deviceId }) {
            manifest.registeredDevices[index].name = deviceName
            manifest.registeredDevices[index].lastSeenAt = date
        } else {
            manifest.registeredDevices.append(
                PersonalSyncRegisteredDevice(deviceId: deviceId, name: deviceName, lastSeenAt: date)
            )
        }
        manifest.registeredDeviceIds = manifest.registeredDevices.map(\.deviceId)
        return manifest
    }

    func preferredBackupSourceDevice(excludingDeviceId: String? = nil) -> PersonalSyncRegisteredDevice? {
        registeredDevices
            .filter { excludingDeviceId == nil || $0.deviceId != excludingDeviceId }
            .max(by: { $0.lastSeenAt < $1.lastSeenAt })
    }
}

// MARK: - Conflicts

enum PersonalSyncConflictKind: String, Codable {
    case settingsDomain
    case studioEntity
    case simpleStudioEntity
    case hustleEntity
    case expense
    case debt
    case goal
}

nonisolated struct PersonalSyncConflict: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let kind: PersonalSyncConflictKind
    let entityKey: String
    let titleKey: String
    let localUpdatedAt: Date
    let remoteUpdatedAt: Date
    let localSummary: String
    let remoteSummary: String
    var isResolved: Bool

    init(
        id: UUID = UUID(),
        kind: PersonalSyncConflictKind,
        entityKey: String,
        titleKey: String,
        localUpdatedAt: Date,
        remoteUpdatedAt: Date,
        localSummary: String,
        remoteSummary: String,
        isResolved: Bool = false
    ) {
        self.id = id
        self.kind = kind
        self.entityKey = entityKey
        self.titleKey = titleKey
        self.localUpdatedAt = localUpdatedAt
        self.remoteUpdatedAt = remoteUpdatedAt
        self.localSummary = localSummary
        self.remoteSummary = remoteSummary
        self.isResolved = isResolved
    }
}

// MARK: - CloudKit record types

enum PersonalCloudRecordType {
    static let expense = "BuxPersonalExpense"
    static let debt = "BuxPersonalDebt"
    static let goal = "BuxPersonalGoal"
    static let settings = "BuxPersonalSettings"
    static let settingsDomain = "BuxPersonalSettingsDomain"
    static let studio = "BuxPersonalStudio"
    static let studioEntity = "BuxPersonalStudioEntity"
    static let simpleStudio = "BuxPersonalSimpleStudio"
    static let simpleStudioEntity = "BuxPersonalSimpleStudioEntity"
    static let hustles = "BuxPersonalHustles"
    static let hustleEntity = "BuxPersonalHustleEntity"
    static let manifest = "BuxPersonalSyncManifest"
}

enum PersonalCloudField {
    static let entityId = "entityId"
    static let entityKind = "entityKind"
    static let domainId = "domainId"
    static let payloadJSON = "payloadJSON"
    static let payloadAsset = "payloadAsset"
    static let updatedAt = "updatedAt"
    static let deviceId = "deviceId"
    static let contentHash = "contentHash"
    static let isDeleted = "isDeleted"
}

enum PersonalSyncDeviceIdentity {
    nonisolated static let legacyDeviceLabel = "Synced device"

    @MainActor
    static var currentDeviceId: String {
        UIDevice.current.identifierForVendor?.uuidString ?? "buxmuse-device-unknown"
    }

    @MainActor
    static var currentDeviceName: String {
        let trimmed = UIDevice.current.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? legacyDeviceLabel : trimmed
    }
}

enum PersonalSyncContentHash {
    static func hash(data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    static func hash(json: String) -> String {
        hash(data: Data(json.utf8))
    }
}
