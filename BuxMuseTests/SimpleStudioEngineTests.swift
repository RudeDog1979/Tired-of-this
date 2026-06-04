//
//  SimpleStudioEngineTests.swift
//  BuxMuseTests
//

import XCTest
@testable import BuxMuse

final class SimpleStudioEngineTests: XCTestCase {

    func testHubDisplayComputesTodayKept() {
        let entries = [
            SimpleStudioEntry(kind: .income, amount: 100, createdAt: Date()),
            SimpleStudioEntry(kind: .expense, amount: 30, createdAt: Date()),
            SimpleStudioEntry(
                kind: .job,
                amount: 200,
                materials: 50,
                petrol: 20,
                createdAt: Date()
            )
        ]
        let snapshot = SimpleStudioSnapshot(entries: entries)
        let display = SimpleStudioEngine.buildHubDisplay(
            snapshot: snapshot,
            businessTitle: "Test Biz",
            persona: .jobsAndRepairs,
            format: { "\($0)" }
        )
        XCTAssertFalse(display.isEmpty)
        XCTAssertEqual(display.businessTitle, "Test Biz")
        XCTAssertFalse(display.madeFormatted.isEmpty)
    }

    func testWaitingItemsIncludeUnpaidJobs() {
        let entries = [
            SimpleStudioEntry(
                kind: .job,
                amount: 450,
                customerName: "Marcus",
                jobLabel: "Plumbing",
                paymentStatus: .unpaid,
                createdAt: Date().addingTimeInterval(-86400 * 3)
            )
        ]
        let snapshot = SimpleStudioSnapshot(entries: entries)
        let items = SimpleStudioEngine.buildWaitingItems(snapshot: snapshot, format: { "\($0)" }, locale: Locale(identifier: "en_US"))
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.customerName, "Marcus")
    }

    func testJobQuoteBreakdown() {
        let job = SimpleStudioEntry(
            kind: .job,
            amount: 500,
            materials: 320,
            petrol: 45,
            agreedPrice: 2000
        )
        let breakdown = job.jobBreakdown()
        XCTAssertEqual(breakdown?.agreed, 2000)
        XCTAssertEqual(breakdown?.paidSoFar, 500)
        XCTAssertEqual(breakdown?.spent, 365)
        XCTAssertEqual(breakdown?.balanceDue, 1500)
        XCTAssertEqual(breakdown?.keptSoFar, 135)
        XCTAssertEqual(breakdown?.projectedKept, 1635)
    }

    func testBuildIOweItems() {
        let entries = [
            SimpleStudioEntry(kind: .iOwe, amount: 120, customerName: "Supplier", paymentStatus: .unpaid),
            SimpleStudioEntry(kind: .lent, amount: 500, customerName: "Keisha", paymentStatus: .unpaid),
            SimpleStudioEntry(kind: .iOwe, amount: 50, customerName: "Paid", paymentStatus: .paid)
        ]
        let items = SimpleStudioEngine.buildIOweItems(
            snapshot: SimpleStudioSnapshot(entries: entries),
            format: { "\($0)" },
            locale: Locale(identifier: "en_US")
        )
        XCTAssertEqual(items.count, 2)
        XCTAssertTrue(items.contains { $0.customerName == "Supplier" })
    }
}
