//
//  BuxReceiptZIPExporter.swift
//  BuxMuse
//
//  Packages on-device receipt/scan JPEGs into a ZIP for user-controlled export.
//

import Foundation

public struct BuxReceiptZIPManifestEntry: Codable, Equatable, Sendable {
    public let id: String
    public let filename: String
    public let source: String
}

public enum BuxReceiptZIPExporter {

    public enum ExportError: LocalizedError {
        case noImages
        case writeFailed

        public var errorDescription: String? {
            switch self {
            case .noImages: return "No receipt or scan images found on this device."
            case .writeFailed: return "Could not create the receipt archive."
            }
        }
    }

    /// Builds a store-only ZIP with images + `manifest.json`. Returns a temp file URL.
    public static func exportToTemporaryZIP() throws -> URL {
        var files: [(path: String, data: Data)] = []
        var manifest: [BuxReceiptZIPManifestEntry] = []
        appendReceiptImages(to: &files, manifest: &manifest)
        guard !files.isEmpty else { throw ExportError.noImages }

        let manifestData = try JSONEncoder().encode(manifest)
        files.append((path: "manifest.json", data: manifestData))

        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let zipURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("buxmuse_receipts_\(stamp).zip")

        let zipData = BuxMinimalZIPWriter.archive(files: files)
        guard !zipData.isEmpty else { throw ExportError.writeFailed }
        try zipData.write(to: zipURL, options: .atomic)
        return zipURL
    }

    /// Appends receipt/scan JPEGs under `receipts/` paths for combined invoice archives.
    public static func appendReceiptImages(
        to files: inout [(path: String, data: Data)],
        manifest: inout [BuxReceiptZIPManifestEntry]
    ) {
        collectImages(
            from: BuxStorageAuditEngine.proReceiptsDirectory(),
            source: "pro_receipt",
            zipFolder: "receipts/pro_receipt",
            files: &files,
            manifest: &manifest
        )
        collectImages(
            from: BuxStorageAuditEngine.simpleScansDirectory(),
            source: "simple_scan",
            zipFolder: "receipts/simple_scan",
            files: &files,
            manifest: &manifest
        )
    }

    private static func collectImages(
        from directory: URL,
        source: String,
        zipFolder: String? = nil,
        files: inout [(path: String, data: Data)],
        manifest: inout [BuxReceiptZIPManifestEntry]
    ) {
        let fm = FileManager.default
        guard fm.fileExists(atPath: directory.path),
              let items = try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else {
            return
        }

        for url in items where ["jpg", "jpeg", "png"].contains(url.pathExtension.lowercased()) {
            guard let data = try? Data(contentsOf: url) else { continue }
            let filename = url.lastPathComponent
            let id = url.deletingPathExtension().lastPathComponent
            let folder = zipFolder ?? source
            let zipPath = "\(folder)/\(filename)"
            files.append((path: zipPath, data: data))
            manifest.append(BuxReceiptZIPManifestEntry(id: id, filename: filename, source: source))
        }
    }
}

// MARK: - Minimal store-only ZIP (no external dependency)

enum BuxMinimalZIPWriter {

    static func archive(files: [(path: String, data: Data)]) -> Data {
        var archive = Data()
        var centralDirectory = Data()
        var offset: UInt32 = 0

        for file in files {
            let pathData = Data(file.path.utf8)
            let crc = crc32(file.data)
            let size = UInt32(file.data.count)

            var local = Data()
            local.appendUInt32(0x04034b50)
            local.appendUInt16(20)
            local.appendUInt16(0)
            local.appendUInt16(0)
            local.appendUInt16(0)
            local.appendUInt16(0)
            local.appendUInt32(crc)
            local.appendUInt32(size)
            local.appendUInt32(size)
            local.appendUInt16(UInt16(pathData.count))
            local.appendUInt16(0)
            local.append(pathData)
            local.append(file.data)

            archive.append(local)

            var cd = Data()
            cd.appendUInt32(0x02014b50)
            cd.appendUInt16(20)
            cd.appendUInt16(20)
            cd.appendUInt16(0)
            cd.appendUInt16(0)
            cd.appendUInt16(0)
            cd.appendUInt16(0)
            cd.appendUInt32(crc)
            cd.appendUInt32(size)
            cd.appendUInt32(size)
            cd.appendUInt16(UInt16(pathData.count))
            cd.appendUInt16(0)
            cd.appendUInt16(0)
            cd.appendUInt16(0)
            cd.appendUInt16(0)
            cd.appendUInt32(0)
            cd.appendUInt32(offset)
            cd.append(pathData)
            centralDirectory.append(cd)

            offset += UInt32(local.count)
        }

        let cdStart = offset
        archive.append(centralDirectory)

        var end = Data()
        end.appendUInt32(0x06054b50)
        end.appendUInt16(0)
        end.appendUInt16(0)
        end.appendUInt16(UInt16(files.count))
        end.appendUInt16(UInt16(files.count))
        end.appendUInt32(UInt32(centralDirectory.count))
        end.appendUInt32(cdStart)
        end.appendUInt16(0)
        archive.append(end)

        return archive
    }

    private static func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in data {
            let index = Int((crc ^ UInt32(byte)) & 0xFF)
            crc = (crc >> 8) ^ crcTable[index]
        }
        return crc ^ 0xFFFF_FFFF
    }

    private static let crcTable: [UInt32] = {
        (0..<256).map { i -> UInt32 in
            var c = UInt32(i)
            for _ in 0..<8 {
                if c & 1 != 0 {
                    c = 0xEDB8_8320 ^ (c >> 1)
                } else {
                    c >>= 1
                }
            }
            return c
        }
    }()
}

private extension Data {
    mutating func appendUInt16(_ value: UInt16) {
        var le = value.littleEndian
        Swift.withUnsafeBytes(of: &le) { append(contentsOf: $0) }
    }

    mutating func appendUInt32(_ value: UInt32) {
        var le = value.littleEndian
        Swift.withUnsafeBytes(of: &le) { append(contentsOf: $0) }
    }
}
