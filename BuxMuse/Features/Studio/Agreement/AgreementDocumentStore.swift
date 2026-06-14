//
//  AgreementDocumentStore.swift
//  BuxMuse
//
//  On-device signed agreement PDFs / scans (privacy-first).
//

import Foundation
import PDFKit
import UIKit
import UniformTypeIdentifiers

enum AgreementDocumentStore {

    static let relativePrefix = "agreements/"

    private static var agreementsDirectory: URL {
        let fm = FileManager.default
        let dir = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Studio/agreements", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    static func save(data: Data, agreementId: UUID, fileExtension: String) -> String? {
        let ext = fileExtension.hasPrefix(".") ? String(fileExtension.dropFirst()) : fileExtension
        let filename = "\(agreementId.uuidString).\(ext)"
        let file = agreementsDirectory.appendingPathComponent(filename)
        do {
            try data.write(to: file, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            return relativePrefix + filename
        } catch {
            print("AgreementDocumentStore: save error \(error)")
            return nil
        }
    }

    static func saveImportedFile(at sourceURL: URL, agreementId: UUID) -> String? {
        let ext = sourceURL.pathExtension.isEmpty ? "pdf" : sourceURL.pathExtension
        guard let data = try? Data(contentsOf: sourceURL) else { return nil }
        return save(data: data, agreementId: agreementId, fileExtension: ext)
    }

    /// Saves the customer's original agreement as `{id}-source.{ext}` (separate from proof attachments).
    static func saveImportedSource(at sourceURL: URL, agreementId: UUID) -> (path: String, kind: AgreementImportedSourceKind)? {
        let ext = normalizedExtension(for: sourceURL)
        guard let kind = sourceKind(forExtension: ext) else { return nil }
        guard let data = try? Data(contentsOf: sourceURL) else { return nil }

        if kind == .pdf, let document = PDFDocument(data: data) {
            let pages = document.pageCount
            if pages > AgreementImportedDocumentLimits.maxStoredPages {
                return nil
            }
            if pages == 0 { return nil }
        }

        let filename = "\(agreementId.uuidString)-source.\(ext)"
        let file = agreementsDirectory.appendingPathComponent(filename)
        do {
            try data.write(to: file, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            return (relativePrefix + filename, kind)
        } catch {
            print("AgreementDocumentStore: imported source save error \(error)")
            return nil
        }
    }

    static func saveSignedExport(data: Data, agreementId: UUID) -> String? {
        let filename = "\(agreementId.uuidString)-signed-export.pdf"
        let file = agreementsDirectory.appendingPathComponent(filename)
        do {
            try data.write(to: file, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            return relativePrefix + filename
        } catch {
            print("AgreementDocumentStore: signed export save error \(error)")
            return nil
        }
    }

    static func pageCount(path storedPath: String?) -> Int {
        guard let storedPath else { return 0 }
        if isPDF(path: storedPath),
           let data = loadData(path: storedPath),
           let document = PDFDocument(data: data) {
            return document.pageCount
        }
        if loadPreviewImage(path: storedPath) != nil {
            return 1
        }
        return 0
    }

    static func renderPageImage(path storedPath: String?, pageIndex: Int, scale: CGFloat = 2) -> UIImage? {
        guard isPDF(path: storedPath),
              let data = loadData(path: storedPath),
              let document = PDFDocument(data: data),
              pageIndex >= 0,
              pageIndex < document.pageCount,
              let page = document.page(at: pageIndex) else {
            return nil
        }

        let bounds = page.bounds(for: .mediaBox)
        let size = CGSize(width: bounds.width * scale, height: bounds.height * scale)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            ctx.cgContext.translateBy(x: 0, y: size.height)
            ctx.cgContext.scaleBy(x: scale, y: -scale)
            page.draw(with: .mediaBox, to: ctx.cgContext)
        }
    }

    static func importedSourcePageCountExceeded(at sourceURL: URL) -> Int? {
        let ext = normalizedExtension(for: sourceURL)
        guard ext == "pdf",
              let data = try? Data(contentsOf: sourceURL),
              let document = PDFDocument(data: data) else { return nil }
        let count = document.pageCount
        return count > AgreementImportedDocumentLimits.maxStoredPages ? count : nil
    }

    static func loadData(path storedPath: String?) -> Data? {
        guard let url = resolveURL(for: storedPath) else { return nil }
        return try? Data(contentsOf: url)
    }

    static func loadPreviewImage(path storedPath: String?) -> UIImage? {
        guard let data = loadData(path: storedPath),
              let image = UIImage(data: data) else { return nil }
        return image.buxOrientedUp()
    }

    static func pageDocumentSize(path storedPath: String?, pageIndex: Int, kind: AgreementImportedSourceKind?) -> CGSize? {
        switch kind {
        case .pdf:
            guard isPDF(path: storedPath),
                  let data = loadData(path: storedPath),
                  let document = PDFDocument(data: data),
                  pageIndex >= 0,
                  pageIndex < document.pageCount,
                  let page = document.page(at: pageIndex) else { return nil }
            let box = page.bounds(for: .mediaBox)
            return box.size
        case .image:
            guard pageIndex == 0,
                  let image = loadPreviewImage(path: storedPath) else { return nil }
            return image.size
        case .none:
            return nil
        }
    }

    static func loadPDFDocument(path storedPath: String?) -> PDFDocument? {
        guard isPDF(path: storedPath),
              let data = loadData(path: storedPath) else { return nil }
        return PDFDocument(data: data)
    }

    static func isPDF(path storedPath: String?) -> Bool {
        guard let url = resolveURL(for: storedPath) else { return false }
        return url.pathExtension.lowercased() == "pdf"
    }

    static func resolveURL(for storedPath: String?) -> URL? {
        guard let storedPath, !storedPath.isEmpty else { return nil }
        if storedPath.hasPrefix(relativePrefix) {
            let name = String(storedPath.dropFirst(relativePrefix.count))
            return agreementsDirectory.appendingPathComponent(name)
        }
        if storedPath.hasPrefix("/") {
            return URL(fileURLWithPath: storedPath)
        }
        return agreementsDirectory.appendingPathComponent(storedPath)
    }

    static func normalizedStoredPath(_ storedPath: String?) -> String? {
        guard let storedPath, !storedPath.isEmpty else { return nil }
        if storedPath.hasPrefix(relativePrefix) { return storedPath }
        let filename = URL(fileURLWithPath: storedPath).lastPathComponent
        guard !filename.isEmpty else { return storedPath }
        return relativePrefix + filename
    }

    static func delete(path storedPath: String?) {
        guard let url = resolveURL(for: storedPath) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    /// Writes synced bytes to the canonical agreements folder using a normalized relative path.
    @discardableResult
    static func writeSyncedFile(data: Data, relativePath: String) -> Bool {
        guard let normalized = normalizedStoredPath(relativePath),
              let url = resolveURL(for: normalized) else { return false }
        do {
            try FileManager.default.createDirectory(
                at: agreementsDirectory,
                withIntermediateDirectories: true
            )
            try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            return true
        } catch {
            print("AgreementDocumentStore: synced file write error \(error)")
            return false
        }
    }

    static func deleteAllSyncedFiles(for agreementId: UUID) {
        let prefix = agreementId.uuidString
        guard let files = try? FileManager.default.contentsOfDirectory(at: agreementsDirectory, includingPropertiesForKeys: nil) else {
            return
        }
        for file in files where file.lastPathComponent.hasPrefix(prefix) {
            try? FileManager.default.removeItem(at: file)
        }
        AgreementImportedMarkupStore.deleteAllMarkups(
            for: agreementId,
            pageCount: AgreementImportedDocumentLimits.maxSignablePages
        )
        AgreementImportedPageAnnotationStore.deleteAll(
            for: agreementId,
            pageCount: AgreementImportedDocumentLimits.maxSignablePages
        )
    }

    static var importContentTypes: [UTType] {
        [.pdf, .png, .jpeg, .heic, .image]
    }

    private static func normalizedExtension(for url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        return ext.isEmpty ? "pdf" : ext
    }

    private static func sourceKind(forExtension ext: String) -> AgreementImportedSourceKind? {
        switch ext {
        case "pdf":
            return .pdf
        case "png", "jpg", "jpeg", "heic", "heif", "gif", "webp", "tif", "tiff":
            return .image
        default:
            return nil
        }
    }
}

private extension UIImage {
    func buxOrientedUp() -> UIImage {
        guard imageOrientation != .up else { return self }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
