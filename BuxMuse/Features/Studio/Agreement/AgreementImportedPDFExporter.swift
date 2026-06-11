//
//  AgreementImportedPDFExporter.swift
//  BuxMuse — WYSIWYG signed PDF export for imported agreements.
//

import PDFKit
import PencilKit
import UIKit

enum AgreementImportedPDFExporter {
    static func exportSignedPDF(draft: AgreementDraft) -> Data? {
        guard draft.hasImportedSource,
              let sourcePath = draft.importedSourcePath else { return nil }

        switch draft.importedSourceKindValue {
        case .pdf:
            return exportPDFSource(draft: draft, sourcePath: sourcePath)
        case .image, .none:
            return exportImageSource(draft: draft, sourcePath: sourcePath)
        }
    }

    static func previewPageImage(
        draft: AgreementDraft,
        pageIndex: Int,
        scale: CGFloat = 1.5
    ) -> UIImage? {
        guard draft.hasImportedSource,
              let sourcePath = draft.importedSourcePath,
              let pageSize = AgreementDocumentStore.pageDocumentSize(
                path: sourcePath,
                pageIndex: pageIndex,
                kind: draft.importedSourceKindValue
              ) else { return nil }

        let renderSize = CGSize(width: pageSize.width * scale, height: pageSize.height * scale)
        let renderer = UIGraphicsImageRenderer(size: renderSize)
        return renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: renderSize))

            if draft.importedSourceKindValue == .pdf,
               let document = AgreementDocumentStore.loadPDFDocument(path: sourcePath),
               pageIndex < document.pageCount,
               let page = document.page(at: pageIndex) {
                let box = page.bounds(for: .mediaBox)
                ctx.cgContext.saveGState()
                ctx.cgContext.scaleBy(x: scale, y: scale)
                ctx.cgContext.translateBy(x: 0, y: box.height)
                ctx.cgContext.scaleBy(x: 1, y: -1)
                page.draw(with: .mediaBox, to: ctx.cgContext)
                ctx.cgContext.restoreGState()
            } else if let image = AgreementDocumentStore.loadPreviewImage(path: sourcePath) {
                image.draw(in: CGRect(origin: .zero, size: renderSize))
            }

            ctx.cgContext.saveGState()
            ctx.cgContext.scaleBy(x: scale, y: scale)
            drawOverlaysUIKit(
                draft: draft,
                pageIndex: pageIndex,
                pageSize: pageSize
            )
            ctx.cgContext.restoreGState()
        }
    }

    private static func exportPDFSource(draft: AgreementDraft, sourcePath: String) -> Data? {
        guard let document = AgreementDocumentStore.loadPDFDocument(path: sourcePath),
              document.pageCount > 0,
              let firstPage = document.page(at: 0) else { return nil }

        let firstBounds = firstPage.bounds(for: .mediaBox)
        let pdfRenderer = UIGraphicsPDFRenderer(bounds: firstBounds)

        return pdfRenderer.pdfData { pdfContext in
            for index in 0..<document.pageCount {
                guard let page = document.page(at: index) else { continue }
                let bounds = page.bounds(for: .mediaBox)
                pdfContext.beginPage(withBounds: bounds, pageInfo: [:])

                let ctx = pdfContext.cgContext
                ctx.saveGState()
                ctx.translateBy(x: 0, y: bounds.height)
                ctx.scaleBy(x: 1, y: -1)
                page.draw(with: .mediaBox, to: ctx)
                ctx.restoreGState()

                drawOverlaysUIKit(
                    draft: draft,
                    pageIndex: index,
                    pageSize: bounds.size
                )
            }
        }
    }

    private static func exportImageSource(draft: AgreementDraft, sourcePath: String) -> Data? {
        guard let image = AgreementDocumentStore.loadPreviewImage(path: sourcePath) else { return nil }
        let pageSize = image.size
        let bounds = CGRect(origin: .zero, size: pageSize)
        let pdfRenderer = UIGraphicsPDFRenderer(bounds: bounds)

        return pdfRenderer.pdfData { pdfContext in
            pdfContext.beginPage(withBounds: bounds, pageInfo: [:])
            image.draw(in: bounds)
            drawOverlaysUIKit(
                draft: draft,
                pageIndex: 0,
                pageSize: pageSize
            )
        }
    }

    /// Top-left page space — matches on-screen preview after the base page is drawn upright.
    private static func drawOverlaysUIKit(
        draft: AgreementDraft,
        pageIndex: Int,
        pageSize: CGSize
    ) {
        let annotation = AgreementImportedPageAnnotationStore.loadOrDefault(
            agreementId: draft.id,
            pageIndex: pageIndex,
            pageSize: pageSize
        )

        if AgreementImportedDocumentLimits.canMarkUp(pageIndex: pageIndex, pageCount: max(pageIndex + 1, 1)) {
            let drawing = AgreementImportedMarkupStore.loadDrawing(for: draft.id, pageIndex: pageIndex)
            let canvasSize = annotation.markupCanvasSize ?? pageSize
            if let markupImage = AgreementImportedPageGeometry.renderMarkup(
                drawing,
                canvasSize: canvasSize,
                pageSize: pageSize
            ) {
                markupImage.draw(in: CGRect(origin: .zero, size: pageSize))
            }
        }

        var placements = annotation.signaturePlacements
        if placements.isEmpty {
            placements = legacyFallbackPlacements(for: draft, pageIndex: pageIndex, pageSize: pageSize)
        }

        for placement in placements {
            guard let role = placement.signatureRole,
                  let image = signatureImage(for: role, draft: draft) else { continue }
            let rect = placement.normalizedRect.cgRect(in: pageSize)
            drawRotatedImageUIKit(
                image,
                in: rect,
                rotationDegrees: placement.rotationDegrees
            )
        }
    }

    private static func drawRotatedImageUIKit(
        _ image: UIImage,
        in rect: CGRect,
        rotationDegrees: Double
    ) {
        guard let context = UIGraphicsGetCurrentContext() else {
            image.draw(in: rect)
            return
        }

        context.saveGState()
        if abs(rotationDegrees) > 0.001 {
            context.translateBy(x: rect.midX, y: rect.midY)
            context.rotate(by: CGFloat(-rotationDegrees * .pi / 180))
            context.translateBy(x: -rect.midX, y: -rect.midY)
        }
        image.draw(in: rect)
        context.restoreGState()
    }

    /// Keeps prior export behaviour when signatures were captured outside the document studio.
    private static func legacyFallbackPlacements(
        for draft: AgreementDraft,
        pageIndex: Int,
        pageSize: CGSize
    ) -> [AgreementImportedSignaturePlacement] {
        let signableCount = min(
            AgreementDocumentStore.pageCount(path: draft.importedSourcePath),
            AgreementImportedDocumentLimits.maxSignablePages
        )
        let signaturePageIndex = max(0, signableCount - 1)
        guard pageIndex == signaturePageIndex else { return [] }

        var placements: [AgreementImportedSignaturePlacement] = []
        let aspect = pageSize.width / max(pageSize.height, 1)

        if draft.clientSignaturePNG != nil {
            placements.append(
                AgreementImportedSignaturePlacement(
                    id: UUID(),
                    role: AgreementSignatureRole.client.storageKey,
                    normalizedRect: AgreementImportedNormalizedRect(
                        x: 0.06,
                        y: 0.82,
                        width: 0.28,
                        height: 0.09
                    ).clamped()
                )
            )
        }

        if draft.providerSignaturePNG != nil {
            var rect = AgreementImportedNormalizedRect.centeredStamp(pageAspect: aspect)
            rect.x = 0.66
            rect.y = 0.82
            placements.append(
                AgreementImportedSignaturePlacement(
                    id: UUID(),
                    role: AgreementSignatureRole.provider.storageKey,
                    normalizedRect: rect.clamped()
                )
            )
        }

        return placements
    }

    private static func signatureImage(for role: AgreementSignatureRole, draft: AgreementDraft) -> UIImage? {
        let data: Data?
        switch role {
        case .provider:
            data = draft.providerSignaturePNG
        case .client:
            data = draft.clientSignaturePNG
        }
        return data
            .flatMap { AgreementImportedSignatureRasterizer.image(from: $0) }
            .map { $0.studioAgreementUprightImage() }
    }

    /// Retained for callers that still composite page bitmaps (preview paths).
    static func compositedPageImage(
        path: String,
        agreementId: UUID,
        pageIndex: Int,
        kind: AgreementImportedSourceKind?,
        draft: AgreementDraft
    ) -> UIImage? {
        previewPageImage(draft: draft, pageIndex: pageIndex)
    }
}
