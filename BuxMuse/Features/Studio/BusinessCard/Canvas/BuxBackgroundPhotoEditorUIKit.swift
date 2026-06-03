//
//  BuxBackgroundPhotoEditorUIKit.swift
//  BuxMuse — UIKit crop export matching on-screen preview (iOS 18+)
//

import SwiftUI
import UIKit

// MARK: - Aspect crop export (matches ImageCropEditorContent / SwiftUI layout)

enum BuxAspectPhotoCropEngine {
    static func crop(
        image: UIImage,
        cropFrameSize: CGSize,
        viewportSide: CGFloat,
        scale: CGFloat,
        offset: CGSize,
        cornerRadius: CGFloat,
        exportSize: CGSize,
        paperColorHex: String
    ) -> UIImage? {
        let source = image.normalizedImage()
        let viewport = viewportSide
        let fit = min(viewport / source.size.width, viewport / source.size.height)
        let displayW = source.size.width * fit * scale
        let displayH = source.size.height * fit * scale
        let centerX = viewport / 2 + offset.width
        let centerY = viewport / 2 + offset.height
        let imageRect = CGRect(
            x: centerX - displayW / 2,
            y: centerY - displayH / 2,
            width: displayW,
            height: displayH
        )

        let cropRect = CGRect(
            x: (viewport - cropFrameSize.width) / 2,
            y: (viewport - cropFrameSize.height) / 2,
            width: cropFrameSize.width,
            height: cropFrameSize.height
        )

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true

        let snippet = UIGraphicsImageRenderer(size: cropFrameSize, format: format).image { ctx in
            let paper = UIColor(Color(hex: paperColorHex))
            paper.setFill()
            UIRectFill(CGRect(origin: .zero, size: cropFrameSize))
            let clip = UIBezierPath(roundedRect: CGRect(origin: .zero, size: cropFrameSize), cornerRadius: cornerRadius)
            clip.addClip()
            ctx.cgContext.translateBy(x: -cropRect.minX, y: -cropRect.minY)
            source.draw(in: imageRect)
        }

        let cornerExport = cornerRadius * (exportSize.width / max(1, cropFrameSize.width))
        let masked = snippet.roundedRectMasked(cornerRadius: cornerExport)

        return UIGraphicsImageRenderer(size: exportSize, format: format).image { ctx in
            paperColorHexUIColor(hex: paperColorHex).setFill()
            UIRectFill(CGRect(origin: .zero, size: exportSize))
            masked.draw(in: CGRect(origin: .zero, size: exportSize))
        }
    }

    private static func paperColorHexUIColor(hex: String) -> UIColor {
        UIColor(Color(hex: hex))
    }
}

// MARK: - Freeform → card export (clip to card shape, paper in corners)

enum BuxFreeformPhotoCropEngine {
    static func crop(
        image: UIImage,
        viewport: CGSize,
        scale: CGFloat,
        offset: CGSize,
        cropWidthFraction: CGFloat,
        cropHeightFraction: CGFloat,
        exportSize: CGSize,
        cardAspect: ProBusinessCardAspect,
        cornerRadius: CGFloat,
        paperColorHex: String
    ) -> UIImage? {
        let source = image.normalizedImage()
        let viewW = viewport.width
        let viewH = viewport.height

        let fit = min(viewW / source.size.width, viewH / source.size.height)
        let drawW = source.size.width * fit * scale
        let drawH = source.size.height * fit * scale
        let originX = (viewW - drawW) / 2 + offset.width
        let originY = (viewH - drawH) / 2 + offset.height

        var cropW = viewW * cropWidthFraction
        var cropH = viewH * cropHeightFraction
        let targetRatio = cardAspect.aspectRatio
        let currentRatio = cropW / max(1, cropH)
        if currentRatio > targetRatio {
            cropW = cropH * targetRatio
        } else {
            cropH = cropW / targetRatio
        }
        let cropX = (viewW - cropW) / 2
        let cropY = (viewH - cropH) / 2
        let cropRect = CGRect(x: cropX, y: cropY, width: cropW, height: cropH)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true

        let viewportImage = UIGraphicsImageRenderer(size: viewport, format: format).image { _ in
            UIColor.black.setFill()
            UIRectFill(CGRect(origin: .zero, size: viewport))
            source.draw(in: CGRect(x: originX, y: originY, width: drawW, height: drawH))
        }

        guard let cg = viewportImage.cgImage,
              let cropped = cg.cropping(to: cropRect) else { return nil }

        let snippet = UIImage(cgImage: cropped, scale: 1, orientation: .up)
        let radius = cornerRadius * (exportSize.width / max(1, cropW))
        let masked = snippet.roundedRectMasked(cornerRadius: radius)

        return UIGraphicsImageRenderer(size: exportSize, format: format).image { _ in
            UIColor(Color(hex: paperColorHex)).setFill()
            UIRectFill(CGRect(origin: .zero, size: exportSize))
            masked.draw(in: CGRect(origin: .zero, size: exportSize))
        }
    }
}
