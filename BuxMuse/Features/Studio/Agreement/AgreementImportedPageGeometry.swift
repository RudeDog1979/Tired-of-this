//
//  AgreementImportedPageGeometry.swift
//  BuxMuse — Aspect-fit layout + normalized page coordinates for imported agreements.
//

import CoreGraphics
import PencilKit
import UIKit

struct AgreementImportedNormalizedRect: Codable, Equatable, Sendable {
    var x: CGFloat
    var y: CGFloat
    var width: CGFloat
    var height: CGFloat

    static func centeredStamp(pageAspect: CGFloat, widthFraction: CGFloat = 0.28, heightFraction: CGFloat = 0.09) -> AgreementImportedNormalizedRect {
        var height = heightFraction
        var width = widthFraction
        let stampAspect = width / max(height, 0.001)
        if stampAspect > pageAspect {
            width = height * pageAspect
        } else {
            height = width / max(pageAspect, 0.001)
        }
        return AgreementImportedNormalizedRect(
            x: max(0, 0.5 - width / 2),
            y: max(0, 0.72 - height / 2),
            width: width,
            height: height
        )
    }

    static func stamp(
        centeredAt point: CGPoint,
        pageAspect: CGFloat,
        widthFraction: CGFloat = 0.22,
        heightFraction: CGFloat = 0.07
    ) -> AgreementImportedNormalizedRect {
        var rect = centeredStamp(
            pageAspect: pageAspect,
            widthFraction: widthFraction,
            heightFraction: heightFraction
        )
        rect.x = point.x - rect.width / 2
        rect.y = point.y - rect.height / 2
        return rect.clamped()
    }

    func clamped() -> AgreementImportedNormalizedRect {
        var copy = self
        copy.width = min(max(width, 0.05), 1)
        copy.height = min(max(height, 0.03), 1)
        copy.x = min(max(x, 0), 1 - copy.width)
        copy.y = min(max(y, 0), 1 - copy.height)
        return copy
    }

    func cgRect(in pageSize: CGSize) -> CGRect {
        CGRect(
            x: x * pageSize.width,
            y: y * pageSize.height,
            width: width * pageSize.width,
            height: height * pageSize.height
        )
    }

    func viewRect(in fitRect: CGRect) -> CGRect {
        CGRect(
            x: fitRect.minX + x * fitRect.width,
            y: fitRect.minY + y * fitRect.height,
            width: width * fitRect.width,
            height: height * fitRect.height
        )
    }

    static func from(viewRect: CGRect, in fitRect: CGRect) -> AgreementImportedNormalizedRect {
        guard fitRect.width > 0, fitRect.height > 0 else {
            return AgreementImportedNormalizedRect(x: 0.1, y: 0.8, width: 0.25, height: 0.08)
        }
        return AgreementImportedNormalizedRect(
            x: (viewRect.minX - fitRect.minX) / fitRect.width,
            y: (viewRect.minY - fitRect.minY) / fitRect.height,
            width: viewRect.width / fitRect.width,
            height: viewRect.height / fitRect.height
        ).clamped()
    }
}

enum AgreementImportedPageGeometry {
    static func aspectFitRect(contentSize: CGSize, in containerSize: CGSize) -> CGRect {
        guard contentSize.width > 0, contentSize.height > 0,
              containerSize.width > 0, containerSize.height > 0 else {
            return .zero
        }
        let scale = min(containerSize.width / contentSize.width, containerSize.height / contentSize.height)
        let fitted = CGSize(width: contentSize.width * scale, height: contentSize.height * scale)
        let origin = CGPoint(
            x: (containerSize.width - fitted.width) / 2,
            y: (containerSize.height - fitted.height) / 2
        )
        return CGRect(origin: origin, size: fitted)
    }

    /// Renders Pencil markup from canvas space into page space (top-left origin, upright).
    static func renderMarkup(
        _ drawing: PKDrawing,
        canvasSize: CGSize,
        pageSize: CGSize
    ) -> UIImage? {
        guard !drawing.bounds.isEmpty,
              canvasSize.width > 0, canvasSize.height > 0,
              pageSize.width > 0, pageSize.height > 0 else {
            return nil
        }

        let pixelScale = max(2, pageSize.width / canvasSize.width)
        let markup = drawing.image(from: CGRect(origin: .zero, size: canvasSize), scale: pixelScale)
        let renderer = UIGraphicsImageRenderer(size: pageSize)
        return renderer.image { _ in
            markup.draw(in: CGRect(origin: .zero, size: pageSize))
        }
    }

    static func drawMarkupImage(_ markupImage: UIImage, in pageBounds: CGRect, context: CGContext) {
        guard let cgImage = markupImage.cgImage else { return }
        context.saveGState()
        context.translateBy(x: 0, y: pageBounds.height)
        context.scaleBy(x: 1, y: -1)
        context.draw(cgImage, in: pageBounds)
        context.restoreGState()
    }

    static func drawRotatedSignatureImage(
        _ image: UIImage,
        in rect: CGRect,
        rotationDegrees: Double,
        context: CGContext
    ) {
        guard abs(rotationDegrees) > 0.001 else {
            drawUIImage(image, in: rect, context: context)
            return
        }
        context.saveGState()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        context.translateBy(x: center.x, y: center.y)
        context.rotate(by: CGFloat(-rotationDegrees * .pi / 180))
        context.translateBy(x: -center.x, y: -center.y)
        drawUIImage(image, in: rect, context: context)
        context.restoreGState()
    }

    static func drawUIImage(_ image: UIImage, in rect: CGRect, context: CGContext) {
        guard let cgImage = image.cgImage else { return }
        context.saveGState()
        context.translateBy(x: 0, y: rect.maxY + rect.minY)
        context.scaleBy(x: 1, y: -1)
        context.draw(cgImage, in: rect)
        context.restoreGState()
    }
}
