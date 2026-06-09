//
//  BuxPadReceiptMarkupStore.swift
//  BuxMuse — Sidecar Pencil markup for Studio receipt scans (no receipt model changes).
//

import Foundation
import PencilKit
import UIKit

enum BuxPadReceiptMarkupStore {
    private static let folderName = "StudioReceiptMarkups"

    static func drawingURL(receiptId: UUID) -> URL {
        markupDirectory().appendingPathComponent("\(receiptId.uuidString).markup.drawing")
    }

    static func hasMarkup(for receiptId: UUID) -> Bool {
        FileManager.default.fileExists(atPath: drawingURL(receiptId: receiptId).path)
    }

    static func loadDrawing(for receiptId: UUID) -> PKDrawing {
        let url = drawingURL(receiptId: receiptId)
        guard let data = try? Data(contentsOf: url),
              let drawing = try? PKDrawing(data: data) else {
            return PKDrawing()
        }
        return drawing
    }

    @discardableResult
    static func saveDrawing(_ drawing: PKDrawing, for receiptId: UUID) -> Bool {
        let url = drawingURL(receiptId: receiptId)
        do {
            try ensureDirectory()
            if drawing.bounds.isEmpty {
                try? FileManager.default.removeItem(at: url)
                return true
            }
            try drawing.dataRepresentation().write(to: url, options: .atomic)
            return true
        } catch {
            return false
        }
    }

    static func loadReceiptImage(path: String?) -> UIImage? {
        guard let path, !path.isEmpty else { return nil }
        return UIImage(contentsOfFile: path)
    }

    static func previewImage(basePath: String?, receiptId: UUID) -> UIImage? {
        guard let base = loadReceiptImage(path: basePath) else { return nil }
        let drawing = loadDrawing(for: receiptId)
        return BuxPadPencilRasterizer.composite(base: base, drawing: drawing) ?? base
    }

    private static func markupDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(folderName, isDirectory: true)
    }

    private static func ensureDirectory() throws {
        try FileManager.default.createDirectory(
            at: markupDirectory(),
            withIntermediateDirectories: true
        )
    }
}
