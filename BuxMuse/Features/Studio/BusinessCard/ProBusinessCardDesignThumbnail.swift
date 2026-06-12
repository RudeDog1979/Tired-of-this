//
//  ProBusinessCardDesignThumbnail.swift
//  BuxMuse
//
//  Unified card preview — canvas document when present, legacy renderer otherwise.
//

import SwiftUI

struct ProBusinessCardDesignThumbnail: View {
    let design: ProBusinessCardDesign
    let logoData: Data?
    var scale: CGFloat = 0.48
    var showShadow: Bool = false
    /// Template chips — skip photos/background IO; keeps scroll smooth.
    var galleryPreview: Bool = false
    /// Gallery tiles — skip QR bitmap generation at tiny sizes.
    var skipQR: Bool = false

    private var cardSize: CGSize { design.aspect.previewSize }
    private var fittedSize: CGSize {
        CGSize(width: cardSize.width * scale, height: cardSize.height * scale)
    }

    var body: some View {
        Group {
            if let canvas = CardCanvasRenderContext.make(
                design: design,
                logoData: logoData,
                galleryPreview: galleryPreview,
                skipQR: skipQR || scale <= 0.45
            ) {
                CardCanvasRenderer(context: canvas)
                    .scaleEffect(scale)
                    .frame(width: fittedSize.width, height: fittedSize.height)
            } else {
                let context = ProBusinessCardRenderFactory.makeContext(
                    design: design,
                    logoData: galleryPreview ? nil : logoData
                )
                ProBusinessCardRenderer(context: context)
                    .scaleEffect(scale)
                    .frame(width: fittedSize.width, height: fittedSize.height)
            }
        }
        .shadow(color: showShadow ? .black.opacity(0.14) : .clear, radius: showShadow ? 8 : 0, y: showShadow ? 4 : 0)
        .modifier(GalleryThumbnailRasterizer(enabled: galleryPreview))
        .id(thumbnailIdentity)
    }

    private var thumbnailIdentity: String {
        if galleryPreview {
            return "gallery-\(design.template.rawValue)-\(design.aspect.rawValue)"
        }
        return "\(design.id)-\(design.template.rawValue)-\(Int(design.updatedAt.timeIntervalSince1970))"
    }
}

private struct GalleryThumbnailRasterizer: ViewModifier {
    let enabled: Bool

    func body(content: Content) -> some View {
        if enabled {
            content.drawingGroup(opaque: false)
        } else {
            content
        }
    }
}
