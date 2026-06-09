//
//  AgreementImportedSignatureRasterizer.swift
//  BuxMuse — Transparent signature PNGs for imported agreement placement only.
//

import PencilKit
import UIKit

enum AgreementImportedSignatureRasterizer {
    static func transparentPNG(from drawing: PKDrawing) -> Data? {
        guard !drawing.bounds.isEmpty else { return nil }
        let bounds = drawing.bounds.insetBy(dx: -12, dy: -12)
        let stroke = drawing.image(from: bounds, scale: 2)

        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        format.scale = stroke.scale
        let renderer = UIGraphicsImageRenderer(size: stroke.size, format: format)
        let image = renderer.image { _ in
            stroke.draw(at: .zero)
        }
        return image.pngData()
    }

    static func image(from data: Data) -> UIImage? {
        guard let image = UIImage(data: data) else { return nil }
        return image.withRenderingMode(.alwaysOriginal)
    }
}
