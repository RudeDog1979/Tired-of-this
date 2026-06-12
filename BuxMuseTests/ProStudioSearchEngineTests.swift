//
//  ProStudioSearchEngineTests.swift
//  BuxMuseTests
//

import XCTest
@testable import BuxMuse

final class ProStudioSearchEngineTests: XCTestCase {

    private let format: (Decimal) -> String = { "\($0)" }

    func testOverdueInvoicesIntent() {
        let clientID = UUID()
        let overdueID = UUID()
        let paidID = UUID()

        let studio = StudioSnapshot(
            profile: StudioProfile(),
            clients: [StudioClient(id: clientID, name: "Acme")],
            invoices: [
                StudioInvoice(
                    id: overdueID,
                    clientId: clientID,
                    invoiceNumber: "INV-001",
                    dueDate: Date().addingTimeInterval(-86400),
                    status: .sent,
                    total: 500
                ),
                StudioInvoice(
                    id: paidID,
                    clientId: clientID,
                    invoiceNumber: "INV-002",
                    status: .paid,
                    total: 200
                )
            ],
            projects: [],
            receipts: [],
            taxProfile: StudioTaxProfile()
        )

        let results = ProStudioSearchEngine.search(
            query: "Overdue invoices",
            studio: studio,
            simple: nil,
            format: format
        )

        XCTAssertTrue(results.contains { result in
            if case .invoice(overdueID) = result.kind { return true }
            return false
        })
        XCTAssertFalse(results.contains { result in
            if case .invoice(paidID) = result.kind { return true }
            return false
        })
    }

    func testGroupsResultsBySection() {
        let clientID = UUID()
        let studio = StudioSnapshot(
            profile: StudioProfile(),
            clients: [StudioClient(id: clientID, name: "Maria")],
            invoices: [],
            projects: [StudioProject(id: UUID(), name: "Website", clientId: clientID)],
            receipts: [],
            taxProfile: StudioTaxProfile()
        )

        let results = ProStudioSearchEngine.search(
            query: "Maria",
            studio: studio,
            simple: nil,
            format: format
        )

        let grouped = ProStudioSearchEngine.groupedResults(results)
        XCTAssertFalse(grouped.isEmpty)
        XCTAssertTrue(grouped.contains { $0.section == .clients || $0.section == .projects })
    }

    func testMileageSearchReturnsResults() {
        let entryID = UUID()
        let studio = StudioSnapshot(
            profile: StudioProfile(),
            clients: [],
            invoices: [],
            projects: [],
            receipts: [],
            taxProfile: StudioTaxProfile(),
            mileageEntries: [
                MileageEntry(
                    id: entryID,
                    date: Date(),
                    startLocation: "Home",
                    endLocation: "Client",
                    distance: 12.4,
                    purpose: .business,
                    notes: "Site visit"
                )
            ]
        )

        let results = ProStudioSearchEngine.search(
            query: "Mileage this month",
            studio: studio,
            simple: nil,
            format: format
        )

        XCTAssertTrue(results.contains { result in
            if case .mileage(entryID) = result.kind { return true }
            return false
        })
    }
}
