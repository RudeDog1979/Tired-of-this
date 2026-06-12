//
//  BuxPadInvoiceSignatureStore.swift
//  BuxMuse — Sidecar provider signatures for invoices (no invoice model changes).
//

import Foundation
import UIKit

enum BuxPadInvoiceSignatureStore {
    private static let folderName = "StudioInvoiceSignatures"

    static func pngURL(invoiceId: UUID) -> URL {
        signatureDirectory().appendingPathComponent("\(invoiceId.uuidString).png")
    }

    static func hasSignature(for invoiceId: UUID) -> Bool {
        FileManager.default.fileExists(atPath: pngURL(invoiceId: invoiceId).path)
    }

    static func loadPNG(for invoiceId: UUID) -> Data? {
        let url = pngURL(invoiceId: invoiceId)
        return try? Data(contentsOf: url)
    }

    static func loadImage(for invoiceId: UUID) -> UIImage? {
        guard let data = loadPNG(for: invoiceId) else { return nil }
        return UIImage(data: data)
    }

    @discardableResult
    static func savePNG(_ data: Data, for invoiceId: UUID) -> Bool {
        do {
            try ensureDirectory()
            try data.write(to: pngURL(invoiceId: invoiceId), options: .atomic)
            return true
        } catch {
            return false
        }
    }

    @discardableResult
    static func clearSignature(for invoiceId: UUID) -> Bool {
        let url = pngURL(invoiceId: invoiceId)
        guard FileManager.default.fileExists(atPath: url.path) else { return true }
        do {
            try FileManager.default.removeItem(at: url)
            return true
        } catch {
            return false
        }
    }

    private static func signatureDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(folderName, isDirectory: true)
    }

    private static func ensureDirectory() throws {
        try FileManager.default.createDirectory(
            at: signatureDirectory(),
            withIntermediateDirectories: true
        )
    }
}
