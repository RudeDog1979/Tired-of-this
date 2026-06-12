//
//  SimpleStudioBusinessCardPDFExporter.swift
//  BuxMuse
//

import SwiftUI
import UIKit

enum SimpleStudioBusinessCardPDFExporter {

    @MainActor
    static func generatePDF<Content: View>(from view: Content, pageSize: CGSize = CGSize(width: 612, height: 792)) -> Data? {
        let renderer = ImageRenderer(content: view.frame(width: 340))
        renderer.scale = 2

        guard let image = renderer.uiImage else { return nil }

        let pdfBounds = CGRect(origin: .zero, size: pageSize)
        let format = UIGraphicsPDFRendererFormat()
        let pdfRenderer = UIGraphicsPDFRenderer(bounds: pdfBounds, format: format)

        return pdfRenderer.pdfData { context in
            context.beginPage()
            let imageSize = image.size
            let maxWidth = pageSize.width - 80
            let maxHeight = pageSize.height - 80
            let scale = min(maxWidth / imageSize.width, maxHeight / imageSize.height, 1)
            let drawSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
            let origin = CGPoint(
                x: (pageSize.width - drawSize.width) / 2,
                y: (pageSize.height - drawSize.height) / 2
            )
            image.draw(in: CGRect(origin: origin, size: drawSize))
        }
    }

    static func temporaryFileURL(data: Data, filename: String = "BusinessCard.pdf") -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}
