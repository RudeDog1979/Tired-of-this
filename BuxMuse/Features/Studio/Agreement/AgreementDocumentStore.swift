//
//  AgreementDocumentStore.swift
//  BuxMuse
//
//  On-device signed agreement PDFs / scans (privacy-first).
//

import Foundation
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

    static func loadData(path storedPath: String?) -> Data? {
        guard let url = resolveURL(for: storedPath) else { return nil }
        return try? Data(contentsOf: url)
    }

    static func loadPreviewImage(path storedPath: String?) -> UIImage? {
        guard let data = loadData(path: storedPath) else { return nil }
        if let image = UIImage(data: data) { return image }
        return nil
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

    static var importContentTypes: [UTType] {
        [.pdf, .png, .jpeg, .heic, .image]
    }
}
