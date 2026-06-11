//
//  AgreementImportedSignatureRasterizer.swift
//  BuxMuse — Transparent signature PNGs for imported agreement placement only.
//

import PencilKit
import SwiftUI
import UIKit

enum AgreementImportedSignatureRasterizer {
    /// `literalInk` — iPhone only at Place signature; iPad uses PencilKit literal strokes (unchanged).
    static func transparentPNG(from drawing: PKDrawing, literalInk: UIColor? = nil) -> Data? {
        guard !drawing.bounds.isEmpty else { return nil }
        let bounds = drawing.bounds.insetBy(dx: -12, dy: -12)
        let stroke = drawing.image(from: bounds, scale: 2)

        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        format.scale = stroke.scale
        let renderer = UIGraphicsImageRenderer(size: stroke.size, format: format)
        var image = renderer.image { _ in
            stroke.draw(at: .zero)
        }

        if let literalInk {
            image = image.applyingLiteralInkMask(literalInk)
        }

        return image.pngData()
    }

    static func image(from data: Data) -> UIImage? {
        guard let image = UIImage(data: data) else { return nil }
        return image.withRenderingMode(.alwaysOriginal)
    }
}

// MARK: - On-document stamp (Place signature → appears on page)

struct AgreementDocumentPlacedSignatureView: UIViewRepresentable {
    let image: UIImage

    func makeUIView(context: Context) -> UIImageView {
        let imageView = UIImageView()
        imageView.overrideUserInterfaceStyle = .light
        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = .clear
        imageView.isOpaque = false
        imageView.image = image.withRenderingMode(.alwaysOriginal)
        return imageView
    }

    func updateUIView(_ imageView: UIImageView, context: Context) {
        imageView.image = image.withRenderingMode(.alwaysOriginal)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UIImageView, context: Context) -> CGSize? {
        guard let width = proposal.width, let height = proposal.height else { return nil }
        return CGSize(width: width, height: height)
    }
}

private extension UIImage {
    /// Keeps stroke alpha from PencilKit; paints every opaque pixel with the picked literal sRGB ink.
    func applyingLiteralInkMask(_ ink: UIColor) -> UIImage {
        guard let cgImage = cgImage else { return self }
        let width = cgImage.width
        let height = cgImage.height
        guard width > 0, height > 0 else { return self }

        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var inkAlpha: CGFloat = 1
        guard ink.getRed(&red, green: &green, blue: &blue, alpha: &inkAlpha) else { return self }

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return self }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let pixels = context.data?.assumingMemoryBound(to: UInt8.self) else { return self }

        let bytesPerRow = context.bytesPerRow
        for y in 0..<height {
            for x in 0..<width {
                let index = y * bytesPerRow + x * 4
                let shapeAlpha = pixels[index + 3]
                guard shapeAlpha > 0 else { continue }

                let coverage = CGFloat(shapeAlpha) / 255
                pixels[index] = UInt8(clamping: Int(red * coverage * 255))
                pixels[index + 1] = UInt8(clamping: Int(green * coverage * 255))
                pixels[index + 2] = UInt8(clamping: Int(blue * coverage * 255))
            }
        }

        guard let baked = context.makeImage() else { return self }
        return UIImage(cgImage: baked, scale: scale, orientation: imageOrientation)
            .withRenderingMode(.alwaysOriginal)
    }
}
