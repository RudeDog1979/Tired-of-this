//
//  BuxDiagnosticExportEngine.swift
//  BuxMuse
//
//  Opt-in, on-device diagnostic report — counts and flags only, no PII.
//

import Foundation
import UIKit
import UserNotifications

public struct BuxDiagnosticReport: Codable, Equatable, Sendable {
    public struct RecordCounts: Codable, Equatable, Sendable {
        public var expenses: Int
        public var goals: Int
        public var studioReceipts: Int
        public var simpleStudioEntries: Int
    }

    public struct StorageBytes: Codable, Equatable, Sendable {
        public var receiptsAndScans: Int
        public var merchantLogos: Int
        public var database: Int
        public var silentBackups: Int
        public var settings: Int
        public var total: Int
    }

    public struct Permissions: Codable, Equatable, Sendable {
        public var notifications: String
    }

    public let schemaVersion: Int
    public let generatedAt: Date
    public let appVersion: String
    public let buildNumber: String
    public let osVersion: String
    public let deviceFamily: String
    public let localeIdentifier: String
    public let currencyCode: String
    public let studioMode: String
    public let featureFlags: [String: Bool]
    public let recordCounts: RecordCounts
    public let storageBytes: StorageBytes
    public let permissions: Permissions
    public let privacyNote: String

    /// Keys that must never appear in exported diagnostic JSON.
    public static let forbiddenTopLevelKeys: Set<String> = [
        "firstName", "lastName", "userDisplayName", "merchant", "merchantName",
        "amount", "notes", "email", "phone", "password", "expenses", "goals",
        "transactions", "receipts", "clients", "profile", "address"
    ]
}

@MainActor
public enum BuxDiagnosticExportEngine {

    public static func buildReport(
        settings: SettingsStore,
        appSettings: AppSettingsManager,
        expenseCount: Int,
        goalCount: Int,
        studioReceiptCount: Int,
        simpleEntryCount: Int
    ) async -> BuxDiagnosticReport {
        let storage = BuxStorageAuditEngine.audit()
        let notificationStatus = await notificationAuthLabel()

        return BuxDiagnosticReport(
            schemaVersion: 1,
            generatedAt: Date(),
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            buildNumber: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown",
            osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            deviceFamily: UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone",
            localeIdentifier: appSettings.interfaceLocale.identifier,
            currencyCode: appSettings.selectedCurrency.id,
            studioMode: settings.studioMode.rawValue,
            featureFlags: [
                "burnoutGuardEnabled": settings.burnoutGuardEnabled,
                "dataGuardModeEnabled": settings.dataGuardModeEnabled,
                "studioEnabled": settings.studioEnabled,
                "sideHustleMatrixEnabled": settings.sideHustleMatrixEnabled,
                "brandThemesEnabled": settings.brandThemesEnabled,
                "enableDebugOverlay": settings.enableDebugOverlay
            ],
            recordCounts: .init(
                expenses: expenseCount,
                goals: goalCount,
                studioReceipts: studioReceiptCount,
                simpleStudioEntries: simpleEntryCount
            ),
            storageBytes: .init(
                receiptsAndScans: storage.receiptsAndScansBytes,
                merchantLogos: storage.merchantLogosBytes,
                database: storage.databaseBytes,
                silentBackups: storage.silentBackupsBytes,
                settings: storage.settingsBytes,
                total: storage.totalBytes
            ),
            permissions: .init(
                notifications: notificationStatus
            ),
            privacyNote: "This diagnostic report contains no personal financial data, names, amounts, or health samples. BuxMuse does not receive this file — you choose where to share it."
        )
    }

    public static func writeTemporaryJSON(_ report: BuxDiagnosticReport) throws -> URL {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(report)

        let violations = Self.forbiddenKeys(in: data)
        guard violations.isEmpty else {
            throw BuxDiagnosticExportError.forbiddenKeysFound(violations)
        }

        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("buxmuse_diagnostic_\(stamp).json")
        try data.write(to: url, options: .atomic)
        return url
    }

    public static func forbiddenKeys(in data: Data) -> [String] {
        guard let object = try? JSONSerialization.jsonObject(with: data),
              let dict = object as? [String: Any] else { return [] }
        return dict.keys.filter { BuxDiagnosticReport.forbiddenTopLevelKeys.contains($0) }.sorted()
    }

    private static func notificationAuthLabel() async -> String {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized: return "authorized"
        case .denied: return "denied"
        case .notDetermined: return "not_determined"
        case .provisional: return "provisional"
        case .ephemeral: return "ephemeral"
        @unknown default: return "unknown"
        }
    }
}

public enum BuxDiagnosticExportError: LocalizedError {
    case forbiddenKeysFound([String])

    public var errorDescription: String? {
        switch self {
        case .forbiddenKeysFound(let keys):
            return "Diagnostic export blocked forbidden keys: \(keys.joined(separator: ", "))"
        }
    }
}
