//
//  ProBusinessCardExport.swift
//  BuxMuse
//

import SwiftUI
import UIKit

enum ProBusinessCardExport {

    @MainActor
    static func renderImage(
        design: ProBusinessCardDesign,
        logoData: Data?,
        scale: CGFloat = 2
    ) -> UIImage? {
        if design.canvasDocument != nil,
           let ctx = CardCanvasRenderContext.make(design: design, logoData: logoData) {
            let view = CardCanvasRenderer(context: ctx)
            let renderer = ImageRenderer(content: view)
            renderer.scale = scale
            return renderer.uiImage
        }
        let context = ProBusinessCardRenderFactory.makeContext(design: design, logoData: logoData)
        let view = ProBusinessCardRenderer(context: context)
        let renderer = ImageRenderer(content: view)
        renderer.scale = scale
        return renderer.uiImage
    }

    @MainActor
    static func generatePDF(
        design: ProBusinessCardDesign,
        logoData: Data?
    ) -> Data? {
        guard let image = renderImage(design: design, logoData: logoData, scale: 3) else { return nil }
        let pageSize = design.aspect.printSize
        let pdfBounds = CGRect(origin: .zero, size: pageSize)
        let format = UIGraphicsPDFRendererFormat()
        let pdfRenderer = UIGraphicsPDFRenderer(bounds: pdfBounds, format: format)

        return pdfRenderer.pdfData { context in
            context.beginPage()
            let maxWidth = pageSize.width - 24
            let maxHeight = pageSize.height - 24
            let scale = min(maxWidth / image.size.width, maxHeight / image.size.height)
            let drawSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            let origin = CGPoint(
                x: (pageSize.width - drawSize.width) / 2,
                y: (pageSize.height - drawSize.height) / 2
            )
            image.draw(in: CGRect(origin: origin, size: drawSize))
        }
    }

    static func temporaryFileURL(data: Data, filename: String) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    @MainActor
    static func pngData(
        design: ProBusinessCardDesign,
        logoData: Data?
    ) -> Data? {
        renderImage(design: design, logoData: logoData, scale: 3)?.pngData()
    }
}
