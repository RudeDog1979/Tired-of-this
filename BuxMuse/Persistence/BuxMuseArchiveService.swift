//
//  BuxMuseArchiveService.swift
//  BuxMuse
//
//  Encrypted full-app backup & restore (.buxmuse archive).
//
//  v1 (BUXMUSE1): password-only AES-GCM
//  v2 (BUXMUSE2): random content key wrapped by password AND recovery key (dual unlock)
//

import Foundation
import CryptoKit

public struct BuxMuseArchiveManifest: Codable, Equatable {
    public var formatVersion: Int
    public var appVersion: String
    public var createdAt: Date
    public var transactionCount: Int
    public var goalCount: Int
    public var includesStudio: Bool
}

public struct BuxMuseArchivePayload: Codable {
    public var manifest: BuxMuseArchiveManifest
    public var settingsData: Data
    public var featureFlags: [String: Bool]
    public var hustles: [Hustle]
    public var selectedHustleId: UUID?
    public var transactions: [Transaction]
    public var goals: [Goal]
    public var studioSnapshot: StudioSnapshot?
    public var simpleStudioSnapshot: SimpleStudioSnapshot?
}

public enum BuxMuseArchiveError: LocalizedError {
    case invalidPassword
    case corruptArchive
    case unsupportedVersion
    case emptyArchive

    public var errorDescription: String? {
        switch self {
        case .invalidPassword: return "Incorrect password or recovery key."
        case .corruptArchive: return "This backup file could not be read."
        case .unsupportedVersion: return "This backup was made with a newer BuxMuse version."
        case .emptyArchive: return "Nothing to back up yet."
        }
    }
}

public enum BuxMuseArchiveStep: String, CaseIterable, Identifiable {
    case collecting = "Collecting your data"
    case packaging = "Packaging archive"
    case encrypting = "Encrypting with your password"
    case writing = "Saving backup file"
    case validate = "Validating archive"
    case settings = "Restoring settings"
    case expenses = "Restoring expenses"
    case goals = "Restoring goals"
    case studio = "Restoring Studio"
    case finalize = "Finalizing"

    public var id: String { rawValue }

    public var isBackupStep: Bool {
        switch self {
        case .collecting, .packaging, .encrypting, .writing: return true
        default: return false
        }
    }
}

@MainActor
public enum BuxMuseArchiveService {
    private static let headerV1 = Data("BUXMUSE1".utf8)
    private static let headerV2 = Data("BUXMUSE2".utf8)
    private static let envelopeVersionV2: UInt8 = 1

    public static func buildPayload(
        settings: SettingsStore,
        hustles: [Hustle],
        selectedHustleId: UUID?,
        transactions: [Transaction],
        goals: [Goal],
        studioSnapshot: StudioSnapshot?,
        simpleSnapshot: SimpleStudioSnapshot?
    ) throws -> BuxMuseArchivePayload {
        guard let settingsData = settings.exportArchiveSettingsData() else {
            throw BuxMuseArchiveError.corruptArchive
        }

        return BuxMuseArchivePayload(
            manifest: BuxMuseArchiveManifest(
                formatVersion: 2,
                appVersion: "1.0.0",
                createdAt: Date(),
                transactionCount: transactions.count,
                goalCount: goals.count,
                includesStudio: studioSnapshot != nil
            ),
            settingsData: settingsData,
            featureFlags: settings.exportFeatureFlagsForArchive(),
            hustles: hustles,
            selectedHustleId: selectedHustleId,
            transactions: transactions,
            goals: goals,
            studioSnapshot: studioSnapshot,
            simpleStudioSnapshot: simpleSnapshot
        )
    }

    /// Encrypts with optional recovery key (v2). Recovery key is returned once — never stored by BuxMuse.
    public static func encrypt(
        _ payload: BuxMuseArchivePayload,
        password: String,
        includeRecoveryKey: Bool = true
    ) throws -> BuxMuseBackupResult {
        let plain = try JSONEncoder().encode(payload)

        if includeRecoveryKey {
            let contentKey = SymmetricKey(size: .bits256)
            guard let sealedPayload = try AES.GCM.seal(plain, using: contentKey).combined else {
                throw BuxMuseArchiveError.corruptArchive
            }

            let keyData = contentKey.withUnsafeBytes { Data($0) }
            let passwordWrap = try wrapKey(keyData, using: deriveKey(from: password))
            let recoveryKey = BuxMuseRecoveryKey.generate()
            let recoveryWrap = try wrapKey(keyData, using: deriveKey(from: BuxMuseRecoveryKey.normalized(recoveryKey)))

            var envelope = headerV2
            envelope.append(envelopeVersionV2)
            appendUInt16(&envelope, passwordWrap.count)
            appendUInt16(&envelope, recoveryWrap.count)
            envelope.append(passwordWrap)
            envelope.append(recoveryWrap)
            envelope.append(sealedPayload)

            return BuxMuseBackupResult(
                archiveData: envelope,
                recoveryKey: recoveryKey,
                usesRecoveryKey: true
            )
        }

        let sealed = try AES.GCM.seal(plain, using: deriveKey(from: password))
        guard let combined = sealed.combined else { throw BuxMuseArchiveError.corruptArchive }
        var envelope = headerV1
        envelope.append(combined)
        return BuxMuseBackupResult(archiveData: envelope, recoveryKey: nil, usesRecoveryKey: false)
    }

    /// Legacy convenience — password-only v1-style call sites.
    public static func encrypt(_ payload: BuxMuseArchivePayload, password: String) throws -> Data {
        try encrypt(payload, password: password, includeRecoveryKey: true).archiveData
    }

