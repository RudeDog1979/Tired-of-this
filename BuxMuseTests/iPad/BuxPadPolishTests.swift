//
//  BuxPadPolishTests.swift
//

import Foundation
import Testing
@testable import BuxMuse

@MainActor
struct BuxPadPolishTests {

    @Test func expenseRedoCandidate_enablesShortcut() {
        let brain = BuxPadNavigationBrain()
        #expect(!brain.canExpenseRedo)
        brain.stashExpenseRedoCandidate(
            ExpenseRecord(
                id: UUID(),
                name: "Test",
                amountValue: 1,
                currencyCode: "USD",
                date: Date(),
                categoryRaw: "food",
                merchantName: "Test"
            )
        )
        #expect(brain.canExpenseRedo)
        brain.clearExpenseRedoCandidate()
        #expect(!brain.canExpenseRedo)
    }

    @Test func invoiceDragPayload_roundTrip() {
        let id = UUID()
        let encoded = BuxPadInvoiceDragPayload.encode(id)
        #expect(BuxPadInvoiceDragPayload.decode(encoded) == id)
    }

    @Test func receiptDragPayload_roundTrip() {
        let id = UUID()
        let encoded = BuxPadReceiptDragPayload.encode(id)
        #expect(BuxPadReceiptDragPayload.decode(encoded) == id)
    }

    @Test func expenseDragPayload_roundTrip() {
        let expenseId = UUID()
        let payload = BuxPadExpenseDragPayload.encode(expenseId)
        #expect(BuxPadExpenseDragPayload.decode(payload) == expenseId)
    }
}
