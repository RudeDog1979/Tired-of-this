//
//  SimpleStudioScanImageStore.swift
//  BuxMuse
//

import Foundation
import UIKit

enum SimpleStudioScanImageStore {

    static let relativePrefix = "scans/"

    private static var scansDirectory: URL {
        let fm = FileManager.default
        let dir = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Studio/scans", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    /// Stable id for the saved business-card photo.
    static let businessCardPhotoId = UUID(uuidString: "B1D00000-0000-4000-8000-000000000001")!

    static func saveBusinessCardPhoto(_ image: UIImage) -> String? {
        save(image, id: businessCardPhotoId)
    }

    /// Persists image and returns a stable relative path stored in JSON.
    static func save(_ image: UIImage, id: UUID) -> String? {
        guard let data = image.jpegData(compressionQuality: 0.82) else { return nil }
        let filename = "\(id.uuidString).jpg"
        let file = scansDirectory.appendingPathComponent(filename)
        do {
            try data.write(to: file, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            return relativePrefix + filename
        } catch {
            print("SimpleStudioScanImageStore: save error \(error)")
            return nil
        }
    }

    static func load(path storedPath: String?) -> UIImage? {
        guard let fileURL = resolveURL(for: storedPath) else { return nil }
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        return UIImage(contentsOfFile: fileURL.path)
    }

    static func resolveURL(for storedPath: String?) -> URL? {
        guard let storedPath, !storedPath.isEmpty else { return nil }

        if storedPath.hasPrefix(relativePrefix) {
            let name = String(storedPath.dropFirst(relativePrefix.count))
            return scansDirectory.appendingPathComponent(name)
        }

        if storedPath.hasPrefix("/") {
            return URL(fileURLWithPath: storedPath)
        }

        return scansDirectory.appendingPathComponent(storedPath)
    }

    /// Converts legacy absolute paths to relative after load.
    static func normalizedStoredPath(_ storedPath: String?) -> String? {
        guard let storedPath, !storedPath.isEmpty else { return nil }
        if storedPath.hasPrefix(relativePrefix) { return storedPath }
        let filename = URL(fileURLWithPath: storedPath).lastPathComponent
        guard !filename.isEmpty else { return storedPath }
        return relativePrefix + filename
    }
}
