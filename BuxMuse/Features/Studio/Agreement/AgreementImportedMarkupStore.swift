//
//  AgreementImportedMarkupStore.swift
//  BuxMuse — Per-page Pencil markup sidecars for imported agreements.
//

import Foundation
import PencilKit

enum AgreementImportedMarkupStore {
    private static let folderName = "StudioAgreementMarkups"

    static func drawingURL(agreementId: UUID, pageIndex: Int) -> URL {
        markupDirectory().appendingPathComponent("\(agreementId.uuidString)-page-\(pageIndex).markup.drawing")
    }

    static func hasMarkup(for agreementId: UUID, pageIndex: Int) -> Bool {
        FileManager.default.fileExists(atPath: drawingURL(agreementId: agreementId, pageIndex: pageIndex).path)
    }

    static func hasAnyMarkup(for agreementId: UUID, pageCount: Int) -> Bool {
        guard pageCount > 0 else { return false }
        let limit = min(pageCount, AgreementImportedDocumentLimits.maxSignablePages)
        for index in 0..<limit where hasMarkup(for: agreementId, pageIndex: index) {
            return true
        }
        return false
    }

    static func loadDrawing(for agreementId: UUID, pageIndex: Int) -> PKDrawing {
        let url = drawingURL(agreementId: agreementId, pageIndex: pageIndex)
        guard let data = try? Data(contentsOf: url),
              let drawing = try? PKDrawing(data: data) else {
            return PKDrawing()
        }
        return drawing
    }

    @discardableResult
    static func saveDrawing(_ drawing: PKDrawing, for agreementId: UUID, pageIndex: Int) -> Bool {
        let url = drawingURL(agreementId: agreementId, pageIndex: pageIndex)
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

    static func deleteAllMarkups(for agreementId: UUID, pageCount: Int) {
        let limit = min(pageCount, AgreementImportedDocumentLimits.maxSignablePages)
        for index in 0..<limit {
            try? FileManager.default.removeItem(at: drawingURL(agreementId: agreementId, pageIndex: index))
            AgreementImportedPageAnnotationStore.deletePage(agreementId: agreementId, pageIndex: index)
        }
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
