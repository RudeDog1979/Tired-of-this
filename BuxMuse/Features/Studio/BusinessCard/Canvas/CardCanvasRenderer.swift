//
//  CardCanvasRenderer.swift
//  BuxMuse
//

import SwiftUI
import UIKit

struct CardCanvasRenderContext {
    let design: ProBusinessCardDesign
    let document: CardCanvasDocument
    var photo: UIImage?
    var logo: UIImage?
    var backgroundPhoto: UIImage?
    var qrImage: UIImage?

    var canvasSize: CGSize { document.canvasSize }
    var accent: Color { Color(hex: design.palette.accentHex) }
    var foreground: Color { Color(hex: design.palette.foregroundHex) }
    var safeInset: CGFloat { canvasSize.height * document.safeInsetRatio }

    static func make(
        design: ProBusinessCardDesign,
        logoData: Data?,
        galleryPreview: Bool = false,
        skipQR: Bool = false
    ) -> CardCanvasRenderContext? {
        guard let doc = design.canvasDocument else { return nil }
        let omitAssets = galleryPreview
        let omitQR = skipQR || galleryPreview
        let rawPhoto = omitAssets
            ? nil
            : SimpleStudioScanImageStore.load(path: design.content.photoPath)
        let adjusted = rawPhoto.flatMap { img in
            BusinessCardPhotoLabEngine.render(source: img, adjustments: design.style.photoAdjustments) ?? img
        }
        return CardCanvasRenderContext(
            design: design,
            document: doc,
            photo: adjusted,
            logo: logoData.flatMap { UIImage(data: $0) },
            backgroundPhoto: omitAssets
                ? nil
                : SimpleStudioScanImageStore.load(path: doc.background.photoPath),
            qrImage: omitQR || !design.options.showsQR
                ? nil
                : InvoiceDesignerEngine.generateQRImage(from: design.content.vCardPayload, size: 180)
        )
    }
}

struct CardCanvasRenderer: View {
    let context: CardCanvasRenderContext
    var selectedLayerID: UUID? = nil
    var showSafeZone: Bool = false
    var interactive: Bool = false

    private var cornerRadius: CGFloat {
        context.design.aspect == .squareSocial ? 20 : 14
    }

    var body: some View {
        ZStack {
            backgroundView
            ForEach(context.document.layers.filter { !$0.isHidden }) { layer in
                layerView(layer)
                    .opacity(layer.opacity)
            }
            if showSafeZone { safeZoneOverlay }
        }
        .frame(width: context.canvasSize.width, height: context.canvasSize.height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(context.accent.opacity(0.15), lineWidth: 0.5)
        )
        .allowsHitTesting(interactive)
    }

    @ViewBuilder
    private func layerView(_ layer: CardCanvasLayer) -> some View {
        let frame = layer.transform.frame(in: context.canvasSize)
        Group {
            switch layer.payload {
            case .text(let payload): textLayer(payload, layer: layer, frame: frame)
            case .image(let payload): imageLayer(payload, layer: layer, frame: frame)
            case .qr: qrLayer(layer: layer, frame: frame)
            case .shape(let payload): shapeLayer(payload, layer: layer, frame: frame)
            case .watermark(let payload): watermarkLayer(payload, layer: layer, frame: frame)
            }
        }
        .overlay {
            if selectedLayerID == layer.id {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(context.accent, lineWidth: 2)
                    .frame(width: frame.width, height: frame.height)
                    .position(x: frame.midX, y: frame.midY)
            }
        }
    }

