//
//  ProBusinessCardShareActions.swift
//  BuxMuse
//
//  Share finished cards via the iOS share sheet — Mail, Messages, WhatsApp, etc.
//

import SwiftUI
import UIKit

enum ProBusinessCardShareActions {

    @MainActor
    static func shareCard(
        design: ProBusinessCardDesign,
        logoData: Data?,
        message: String? = nil
    ) {
        var items: [Any] = []

        if let pngData = ProBusinessCardExport.pngData(design: design, logoData: logoData),
           let image = UIImage(data: pngData) {
            items.append(image)
        }

        let card = SimpleBusinessCard(
            name: design.content.name,
            tagline: design.content.tagline,
            phone: design.content.phone,
            email: design.content.email,
            skills: design.content.skills,
            photoPath: design.content.photoPath
        )
        if let vcardURL = SimpleStudioVCardExporter.temporaryFileURL(
            for: card,
            photo: SimpleStudioScanImageStore.load(path: design.content.photoPath)
        ) {
            items.append(vcardURL)
        }

        let text = message ?? defaultMessage(for: design)
        items.append(text)

        guard !items.isEmpty else { return }
        SimpleStudioShareHelper.present(items: items)
    }

    @MainActor
    static func sharePDF(design: ProBusinessCardDesign, logoData: Data?) {
        guard let data = ProBusinessCardExport.generatePDF(design: design, logoData: logoData),
              let url = ProBusinessCardExport.temporaryFileURL(data: data, filename: "\(sanitizedTitle(design.title)).pdf") else { return }
        SimpleStudioShareHelper.present(items: [url])
    }

    @MainActor
    static func sharePNG(design: ProBusinessCardDesign, logoData: Data?) {
        guard let data = ProBusinessCardExport.pngData(design: design, logoData: logoData),
              let url = ProBusinessCardExport.temporaryFileURL(data: data, filename: "\(sanitizedTitle(design.title)).png") else { return }
        SimpleStudioShareHelper.present(items: [url])
    }

    @MainActor
    static func shareVCard(design: ProBusinessCardDesign, logoData: Data?) {
        let card = SimpleBusinessCard(
            name: design.content.name,
            tagline: design.content.tagline,
            phone: design.content.phone,
            email: design.content.email,
            skills: design.content.skills,
            photoPath: design.content.photoPath
        )
        guard let url = SimpleStudioVCardExporter.temporaryFileURL(
            for: card,
            photo: SimpleStudioScanImageStore.load(path: design.content.photoPath)
        ) else { return }
        SimpleStudioShareHelper.present(items: [url, defaultMessage(for: design)])
    }

    private static func defaultMessage(for design: ProBusinessCardDesign) -> String {
        let name = design.content.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty { return "My business card" }
        return "Here's my business card — \(name)"
    }

    private static func sanitizedTitle(_ title: String) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "business-card" : trimmed.replacingOccurrences(of: " ", with: "-")
    }
}
