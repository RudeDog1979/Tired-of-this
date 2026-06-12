//
//  BuxDiagnosticExportTests.swift
//  BuxMuseTests
//

import XCTest
@testable import BuxMuse

@MainActor
final class BuxDiagnosticExportTests: XCTestCase {

    func testDiagnosticJSONContainsNoForbiddenKeys() async throws {
        let settings = SettingsStore.shared
        let appSettings = AppSettingsManager()

        let report = await BuxDiagnosticExportEngine.buildReport(
            settings: settings,
            appSettings: appSettings,
            expenseCount: 3,
            goalCount: 1,
            studioReceiptCount: 2,
            simpleEntryCount: 4
        )

        let url = try BuxDiagnosticExportEngine.writeTemporaryJSON(report)
        defer { try? FileManager.default.removeItem(at: url) }

        let data = try Data(contentsOf: url)
        let violations = BuxDiagnosticExportEngine.forbiddenKeys(in: data)
        XCTAssertTrue(violations.isEmpty, "Forbidden PII keys found: \(violations)")

        let decoded = try JSONDecoder().decode(BuxDiagnosticReport.self, from: data)
        XCTAssertEqual(decoded.schemaVersion, 1)
        XCTAssertEqual(decoded.recordCounts.expenses, 3)
        XCTAssertFalse(decoded.privacyNote.isEmpty)
    }

    func testForbiddenKeyScannerDetectsViolations() throws {
        let payload: [String: Any] = [
            "schemaVersion": 1,
            "merchantName": "Secret Shop",
            "recordCounts": ["expenses": 1]
        ]
        let data = try JSONSerialization.data(withJSONObject: payload)
        let violations = BuxDiagnosticExportEngine.forbiddenKeys(in: data)
        XCTAssertEqual(violations, ["merchantName"])
    }
}