    @ViewBuilder
    private var backgroundView: some View {
        let bg = context.document.background
        switch bg.style {
        case .solid:
            Color(hex: bg.solidHex)
        case .gradient:
            LinearGradient(
                colors: [Color(hex: bg.solidHex), Color(hex: bg.accentHex).opacity(0.2)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        case .patternDots:
            ZStack {
                Color(hex: bg.solidHex)
                Canvas { ctx, sz in
                    for x in stride(from: 0, through: sz.width, by: 12) {
                        for y in stride(from: 0, through: sz.height, by: 12) {
                            ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 2, height: 2)), with: .color(context.accent.opacity(0.08)))
                        }
                    }
                }
            }
        case .patternLines:
            ZStack {
                Color(hex: bg.solidHex)
                Canvas { ctx, sz in
                    var path = Path()
                    var y: CGFloat = 0
                    while y <= sz.height {
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: sz.width, y: y))
                        y += 16
                    }
                    ctx.stroke(path, with: .color(context.accent.opacity(0.07)), lineWidth: 1)
                }
            }
        case .photo:
            ZStack {
                if let img = context.backgroundPhoto {
                    backgroundPhotoView(img: img, bg: bg)
                } else {
                    Color(hex: bg.solidHex)
                }
                if let overlay = bg.overlayHex {
                    Color(hex: overlay).opacity(bg.overlayOpacity)
                }
            }
        }
    }

    @ViewBuilder
    private func backgroundPhotoView(img: UIImage, bg: CardBackgroundSpec) -> some View {
        let t = bg.photoTransform
        let zoom = max(1, CGFloat(t.zoom))
        Image(uiImage: img)
            .resizable()
            .scaledToFill()
            .scaleEffect(zoom)
            .rotationEffect(.degrees(t.rotation))
            .offset(x: CGFloat(t.offsetX) * context.canvasSize.width, y: CGFloat(t.offsetY) * context.canvasSize.height)
            .frame(width: context.canvasSize.width, height: context.canvasSize.height)
            .clipped()
            .opacity(bg.photoOpacity)
            .saturation(bg.saturation)
            .brightness(bg.brightness)
    }

    @ViewBuilder
    private func textLayer(_ payload: CardTextPayload, layer: CardCanvasLayer, frame: CGRect) -> some View {
        let style = payload.style
        let font = ProBusinessCardFontID.from(stored: style.fontID)
        let weight: Font.Weight = style.isBold ? .bold : .regular
        let align: TextAlignment = style.alignment == "center" ? .center : .leading
        Text(payload.text)
            .font(font.font(size: style.fontSize * layer.transform.scale, weight: weight))
            .italic(style.isItalic)
            .underline(style.isUnderline)
            .foregroundColor(Color(hex: style.colorHex))
            .multilineTextAlignment(align)
            .lineSpacing(style.lineSpacing)
            .minimumScaleFactor(0.5)
            .lineLimit(4)
            .padding(style.backgroundColorHex != nil ? 4 : 0)
            .background(style.backgroundColorHex.map { Color(hex: $0).opacity(0.85) })
            .cardTextEffect(style.effectPreset, color: Color(hex: style.colorHex))
            .shadow(
                color: layer.effects.shadowColorHex.map { Color(hex: $0) } ?? .clear,
                radius: layer.effects.shadowRadius,
                x: layer.effects.shadowOffsetX,
                y: layer.effects.shadowOffsetY
            )
            .rotationEffect(.degrees(layer.transform.rotation))
            .frame(width: frame.width, height: frame.height, alignment: align == .center ? .center : .leading)
            .position(x: frame.midX, y: frame.midY)
    }

    @ViewBuilder
    private func imageLayer(_ payload: CardImagePayload, layer: CardCanvasLayer, frame: CGRect) -> some View {
        let image: UIImage? = {
            switch payload.source {
            case .profilePhoto: return context.photo
            case .profileLogo: return context.logo
            case .assetPath(let path): return SimpleStudioScanImageStore.load(path: path)
            }
        }()
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .scaleEffect(max(1, CGFloat(payload.photoTransform.zoom)))
                    .rotationEffect(.degrees(payload.photoTransform.rotation))
                    .offset(
                        x: CGFloat(payload.photoTransform.offsetX) * frame.width,
                        y: CGFloat(payload.photoTransform.offsetY) * frame.height
                    )
                    .scaleEffect(x: payload.flipHorizontal ? -1 : 1, y: payload.flipVertical ? -1 : 1)
            } else {
                Image(systemName: payload.source == .profileLogo ? "briefcase.fill" : "person.fill")
                    .font(.system(size: frame.width * 0.35))
                    .foregroundStyle(context.accent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(context.accent.opacity(0.12))
            }
        }
        .frame(width: frame.width, height: frame.height)
        .clipShape(clipShape(for: payload.mask, cornerRadius: payload.cornerRadius, size: frame))
        .overlay {
            if let border = payload.borderColorHex, payload.borderWidth > 0 {
                clipShape(for: payload.mask, cornerRadius: payload.cornerRadius, size: frame)
                    .stroke(Color(hex: border), lineWidth: payload.borderWidth)
            }
        }
        .rotationEffect(.degrees(layer.transform.rotation))
        .position(x: frame.midX, y: frame.midY)
    }

    @ViewBuilder
    private func qrLayer(layer: CardCanvasLayer, frame: CGRect) -> some View {
        if let qr = context.qrImage {
            Image(uiImage: qr)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(width: frame.width, height: frame.height)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .rotationEffect(.degrees(layer.transform.rotation))
                .position(x: frame.midX, y: frame.midY)
        }
    }

    @ViewBuilder
    private func shapeLayer(_ payload: CardShapePayload, layer: CardCanvasLayer, frame: CGRect) -> some View {
        BuxGeometricShapeView(
            type: payload.shapeType,
            fill: fill(for: payload),
            stroke: payload.strokeHex.map { Color(hex: $0) },
            strokeWidth: payload.strokeWidth,
            cornerRadius: payload.cornerRadius,
            symbolName: payload.symbolName
        )
        .frame(width: frame.width, height: frame.height)
        .rotationEffect(.degrees(layer.transform.rotation))
        .position(x: frame.midX, y: frame.midY)
    }

    @ViewBuilder
    private func watermarkLayer(_ payload: CardWatermarkPayload, layer: CardCanvasLayer, frame: CGRect) -> some View {
        let font = ProBusinessCardFontID.from(stored: payload.fontID)
        Text(payload.text.uppercased())
            .font(font.font(size: min(frame.height * 0.7, 42), weight: .black))
            .foregroundColor(Color(hex: payload.colorHex).opacity(layer.opacity))
            .multilineTextAlignment(.center)
            .minimumScaleFactor(0.35)
            .lineLimit(2)
            .frame(width: frame.width, height: frame.height)
            .rotationEffect(.degrees(layer.transform.rotation))
            .position(x: frame.midX, y: frame.midY)
    }

    private func fill(for payload: CardShapePayload) -> AnyShapeStyle {
        if payload.useGradient {
            return AnyShapeStyle(LinearGradient(
                colors: [Color(hex: payload.fillHex), Color(hex: payload.fillHex).opacity(0.45)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ))
        }
        return AnyShapeStyle(Color(hex: payload.fillHex).opacity(payload.fillHex == "#00000000" ? 0 : 1))
    }

    private func clipShape(for mask: CardImageMask, cornerRadius: Double, size: CGRect) -> AnyShape {
        switch mask {
        case .none:
            return AnyShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        case .circle:
            return AnyShape(Circle())
        case .roundedRect:
            return AnyShape(RoundedRectangle(cornerRadius: max(4, cornerRadius), style: .continuous))
        }
    }

    private var safeZoneOverlay: some View {
        RoundedRectangle(cornerRadius: 4)
            .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            .foregroundColor(context.accent.opacity(0.5))
            .padding(context.safeInset)
    }
}

private struct AnyShape: Shape {
    private let builder: @Sendable (CGRect) -> Path

    init<S: Shape>(_ shape: S) {
        builder = { rect in shape.path(in: rect) }
    }

    func path(in rect: CGRect) -> Path { builder(rect) }
}
