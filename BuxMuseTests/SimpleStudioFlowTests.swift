//
//  SimpleStudioFlowTests.swift
//  BuxMuseTests
//

import XCTest
@testable import BuxMuse

final class SimpleStudioFlowTests: XCTestCase {

    private let format: (Decimal) -> String = { "\($0)" }

    func testSimpleSuggestionListIsExpanded() {
        XCTAssertGreaterThanOrEqual(SimpleStudioSearchEngine.simpleSuggestionQueries.count, 15)
        XCTAssertTrue(SimpleStudioSearchEngine.simpleSuggestionQueries.contains("Who owes me?"))
        XCTAssertTrue(SimpleStudioSearchEngine.simpleSuggestionQueries.contains("Work done this week"))
    }

    func testChartFilterSpentUsesMonthEntriesOnly() {
        let calendar = Calendar.current
        let now = Date()
        let lastMonth = calendar.date(byAdding: .month, value: -1, to: now) ?? now

        let snapshot = SimpleStudioSnapshot(entries: [
            SimpleStudioEntry(kind: .expense, amount: 40, createdAt: now),
            SimpleStudioEntry(kind: .expense, amount: 99, createdAt: lastMonth)
        ])

        let results = SimpleStudioSearchEngine.chartFilterResults(
            sliceID: "spent",
            snapshot: snapshot,
            format: format,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.amountFormatted, "40")
    }

    func testChartFilterMadeIncludesPaidOwedToMe() {
        let snapshot = SimpleStudioSnapshot(entries: [
            SimpleStudioEntry(kind: .owedToMe, amount: 80, paymentStatus: .paid, createdAt: Date()),
            SimpleStudioEntry(kind: .owedToMe, amount: 80, paymentStatus: .unpaid, createdAt: Date())
        ])

        let results = SimpleStudioSearchEngine.chartFilterResults(
            sliceID: "made",
            snapshot: snapshot,
            format: format
        )

        XCTAssertEqual(results.count, 1)
    }

    func testBuildMonthChartSlicesFiltersZeroValues() {
        let slices = SimpleStudioEngine.buildMonthChartSlices(
            made: 100,
            spent: 0,
            waiting: 50,
            owe: 0,
            format: format,
            locale: Locale(identifier: "en_US")
        )

        XCTAssertEqual(slices.count, 2)
        XCTAssertTrue(slices.contains { $0.id == "made" })
        XCTAssertTrue(slices.contains { $0.id == "waiting" })
    }

    func testBusinessCardRoundTrip() {
        let card = SimpleBusinessCard(
            name: "Maria Plumbing",
            tagline: "Jobs & repairs",
            phone: "+15551234567",
            email: "maria@example.com",
            skills: "Plumbing, drains",
            photoPath: nil
        )

        XCTAssertFalse(card.name.isEmpty)
        XCTAssertEqual(card.tagline, "Jobs & repairs")
    }
}
