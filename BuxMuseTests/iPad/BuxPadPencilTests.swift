//
//  BuxPadPencilTests.swift
//

import Foundation
import PencilKit
import Testing
@testable import BuxMuse

struct BuxPadPencilTests {

    @Test func receiptMarkupStore_clearsEmptyDrawing() {
        let receiptId = UUID()
        #expect(BuxPadReceiptMarkupStore.saveDrawing(PKDrawing(), for: receiptId))
        #expect(!BuxPadReceiptMarkupStore.hasMarkup(for: receiptId))
    }

    @Test func invoiceSignatureStore_roundTripsPNG() {
        let invoiceId = UUID()
        let png = Data([0x89, 0x50, 0x4E, 0x47])
        #expect(BuxPadInvoiceSignatureStore.savePNG(png, for: invoiceId))
        #expect(BuxPadInvoiceSignatureStore.hasSignature(for: invoiceId))
        #expect(BuxPadInvoiceSignatureStore.loadPNG(for: invoiceId) == png)
        #expect(BuxPadInvoiceSignatureStore.clearSignature(for: invoiceId))
        #expect(!BuxPadInvoiceSignatureStore.hasSignature(for: invoiceId))
    }
}
