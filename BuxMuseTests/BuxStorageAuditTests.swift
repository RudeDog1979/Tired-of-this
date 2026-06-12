//
//  BuxStorageAuditTests.swift
//  BuxMuseTests
//

import XCTest
@testable import BuxMuse

final class BuxStorageAuditTests: XCTestCase {

    func testFormattedByteCountZero() {
        XCTAssertEqual(BuxStorageAuditEngine.formattedByteCount(0), "0 KB")
    }

    func testMinimalZIPRoundTripStructure() throws {
        let files: [(path: String, data: Data)] = [
            ("hello.txt", Data("test".utf8)),
            ("nested/world.txt", Data("nested".utf8))
        ]
        let zipData = BuxMinimalZIPWriter.archive(files: files)
        XCTAssertGreaterThan(zipData.count, 100)
        XCTAssertEqual(zipData.prefix(4), Data([0x50, 0x4B, 0x03, 0x04]))
        XCTAssertTrue(zipData.suffix(4) == Data([0x50, 0x4B, 0x05, 0x06]))
    }

    func testReceiptZIPExportFailsWhenNoImages() {
        let tempPro = BuxStorageAuditEngine.proReceiptsDirectory()
        let tempScans = BuxStorageAuditEngine.simpleScansDirectory()
        let fm = FileManager.default

        let hadPro = fm.fileExists(atPath: tempPro.path)
        let hadScans = fm.fileExists(atPath: tempScans.path)
        try? fm.removeItem(at: tempPro)
        try? fm.removeItem(at: tempScans)

        defer {
            if hadPro { try? fm.createDirectory(at: tempPro, withIntermediateDirectories: true) }
            if hadScans { try? fm.createDirectory(at: tempScans, withIntermediateDirectories: true) }
        }

        XCTAssertThrowsError(try BuxReceiptZIPExporter.exportToTemporaryZIP()) { error in
            guard case BuxReceiptZIPExporter.ExportError.noImages = error else {
                return XCTFail("Expected noImages, got \(error)")
            }
        }
    }
}
