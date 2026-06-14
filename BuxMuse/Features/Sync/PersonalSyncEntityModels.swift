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
    static let currentVersion = 2
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

    var id: String { "\(entityKind):\(entityId)" }

    init(
        entityKind: String,
        entityId: String,
        payloadJSON: String,
        updatedAt: Date,
        deviceId: String,
        contentHash: String,
        isDeleted: Bool = false,
        usesExternalAsset: Bool = false
    ) {
        self.entityKind = entityKind
        self.entityId = entityId
        self.payloadJSON = payloadJSON
        self.updatedAt = updatedAt
        self.deviceId = deviceId
        self.contentHash = contentHash
        self.isDeleted = isDeleted
        self.usesExternalAsset = usesExternalAsset
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

nonisolated struct PersonalSyncManifestPayload: Codable, Equatable, Sendable {
    var schemaVersion: Int
    var dualDeviceReconcileCompletedVersion: Int?
    var lastFullReconcileAt: Date?
    var registeredDeviceIds: [String]
    var updatedAt: Date

    static func fresh(deviceId: String) -> PersonalSyncManifestPayload {
        PersonalSyncManifestPayload(
            schemaVersion: PersonalSyncSchema.currentVersion,
            dualDeviceReconcileCompletedVersion: nil,
            lastFullReconcileAt: nil,
            registeredDeviceIds: [deviceId],
            updatedAt: Date()
        )
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
    static var currentDeviceId: String {
        UIDevice.current.identifierForVendor?.uuidString ?? "buxmuse-device-unknown"
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
