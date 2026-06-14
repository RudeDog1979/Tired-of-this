//
//  BuxStorageAuditEngine.swift
//  BuxMuse
//
//  On-device storage breakdown for Settings → Data.
//

import Foundation

public struct BuxStorageBreakdown: Equatable, Sendable {
    public var receiptsAndScansBytes: Int
    public var merchantLogosBytes: Int
    public var databaseBytes: Int
    public var silentBackupsBytes: Int
    public var settingsBytes: Int
    public var totalBytes: Int
    public var receiptImageCount: Int
    public var scanImageCount: Int

    public static let empty = BuxStorageBreakdown(
        receiptsAndScansBytes: 0,
        merchantLogosBytes: 0,
        databaseBytes: 0,
        silentBackupsBytes: 0,
        settingsBytes: 0,
        totalBytes: 0,
        receiptImageCount: 0,
        scanImageCount: 0
    )
}

public enum BuxStorageAuditEngine {

    private static let swiftDataStoreBaseName = "BuxMuse_v5"
    private static let merchantLogoFolder = "BuxMuseMerchantLogosV5"
    private static let settingsFileName = "settings_store_v1.json"
    private static let silentBackupFolder = "BuxMuseBackups"
    private static let proReceiptFolder = "StudioReceipts"
    private static let simpleScanFolder = "Studio/scans"
    private static let agreementsFolder = "Studio/agreements"
    private static let agreementMarkupFolder = "StudioAgreementMarkups"
    private static let receiptMarkupFolder = "StudioReceiptMarkups"
    private static let studioHubFileNames = [
        "studio_hub.json",
        "studio_hub_v1.json",
        "freelance_hub.json",
        "freelance_hub_v1.json",
        "simple_studio.json"
    ]

    public static func audit() -> BuxStorageBreakdown {
        let fm = FileManager.default
        let documentsURL = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        let proReceiptsURL = documentsURL.appendingPathComponent(proReceiptFolder, isDirectory: true)
        let simpleScansURL = applicationSupportURL()
            .appendingPathComponent(simpleScanFolder, isDirectory: true)
        let agreementsURL = applicationSupportURL()
            .appendingPathComponent(agreementsFolder, isDirectory: true)
        let agreementMarkupURL = documentsURL.appendingPathComponent(agreementMarkupFolder, isDirectory: true)
        let receiptMarkupURL = documentsURL.appendingPathComponent(receiptMarkupFolder, isDirectory: true)
        let logosURL = fm.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent(merchantLogoFolder, isDirectory: true)
        let databaseURL = applicationSupportURL()
            .appendingPathComponent("\(swiftDataStoreBaseName).store")
        let backupsURL = applicationSupportURL()
            .appendingPathComponent(silentBackupFolder, isDirectory: true)
        let settingsURL = applicationSupportURL()
            .appendingPathComponent("Settings", isDirectory: true)
            .appendingPathComponent(settingsFileName)

        let proReceiptAudit = directoryAudit(at: proReceiptsURL, extensions: ["jpg", "jpeg", "png"])
        let scanAudit = directoryAudit(at: simpleScansURL, extensions: ["jpg", "jpeg", "png"])
        let agreementsAudit = directoryAudit(at: agreementsURL, extensions: nil)
        let agreementMarkupAudit = directoryAudit(at: agreementMarkupURL, extensions: nil)
        let receiptMarkupAudit = directoryAudit(at: receiptMarkupURL, extensions: nil)
        let receiptsAndScans = proReceiptAudit.bytes
            + scanAudit.bytes
            + agreementsAudit.bytes
            + agreementMarkupAudit.bytes
            + receiptMarkupAudit.bytes

        let merchantLogos = directoryAudit(at: logosURL, extensions: ["png", "jpg", "jpeg"]).bytes
        let database = storeAuditBytes(at: databaseURL)
        let silentBackups = directoryAudit(at: backupsURL, extensions: nil).bytes
        let settings = fileSize(at: settingsURL)

        let total = receiptsAndScans + merchantLogos + database + silentBackups + settings

        return BuxStorageBreakdown(
            receiptsAndScansBytes: receiptsAndScans,
            merchantLogosBytes: merchantLogos,
            databaseBytes: database,
            silentBackupsBytes: silentBackups,
            settingsBytes: settings,
            totalBytes: total,
            receiptImageCount: proReceiptAudit.fileCount,
            scanImageCount: scanAudit.fileCount
        )
    }

    public static func formattedByteCount(_ bytes: Int) -> String {
        guard bytes > 0 else { return "0 KB" }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }

    // MARK: - Paths for export