    /// Unlocks with password OR recovery key (v2), or password only (v1).
    public static func decrypt(_ data: Data, secret: String) throws -> BuxMuseArchivePayload {
        if data.count > headerV2.count, data.prefix(headerV2.count) == headerV2 {
            return try decryptV2(data, secret: secret)
        }
        if data.count > headerV1.count, data.prefix(headerV1.count) == headerV1 {
            return try decryptV1(data, secret: secret)
        }
        throw BuxMuseArchiveError.corruptArchive
    }

    public static func decrypt(_ data: Data, password: String) throws -> BuxMuseArchivePayload {
        try decrypt(data, secret: password)
    }

    public static func restore(
        _ payload: BuxMuseArchivePayload,
        settings: SettingsStore,
        studioStore: StudioStore,
        simpleStudioStore: SimpleStudioStore,
        persistence: PersistenceController,
        brain: BuxMuseBrain,
        onStep: ((BuxMuseArchiveStep, Double) -> Void)? = nil
    ) throws {
        onStep?(.validate, 0.1)

        onStep?(.settings, 0.2)
        try settings.importArchiveSettingsData(payload.settingsData)
        settings.importFeatureFlagsFromArchive(payload.featureFlags)
        HustleManager.shared.replaceAll(payload.hustles, selectedId: payload.selectedHustleId)

        onStep?(.expenses, 0.4)
        try persistence.purgeExpensesAndGoals()
        for tx in payload.transactions {
            _ = try brain.saveExpense(tx)
        }

        onStep?(.goals, 0.65)
        try persistence.replaceAllGoals(payload.goals)

        onStep?(.studio, 0.85)
        if let studio = payload.studioSnapshot {
            studioStore.apply(studio)
        }
        if let simple = payload.simpleStudioSnapshot {
            simpleStudioStore.apply(simple)
        }

        onStep?(.finalize, 1.0)
        brain.refreshExpenses()
        settings.save()
    }

    // MARK: - v1

    private static func decryptV1(_ data: Data, secret: String) throws -> BuxMuseArchivePayload {
        let combined = data.suffix(from: headerV1.count)
        let key = deriveKey(from: secret)
        let box = try AES.GCM.SealedBox(combined: combined)
        let plain = try AES.GCM.open(box, using: key)
        return try decodePayload(plain)
    }

    // MARK: - v2

    private static func decryptV2(_ data: Data, secret: String) throws -> BuxMuseArchivePayload {
        var offset = headerV2.count
        guard offset + 5 <= data.count else { throw BuxMuseArchiveError.corruptArchive }

        let version = data[offset]
        offset += 1
        guard version == envelopeVersionV2 else { throw BuxMuseArchiveError.unsupportedVersion }

        let passwordLen = Int(readUInt16(data, offset: offset))
        offset += 2
        let recoveryLen = Int(readUInt16(data, offset: offset))
        offset += 2

        guard passwordLen > 0, recoveryLen > 0,
              offset + passwordLen + recoveryLen < data.count else {
            throw BuxMuseArchiveError.corruptArchive
        }

        let passwordWrap = data.subdata(in: offset..<(offset + passwordLen))
        offset += passwordLen
        let recoveryWrap = data.subdata(in: offset..<(offset + recoveryLen))
        offset += recoveryLen
        let sealedPayload = data.suffix(from: offset)

        let isRecovery = BuxMuseRecoveryKey.isRecoveryKeyFormat(secret)
        let derived = deriveKey(from: isRecovery ? BuxMuseRecoveryKey.normalized(secret) : secret)

        let contentKey: SymmetricKey
        do {
            if isRecovery {
                contentKey = try unwrapKey(recoveryWrap, using: derived)
            } else {
                contentKey = try unwrapKey(passwordWrap, using: derived)
            }
        } catch {
            throw BuxMuseArchiveError.invalidPassword
        }

        let box = try AES.GCM.SealedBox(combined: sealedPayload)
        let plain = try AES.GCM.open(box, using: contentKey)
        return try decodePayload(plain)
    }

    // MARK: - Helpers

    private static func decodePayload(_ plain: Data) throws -> BuxMuseArchivePayload {
        let payload = try JSONDecoder().decode(BuxMuseArchivePayload.self, from: plain)
        guard payload.manifest.formatVersion <= 2 else { throw BuxMuseArchiveError.unsupportedVersion }
        return payload
    }

    private static func wrapKey(_ keyData: Data, using wrappingKey: SymmetricKey) throws -> Data {
        guard let combined = try AES.GCM.seal(keyData, using: wrappingKey).combined else {
            throw BuxMuseArchiveError.corruptArchive
        }
        return combined
    }

    private static func unwrapKey(_ wrap: Data, using wrappingKey: SymmetricKey) throws -> SymmetricKey {
        let box = try AES.GCM.SealedBox(combined: wrap)
        let keyData = try AES.GCM.open(box, using: wrappingKey)
        return SymmetricKey(data: keyData)
    }

    private static func deriveKey(from secret: String) -> SymmetricKey {
        SymmetricKey(data: SHA256.hash(data: Data(secret.utf8)))
    }

    private static func appendUInt16(_ data: inout Data, _ value: Int) {
        var be = UInt16(value).bigEndian
        withUnsafeBytes(of: &be) { data.append(contentsOf: $0) }
    }

    private static func readUInt16(_ data: Data, offset: Int) -> UInt16 {
        let slice = data.subdata(in: offset..<(offset + 2))
        return slice.withUnsafeBytes { $0.load(as: UInt16.self).bigEndian }
    }
}
