//
//  SimpleStudioSearchEngineTests.swift
//  BuxMuseTests
//

import XCTest
@testable import BuxMuse

final class SimpleStudioSearchEngineTests: XCTestCase {

    func testParsesWaitingIntent() {
        let parsed = SimpleStudioSearchEngine.parse("Who owes me?")
        XCTAssertTrue(parsed.intents.contains(.waitingOnMe))
        XCTAssertEqual(parsed.chartSliceID, "waiting")
    }

    func testParsesPersonNameTokens() {
        let parsed = SimpleStudioSearchEngine.parse("jobs for Maria")
        XCTAssertTrue(parsed.intents.contains(.jobs))
        XCTAssertTrue(parsed.nameTokens.contains("maria"))
    }

    func testFindsWaitingPeopleAndEntries() {
        let maria = SimpleCustomerMemory(name: "Maria", outstandingBalance: 120)
        let entry = SimpleStudioEntry(
            kind: .owedToMe,
            amount: 80,
            customerName: "John",
            paymentStatus: .unpaid
        )
        let snapshot = SimpleStudioSnapshot(
            entries: [entry],
            customers: [maria]
        )

        let results = SimpleStudioSearchEngine.search(
            query: "who owes me",
            snapshot: snapshot,
            format: { "\($0)" }
        )

        XCTAssertTrue(results.contains { $0.title == "Maria" })
        XCTAssertTrue(results.contains { $0.title == "They owe me" || $0.subtitle == "John" })
    }

    func testChartSliceFilterMade() {
        let entry = SimpleStudioEntry(
            kind: .income,
            amount: 50,
            customerName: "Client",
            createdAt: Date()
        )
        let snapshot = SimpleStudioSnapshot(entries: [entry])

        let results = SimpleStudioSearchEngine.chartFilterResults(
            sliceID: "made",
            snapshot: snapshot,
            format: { "\($0)" }
        )

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.kind, SimpleStudioSearchEngine.ResultKind.entry(entry.id))
    }

    func testChartSliceFilterWaitingIncludesAllTime() {
        let oldDate = Calendar.current.date(byAdding: .month, value: -2, to: Date()) ?? Date()
        let entry = SimpleStudioEntry(
            kind: .owedToMe,
            amount: 80,
            customerName: "John",
            paymentStatus: .unpaid,
            createdAt: oldDate
        )
        let snapshot = SimpleStudioSnapshot(entries: [entry])

        let results = SimpleStudioSearchEngine.chartFilterResults(
            sliceID: "waiting",
            snapshot: snapshot,
            format: { "\($0)" }
        )

        XCTAssertEqual(results.count, 1)
    }
}