    public static func proReceiptsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent(proReceiptFolder, isDirectory: true)
    }

    public static func simpleScansDirectory() -> URL {
        applicationSupportURL().appendingPathComponent(simpleScanFolder, isDirectory: true)
    }

    public static func silentBackupsDirectory() -> URL {
        applicationSupportURL().appendingPathComponent(silentBackupFolder, isDirectory: true)
    }

    /// Factory reset: delete every persisted BuxMuse artifact from disk and UserDefaults.
    /// CloudKit is untouched. Re-seed in-memory stores after this returns.
    public static func performNuclearLocalWipe() {
        wipeAllBuxMuseUserDefaults()

        let fm = FileManager.default
        removeAllContents(in: applicationSupportURL())

        if let documents = fm.urls(for: .documentDirectory, in: .userDomainMask).first {
            removeAllContents(in: documents)
        }

        if let caches = fm.urls(for: .cachesDirectory, in: .userDomainMask).first {
            removeBuxMuseCacheContents(in: caches)
        }

        purgeTemporarySyncArtifacts()
        URLCache.shared.removeAllCachedResponses()
    }

    private static func removeAllContents(in directory: URL) {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return }
        for url in contents {
            try? fm.removeItem(at: url)
        }
    }

    private static func removeBuxMuseCacheContents(in cachesDirectory: URL) {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: cachesDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return }
        for url in contents {
            let name = url.lastPathComponent
            if name.hasPrefix("BuxMuse")
                || name.hasPrefix("buxmuse")
                || name.hasPrefix("bux-sync")
                || name.hasPrefix("com.buxmuse") {
                try? fm.removeItem(at: url)
            }
        }
    }

    private static func purgeTemporarySyncArtifacts() {
        let fm = FileManager.default
        let temp = fm.temporaryDirectory
        guard let contents = try? fm.contentsOfDirectory(
            at: temp,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return }
        for url in contents where url.lastPathComponent.hasPrefix("bux-sync-") {
            try? fm.removeItem(at: url)
        }
    }

    private static func wipeAllBuxMuseUserDefaults() {
        let defaults = UserDefaults.standard
        for key in defaults.dictionaryRepresentation().keys {
            if key.hasPrefix("buxmuse.") || key == "studio_discovery_offer_dismissed" {
                defaults.removeObject(forKey: key)
            }
        }
    }

    private static func removeItemIfExists(at url: URL) {
        let fm = FileManager.default
        var isDirectory: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDirectory) else { return }
        try? fm.removeItem(at: url)
    }

    private static func removeStoreArtifacts(withBaseName baseName: String, in directory: URL) {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return }
        for url in contents where url.lastPathComponent.hasPrefix(baseName) {
            try? fm.removeItem(at: url)
        }
    }

    /// Deletes user-generated media, Studio sidecars, backups, and legacy hub JSON (not SwiftData or settings JSON).
    public static func purgeAllUserGeneratedMedia() {
        removeDirectoryContents(at: proReceiptsDirectory())
        removeDirectoryContents(at: simpleScansDirectory())
        removeDirectoryContents(at: silentBackupsDirectory())
        removeDirectoryContents(at: agreementsDirectory())
        removeDirectoryContents(at: agreementMarkupDirectory())
        removeDirectoryContents(at: receiptMarkupDirectory())
        purgeLegacyStudioHubFiles()
        let syncConflicts = applicationSupportURL().appendingPathComponent("Sync/personal_sync_conflicts.json")
        try? FileManager.default.removeItem(at: syncConflicts)
    }

    public static func agreementsDirectory() -> URL {
        applicationSupportURL().appendingPathComponent(agreementsFolder, isDirectory: true)
    }

    private static func agreementMarkupDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent(agreementMarkupFolder, isDirectory: true)
    }

    private static func receiptMarkupDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent(receiptMarkupFolder, isDirectory: true)
    }

    private static func purgeLegacyStudioHubFiles() {
        let support = applicationSupportURL()
        let studioDir = support.appendingPathComponent("Studio", isDirectory: true)
        let legacyDir = support.appendingPathComponent("FreelanceHub", isDirectory: true)
        for name in studioHubFileNames {
            try? FileManager.default.removeItem(at: studioDir.appendingPathComponent(name))
            try? FileManager.default.removeItem(at: legacyDir.appendingPathComponent(name))
        }
    }

    // MARK: - Private

    private static func removeDirectoryContents(at url: URL) {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: nil) else { return }
        for file in files {
            try? fm.removeItem(at: file)
        }
    }

    private static func applicationSupportURL() -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    }

    private struct DirectoryAudit {
        var bytes: Int
        var fileCount: Int
    }

    private static func directoryAudit(at url: URL, extensions: [String]?) -> DirectoryAudit {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path),
              let enumerator = fm.enumerator(
                at: url,
                includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
                options: [.skipsHiddenFiles]
              ) else {
            return DirectoryAudit(bytes: 0, fileCount: 0)
        }

        var bytes = 0
        var count = 0
        for case let fileURL as URL in enumerator {
            guard (try? fileURL.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else { continue }
            if let extensions {
                let ext = fileURL.pathExtension.lowercased()
                guard extensions.contains(ext) else { continue }
            }
            bytes += fileSize(at: fileURL)
            count += 1
        }
        return DirectoryAudit(bytes: bytes, fileCount: count)
    }

    private static func fileSize(at url: URL) -> Int {
        guard let values = try? url.resourceValues(forKeys: [.fileSizeKey]),
              let size = values.fileSize else { return 0 }
        return size
    }

    private static func storeAuditBytes(at storeURL: URL) -> Int {
        let fm = FileManager.default
        var isDirectory: ObjCBool = false
        if fm.fileExists(atPath: storeURL.path, isDirectory: &isDirectory), isDirectory.boolValue {
            return directoryAudit(at: storeURL, extensions: nil).bytes
        }
        return fileSize(at: storeURL)
            + fileSize(at: URL(fileURLWithPath: storeURL.path + "-shm"))
            + fileSize(at: URL(fileURLWithPath: storeURL.path + "-wal"))
    }
}
