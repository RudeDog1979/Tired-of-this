//
//  SimpleStudioScanEngineTests.swift
//  BuxMuseTests
//

import XCTest
@testable import BuxMuse

final class SimpleStudioScanEngineTests: XCTestCase {

    func testInfersIncomeFromTransferScreenshot() {
        let lines = [
            "Zelle payment",
            "Payment from Marcus Johnson",
            "Amount $500.00",
            "Memo: Bathroom tiles",
            "03/15/2026"
        ]
        let draft = SimpleStudioScanEngine.parseLines(lines, persona: .jobsAndRepairs)
        XCTAssertEqual(draft.kind, .job)
        XCTAssertEqual(draft.amount, 500)
        XCTAssertTrue(draft.customerName.localizedCaseInsensitiveContains("Marcus"))
    }

    func testInfersExpenseFromReceipt() {
        let lines = [
            "Hardware World",
            "Purchase receipt",
            "Total 320.50",
            "Paid to cashier"
        ]
        let draft = SimpleStudioScanEngine.parseLines(lines, persona: .jobsAndRepairs)
        XCTAssertEqual(draft.kind, .expense)
        XCTAssertEqual(draft.amount, 320.50)
    }

    func testInfersAdvanceFromText() {
        let lines = [
            "Advance for materials deposit",
            "Received from Keisha",
            "J$1,200.00"
        ]
        let draft = SimpleStudioScanEngine.parseLines(lines, persona: .jobsAndRepairs)
        XCTAssertEqual(draft.kind, .advanceReceived)
        XCTAssertEqual(draft.amount, 1200)
    }

    func testScanDraftBuildsEntryWithPhotoPath() {
        let draft = SimpleScanDraft(
            kind: .income,
            amount: 75,
            customerName: "Anya",
            jobLabel: "Cleaning",
            note: "Cash app",
            paymentStatus: .paid
        )
        let entry = draft.asEntry(sourcePhotoPath: "/tmp/scan.jpg")
        XCTAssertEqual(entry.kind, .income)
        XCTAssertEqual(entry.amount, 75)
        XCTAssertEqual(entry.customerName, "Anya")
        XCTAssertEqual(entry.sourcePhotoPath, "/tmp/scan.jpg")
    }
}
