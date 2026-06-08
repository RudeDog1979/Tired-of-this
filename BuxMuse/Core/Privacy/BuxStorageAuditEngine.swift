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

    private static let swiftDataStoreBaseName = "BuxMuse_v3"
    private static let merchantLogoFolder = "BuxMuseMerchantLogosV5"
    private static let settingsFileName = "settings_store_v1.json"
    private static let silentBackupFolder = "BuxMuseBackups"
    private static let proReceiptFolder = "StudioReceipts"
    private static let simpleScanFolder = "Studio/scans"

    public static func audit() -> BuxStorageBreakdown {
        let fm = FileManager.default
        let proReceiptsURL = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent(proReceiptFolder, isDirectory: true)
        let simpleScansURL = applicationSupportURL()
            .appendingPathComponent(simpleScanFolder, isDirectory: true)
        let logosURL = fm.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent(merchantLogoFolder, isDirectory: true)
        let databaseURL = applicationSupportURL()
            .appendingPathComponent("\(swiftDataStoreBaseName).store")
        let backupsURL = applicationSupportURL()
            .appendingPathComponent(silentBackupFolder, isDirectory: true)
        let settingsURL = applicationSupportURL()
            .appendingPathComponent(settingsFileName)

        let proReceiptAudit = directoryAudit(at: proReceiptsURL, extensions: ["jpg", "jpeg", "png"])
        let scanAudit = directoryAudit(at: simpleScansURL, extensions: ["jpg", "jpeg", "png"])
        let receiptsAndScans = proReceiptAudit.bytes + scanAudit.bytes

        let merchantLogos = directoryAudit(at: logosURL, extensions: ["png", "jpg", "jpeg"]).bytes
        let database = fileSize(at: databaseURL)
            + fileSize(at: URL(fileURLWithPath: databaseURL.path + "-shm"))
            + fileSize(at: URL(fileURLWithPath: databaseURL.path + "-wal"))
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

    /// Deletes user-generated media and local backup archives (not SwiftData or settings JSON).
    public static func purgeAllUserGeneratedMedia() {
        removeDirectoryContents(at: proReceiptsDirectory())
        removeDirectoryContents(at: simpleScansDirectory())
        removeDirectoryContents(at: silentBackupsDirectory())
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
}
