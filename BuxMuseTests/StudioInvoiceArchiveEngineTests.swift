//
//  StudioInvoiceArchiveEngineTests.swift
//  BuxMuseTests
//

import XCTest
@testable import BuxMuse

@MainActor
final class StudioInvoiceArchiveEngineTests: XCTestCase {

    func testHasLinkedTwinAcrossTiers() {
        let id = UUID()
        let simple = SimpleStudioStore.shared
        let studio = StudioStore.shared

        simple.addInvoice(
            SimpleInvoice(id: id, customerName: "Alex", amount: 100, jobDescription: "Paint")
        )
        studio.addInvoice(
            StudioInvoice(id: id, clientId: UUID(), invoiceNumber: "TEST-LINK", total: 100)
        )

        XCTAssertTrue(
            StudioInvoiceArchiveEngine.hasLinkedTwin(
                tier: .simple,
                id: id,
                simpleStore: simple,
                studioStore: studio
            )
        )

        studio.deleteInvoice(id: id)
        simple.deleteInvoice(id: id)
    }

    func testDeleteInvoiceUnlinksSimpleEntries() {
        let store = SimpleStudioStore.shared
        let invoiceID = UUID()
        let jobID = UUID()

        store.addEntry(
            SimpleStudioEntry(id: jobID, kind: .job, amount: 50, customerName: "Sam", linkedInvoiceId: invoiceID)
        )
        store.addInvoice(
            SimpleInvoice(id: invoiceID, customerName: "Sam", amount: 50, jobDescription: "Fix", linkedEntryId: jobID)
        )

        store.deleteInvoice(id: invoiceID)

        XCTAssertNil(store.invoice(id: invoiceID))
        XCTAssertFalse(store.entries.contains { $0.kind == .owedToMe && $0.linkedInvoiceId == invoiceID })
        if let job = store.entry(id: jobID) {
            XCTAssertNil(job.linkedInvoiceId)
        }
    }
}
