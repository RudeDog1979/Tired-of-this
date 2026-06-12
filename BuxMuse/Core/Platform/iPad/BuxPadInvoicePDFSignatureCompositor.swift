//
//  BuxPadInvoicePDFSignatureCompositor.swift
//  BuxMuse — Embeds stored Pencil signatures into exported invoice PDFs.
//

import PDFKit
import UIKit

enum BuxPadInvoicePDFExport {
    static func finalizePDF(_ data: Data, invoiceId: UUID) -> Data {
        BuxPadInvoicePDFSignatureCompositor.embedSignature(in: data, invoiceId: invoiceId) ?? data
    }
}

enum BuxPadInvoicePDFSignatureCompositor {
    static func embedSignature(in pdfData: Data, invoiceId: UUID) -> Data? {
        guard let signatureImage = BuxPadInvoiceSignatureStore.loadImage(for: invoiceId),
              let document = PDFDocument(data: pdfData),
              document.pageCount > 0,
              let lastPage = document.page(at: document.pageCount - 1) else {
            return nil
        }

        let pageBounds = lastPage.bounds(for: .mediaBox)
        let output = NSMutableData()
        guard let consumer = CGDataConsumer(data: output as CFMutableData) else { return nil }

        var mediaBox = pageBounds
        guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else { return nil }

        for index in 0..<document.pageCount {
            guard let page = document.page(at: index) else { continue }
            let bounds = page.bounds(for: .mediaBox)
            context.beginPDFPage(nil)
            context.saveGState()
            context.translateBy(x: 0, y: bounds.height)
            context.scaleBy(x: 1, y: -1)
            page.draw(with: .mediaBox, to: context)

            if index == document.pageCount - 1 {
                drawSignature(signatureImage, in: bounds, context: context)
            }

            context.restoreGState()
            context.endPDFPage()
        }

        context.closePDF()
        return output as Data
    }

    private static func drawSignature(_ image: UIImage, in pageBounds: CGRect, context: CGContext) {
        let maxWidth: CGFloat = 180
        let maxHeight: CGFloat = 56
        let aspect = image.size.width / max(image.size.height, 1)
        var width = maxWidth
        var height = width / aspect
        if height > maxHeight {
            height = maxHeight
            width = height * aspect
        }

        let rect = CGRect(
            x: pageBounds.maxX - width - 56,
            y: pageBounds.height - height - 72,
            width: width,
            height: height
        )

        if let cgImage = image.cgImage {
            context.draw(cgImage, in: rect)
        }
    }
}
