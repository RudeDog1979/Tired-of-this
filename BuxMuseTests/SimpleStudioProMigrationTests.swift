//
//  SimpleStudioProMigrationTests.swift
//  BuxMuseTests
//

import XCTest
@testable import BuxMuse

@MainActor
final class SimpleStudioProMigrationTests: XCTestCase {

    func testMigratesCustomersAndUnpaidJobToPro() {
        let studioStore = StudioStore.shared
        let beforeClients = studioStore.clients.count
        let beforeInvoices = studioStore.invoices.count

        let customerId = UUID()
        let jobId = UUID()
        let snapshot = SimpleStudioSnapshot(
            entries: [
                SimpleStudioEntry(
                    id: jobId,
                    kind: .job,
                    amount: 450,
                    customerName: "Marcus Test \(jobId.uuidString.prefix(6))",
                    customerId: customerId,
                    jobLabel: "Plumbing",
                    paymentStatus: .unpaid
                )
            ],
            customers: [
                SimpleCustomerMemory(
                    id: customerId,
                    name: "Marcus Test \(jobId.uuidString.prefix(6))",
                    outstandingBalance: 450
                )
            ],
            invoices: []
        )

        let result = SimpleStudioProMigration.migrate(
            simple: snapshot,
            into: studioStore,
            currencyCode: "USD"
        )

        XCTAssertGreaterThanOrEqual(result.clientsAdded, 1)
        XCTAssertGreaterThanOrEqual(result.invoicesAdded, 1)
        XCTAssertGreaterThanOrEqual(studioStore.clients.count, beforeClients)
        XCTAssertGreaterThanOrEqual(studioStore.invoices.count, beforeInvoices)
        XCTAssertTrue(studioStore.invoices.contains { $0.id == jobId })
    }

    func testMigrationIsIdempotentForSameInvoiceId() {
        let studioStore = StudioStore.shared
        let invoiceId = UUID()
        let name = "Idempotent \(invoiceId.uuidString.prefix(6))"
        let snapshot = SimpleStudioSnapshot(
            entries: [],
            customers: [],
            invoices: [
                SimpleInvoice(
                    id: invoiceId,
                    customerName: name,
                    amount: 100,
                    jobDescription: "Work"
                )
            ]
        )

        let first = SimpleStudioProMigration.migrate(simple: snapshot, into: studioStore, currencyCode: "USD")
        let second = SimpleStudioProMigration.migrate(simple: snapshot, into: studioStore, currencyCode: "USD")

        XCTAssertEqual(first.invoicesAdded, 1)
        XCTAssertEqual(second.invoicesAdded, 0)
    }
}
