//
//  ProBusinessCardRenderer.swift
//  BuxMuse
//

import SwiftUI
import UIKit

struct ProBusinessCardRenderContext {
    let design: ProBusinessCardDesign
    var photo: UIImage?
    var logo: UIImage?
    var backgroundPhoto: UIImage?
    var qrImage: UIImage?

    var accent: Color { Color(hex: design.palette.accentHex) }
    var background: Color { Color(hex: design.palette.backgroundHex) }
    var foreground: Color { Color(hex: design.palette.foregroundHex) }
    var size: CGSize { design.aspect.previewSize }
    var template: ProBusinessCardTemplate { design.template.renderTemplate }
    var isPortraitCard: Bool { design.aspect.isPortrait }

    var safeInset: CGFloat { size.height * design.aspect.safeInsetRatio }

    var layout: ProBusinessCardLayoutEngine {
        ProBusinessCardLayoutEngine(
            cardSize: size,
            safeInset: safeInset,
            photoScale: design.style.photoScale,
            placement: design.style.photoPlacement,
            showsPhoto: design.options.showsPhoto
        )
    }

    var logoSize: CGFloat {
        guard design.options.showsLogo else { return 0 }
        return min(size.height, size.width) * design.style.logoScale.pointRatio
    }

    var hAlign: HorizontalAlignment {
        design.options.textAlignment == .center ? .center : .leading
    }
}

struct ProBusinessCardRenderer: View {
    let context: ProBusinessCardRenderContext
    var showSafeZone: Bool = false
    var selectedLayer: ProBusinessCardCanvasLayerKind? = nil
    var hideFreeformLayers: Bool = false
    var onWatermarkDrag: ((CGSize) -> Void)? = nil
    var onWatermarkPinch: ((CGFloat) -> Void)? = nil
    var onPhotoDrag: ((CGSize) -> Void)? = nil

    var body: some View {
        ZStack {
            backgroundLayer
            templateDarkOverlay
            watermarkLayer
            templateAccentLayer
            if !hideFreeformLayers { canvasPhotoLayer; canvasLogoLayer }
            layoutPhotoLayer
            contentLayer
            if !hideFreeformLayers { canvasNameLayer; canvasQRLayer }
            borderLayer
            if showSafeZone { safeZoneOverlay }
        }
        .frame(width: context.size.width, height: context.size.height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(context.accent.opacity(0.18), lineWidth: 0.5)
        )
    }

    private var cornerRadius: CGFloat {
        context.design.aspect == .squareSocial ? 20 : 14
    }

    // MARK: Background

    @ViewBuilder
    private var backgroundLayer: some View { styledBackground }

    @ViewBuilder
    private var templateDarkOverlay: some View {
        switch context.template {
        case .boldTrade:
            Color(hex: "#0F172A").opacity(context.design.style.backgroundStyle == .solid ? 0.9 : 0.5)
        case .neonEdge:
            Color(hex: "#0B1220").opacity(context.design.style.backgroundStyle == .solid ? 0.85 : 0.42)
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private var styledBackground: some View {
        switch context.design.style.backgroundStyle {
        case .solid:
            context.background
        case .gradient:
            LinearGradient(
                colors: [context.background, context.accent.opacity(0.14)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .patternDots:
            ZStack {
                context.background
                Canvas { ctx, sz in
                    let step: CGFloat = 12
                    for x in stride(from: 0, through: sz.width, by: step) {
                        for y in stride(from: 0, through: sz.height, by: step) {
                            ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 2, height: 2)), with: .color(context.accent.opacity(0.08)))
                        }
                    }
                }
            }
        case .patternLines:
            ZStack {
                context.background
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
                if let bg = context.backgroundPhoto {
                    Image(uiImage: bg)
                        .resizable()
                        .scaledToFill()
                        .frame(width: context.size.width, height: context.size.height)
                        .clipped()
                        .opacity(context.design.style.backgroundPhotoOpacity)
                } else {
                    context.background
                }
                if context.backgroundPhoto != nil {
                    context.foreground.opacity(0.5)
                }
            }
        }
    }

    // MARK: Photo — layout grid OR freeform canvas

    @ViewBuilder
    private var layoutPhotoLayer: some View {
        if context.design.style.photoCanvas == nil {
            legacyLayoutPhotoLayer
        }
    }

    @ViewBuilder
    private var legacyLayoutPhotoLayer: some View {
        if context.design.options.showsPhoto,
           context.design.style.photoScale != .off,
           let photo = context.photo {
            let frame = context.layout.photoFrame()
            if frame != .zero {
                photoView(photo: photo, frame: frame, isStrip: context.layout.isStrip)
                    .overlay {
                        if selectedLayer == .photo {
                            RoundedRectangle(cornerRadius: context.layout.isStrip ? 4 : frame.width / 2)
                                .stroke(context.accent, lineWidth: 2)
                                .frame(width: frame.width, height: frame.height)
                                .position(x: frame.midX, y: frame.midY)
                        }
                    }
                    .modifier(LayerDragModifier(enabled: onPhotoDrag != nil, onDrag: onPhotoDrag))
            }
        }
    }

    @ViewBuilder
    private var canvasPhotoLayer: some View {
        if context.design.options.showsPhoto,
           context.design.style.photoScale != .off,
           let photo = context.photo,
           let canvas = context.design.style.photoCanvas {
            let card = context.size
            let base = min(card.width, card.height) * context.design.style.photoScale.pointRatio * canvas.scale
            let frame = CGRect(x: 0, y: 0, width: base, height: base)
            photoView(photo: photo, frame: frame, isStrip: false)
                .overlay {
                    if selectedLayer == .photo {
                        Circle().stroke(context.accent, lineWidth: 2)
                            .frame(width: base, height: base)
                    }
                }
                .rotationEffect(.degrees(canvas.rotation))
                .position(x: canvas.normalizedX * card.width, y: canvas.normalizedY * card.height)
        }
    }

    @ViewBuilder
    private var canvasLogoLayer: some View {
        if context.design.options.showsLogo,
           let canvas = context.design.style.logoCanvas {
            let card = context.size
            let base = min(card.width, card.height) * context.design.style.logoScale.pointRatio * canvas.scale
            Group {
                if let logo = context.logo {
                    Image(uiImage: logo).resizable().scaledToFill()
                } else {
                    Image(systemName: "briefcase.fill")
                        .font(.system(size: base * 0.38, weight: .bold))
                        .foregroundColor(context.accent)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(context.accent.opacity(0.12))
                }
            }
            .frame(width: base, height: base)
            .clipShape(logoClipShape(size: base))
            .overlay {
                if selectedLayer == .logo {
                    logoClipShape(size: base).stroke(context.accent, lineWidth: 2)
                }
            }
            .rotationEffect(.degrees(canvas.rotation))
            .position(x: canvas.normalizedX * card.width, y: canvas.normalizedY * card.height)
        }
    }

    @ViewBuilder
    private var canvasNameLayer: some View {
        if let canvas = context.design.style.nameCanvas {
            let card = context.size
            Text(context.design.content.name)
                .font(nameFont)
                .foregroundColor(contentForeground)
                .lineLimit(2)
                .minimumScaleFactor(0.5)
                .multilineTextAlignment(textAlign)
                .frame(maxWidth: card.width * 0.82)
                .scaleEffect(canvas.scale)
                .overlay {
                    if selectedLayer == .name {
                        RoundedRectangle(cornerRadius: 6).stroke(context.accent, lineWidth: 2).padding(-4)
                    }
                }
                .rotationEffect(.degrees(canvas.rotation))
                .position(x: canvas.normalizedX * card.width, y: canvas.normalizedY * card.height)
        }
    }

    @ViewBuilder
    private var canvasQRLayer: some View {
        if context.design.options.showsQR,
           let canvas = context.design.style.qrCanvas,
           let qr = context.qrImage {
            let card = context.size
            let base = min(56, card.height * 0.22) * canvas.scale
            Image(uiImage: qr)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(width: base, height: base)
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                .overlay {
                    if selectedLayer == .qr {
                        RoundedRectangle(cornerRadius: 5).stroke(context.accent, lineWidth: 2)
                    }
                }
                .rotationEffect(.degrees(canvas.rotation))
                .position(x: canvas.normalizedX * card.width, y: canvas.normalizedY * card.height)
        }
    }

    // MARK: Photo rendering

    @ViewBuilder
    private var photoLayer: some View { EmptyView() }

    @ViewBuilder
    private func photoView(photo: UIImage, frame: CGRect, isStrip: Bool) -> some View {
        let transform = context.design.style.photoTransform
        let zoom = max(1, CGFloat(transform.zoom))
        Group {
            if isStrip {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
            .scaleEffect(zoom)
            .rotationEffect(.degrees(transform.rotation))
            .offset(x: CGFloat(transform.offsetX) * frame.width, y: CGFloat(transform.offsetY) * frame.height)
                    .frame(width: frame.width, height: frame.height)
                    .clipped()
            } else if context.design.style.photoPlacement == .center {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
            .scaleEffect(zoom)
            .rotationEffect(.degrees(transform.rotation))
            .offset(x: CGFloat(transform.offsetX) * frame.width, y: CGFloat(transform.offsetY) * frame.height)
                    .frame(width: frame.width, height: frame.height)
                    .clipShape(photoClipShape(frame: frame, isStrip: false))
                    .opacity(0.2)
            } else {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
            .scaleEffect(zoom)
            .rotationEffect(.degrees(transform.rotation))
            .offset(x: CGFloat(transform.offsetX) * frame.width, y: CGFloat(transform.offsetY) * frame.height)
                    .frame(width: frame.width, height: frame.height)
                    .clipShape(photoClipShape(frame: frame, isStrip: false))
                    .overlay(photoClipShape(frame: frame, isStrip: false).stroke(context.background, lineWidth: 2))
            }
        }
        .position(x: frame.midX, y: frame.midY)
    }

    // MARK: Watermark

    @ViewBuilder
    private var watermarkLayer: some View {
        let wm = context.design.style.watermark
        if wm.isEnabled {
            let text = wm.text.isEmpty ? context.design.content.name : wm.text
            Text(text.uppercased())
                .font(watermarkFont)
                .foregroundColor(contentForeground.opacity(wm.opacity))
                .lineLimit(2)
                .minimumScaleFactor(0.35)
                .multilineTextAlignment(.center)
                .frame(maxWidth: context.size.width * 0.9)
                .rotationEffect(.degrees(wm.rotation))
                .scaleEffect(wm.scale)
                .position(x: context.size.width * wm.normalizedX, y: context.size.height * wm.normalizedY)
                .overlay {
                    if selectedLayer == .watermark {
                        RoundedRectangle(cornerRadius: 4).stroke(context.accent, lineWidth: 2).padding(-6)
                    }
                }
                .modifier(LayerDragModifier(enabled: onWatermarkDrag != nil, onDrag: onWatermarkDrag))
                .modifier(PinchModifier(enabled: onWatermarkPinch != nil, onPinch: onWatermarkPinch))
        }
    }

    private var watermarkFont: Font {
        let typo = context.design.style.typography
        let font = ProBusinessCardFontID.from(stored: typo.fontID)
        let size: CGFloat = context.isPortraitCard ? 32 : (context.design.aspect == .squareSocial ? 48 : 36)
        return font.font(size: size * typo.nameScale, weight: .black)
    }

    // MARK: Template accents

    @ViewBuilder
    private var templateAccentLayer: some View {
        switch context.template {
        case .classic:
            HStack(spacing: 0) {
                context.accent.frame(width: max(6, context.size.width * 0.022))
                Spacer()
            }
        case .twoToneSplit:
            GeometryReader { geo in
                Path { path in
                    path.move(to: CGPoint(x: geo.size.width, y: 0))
                    path.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height))
                    path.addLine(to: CGPoint(x: geo.size.width * 0.38, y: geo.size.height))
                    path.closeSubpath()
                }
                .fill(context.accent.opacity(0.16))
            }
        case .gradientPro:
            VStack(spacing: 0) {
                LinearGradient(colors: [context.accent, context.accent.opacity(0.45)], startPoint: .leading, endPoint: .trailing)
                    .frame(height: context.size.height * (context.isPortraitCard ? 0.16 : 0.2))
                Spacer(minLength: 0)
            }
        case .glassFrost:
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
                .padding(context.safeInset * 0.55)
        case .stampBadge:
            Circle()
                .stroke(context.accent.opacity(0.25), lineWidth: 3)
                .frame(width: context.size.height * 0.5)
                .position(x: context.size.width * 0.78, y: context.size.height * 0.36)
        case .neonEdge:
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(LinearGradient(colors: [context.accent, context.accent.opacity(0.25)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 2.5)
                .shadow(color: context.accent.opacity(0.4), radius: 8)
        case .letterpress:
            VStack {
                Spacer()
                Rectangle().fill(contentForeground.opacity(0.08)).frame(height: 1)
            }
            .padding(.horizontal, context.safeInset)
            .padding(.bottom, context.safeInset * 2)
        default:
            EmptyView()
        }
    }

    // MARK: Content

    @ViewBuilder
    private var contentLayer: some View {
        let raw = context.layout.contentRect()
        let rect = CGRect(
            x: raw.origin.x,
            y: raw.origin.y,
            width: max(raw.width, 1),
            height: max(raw.height, 1)
        )
        Group {
            switch context.template {
            case .qrFirst: qrFirstContent
            case .swissGrid, .lineMinimal, .geometricGrid, .diagonalBands, .hexAccent, .cornerBlocks, .splitVertical:
                swissContent
            case .monogram: monogramContent
            case .logoMark, .watermark, .circleFrame, .arcSweep: heroContent
            case .editorial, .letterpress, .minimalMono: editorialContent
            default: standardContent
            }
        }
        .frame(width: rect.width, height: rect.height, alignment: .topLeading)
        .position(x: rect.midX, y: rect.midY)
    }

    private var standardContent: some View {
        VStack(alignment: context.hAlign, spacing: spacingUnit) {
            logoRow
            textBlock
            if context.design.options.showsSkills, !context.design.content.skills.isEmpty { skillsLine }
            Spacer(minLength: 0)
            footerRow
        }
    }

    private var heroContent: some View {
        VStack(alignment: context.hAlign, spacing: spacingUnit) {
            logoRow
            textBlock
            Spacer(minLength: 0)
            footerRow
        }
    }

    private var qrFirstContent: some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: context.hAlign, spacing: 6) {
                logoRow
                textBlock
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if context.design.options.showsQR, context.design.style.qrCanvas == nil { qrView(size: 72) }
        }
    }

    private var swissContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                if context.design.style.logoCanvas == nil { logoView(size: context.logoSize) }
                Spacer()
                if context.design.options.showsQR, context.design.style.qrCanvas == nil { qrView(size: 52) }
            }
            textBlock
            Spacer(minLength: 0)
            contactBlock(compact: true)
        }
    }

    private var monogramContent: some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle().fill(context.accent.opacity(0.14)).frame(width: context.logoSize, height: context.logoSize)
                Text(monogramLetter)
                    .font(.system(size: context.logoSize * 0.42, weight: .black, design: .rounded))
                    .foregroundColor(context.accent)
            }
            VStack(alignment: .leading, spacing: 5) {
                logoView(size: context.logoSize * 0.72)
                textBlock
                contactBlock(compact: true)
            }
            Spacer(minLength: 0)
        }
    }

    private var editorialContent: some View {
        VStack(alignment: context.hAlign, spacing: 8) {
            if context.design.style.logoCanvas == nil {
                logoView(size: context.logoSize * 0.85)
            }
            textBlock
            Rectangle().fill(contentForeground.opacity(0.12)).frame(height: 1)
            contactBlock(compact: false)
            Spacer(minLength: 0)
        }
    }

    private var logoRow: some View {
        HStack {
            if context.design.options.showsLogo, context.design.style.logoCanvas == nil {
                logoView(size: context.logoSize)
            }
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func logoView(size: CGFloat) -> some View {
        if context.design.options.showsLogo, size > 0 {
            Group {
                if let logo = context.logo {
                    Image(uiImage: logo).resizable().scaledToFill()
                } else {
                    Image(systemName: "briefcase.fill")
                        .font(.system(size: size * 0.38, weight: .bold))
                        .foregroundColor(context.accent)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(context.accent.opacity(0.12))
                }
            }
            .frame(width: size, height: size)
            .clipShape(logoClipShape(size: size))
            .overlay {
                if selectedLayer == .logo {
                    logoClipShape(size: size).stroke(context.accent, lineWidth: 2)
                }
            }
        }
    }

    private func logoClipShape(size: CGFloat) -> some Shape {
        let mask = context.design.style.logoMask
        let radius = context.design.style.logoCornerRadius
        switch mask {
        case .none:
            return AnyRendererShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        case .circle:
            return AnyRendererShape(Circle())
        case .roundedRect:
            return AnyRendererShape(RoundedRectangle(cornerRadius: max(4, size * radius / 100), style: .continuous))
        }
    }

    private func photoClipShape(frame: CGRect, isStrip: Bool) -> some Shape {
        if isStrip { return AnyRendererShape(RoundedRectangle(cornerRadius: 4, style: .continuous)) }
        switch context.design.style.photoMask {
        case .none:
            return AnyRendererShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        case .circle:
            return AnyRendererShape(Circle())
        case .roundedRect:
            return AnyRendererShape(RoundedRectangle(cornerRadius: frame.width * 0.14, style: .continuous))
        }
    }

    private var textBlock: some View {
        VStack(alignment: context.hAlign, spacing: 3) {
            if context.design.style.nameCanvas == nil {
                Text(context.design.content.name)
                    .font(nameFont)
                    .foregroundColor(contentForeground)
                    .lineLimit(2)
                    .minimumScaleFactor(0.5)
                    .multilineTextAlignment(textAlign)
            }
            if !context.design.content.tagline.isEmpty {
                Text(context.design.content.tagline)
                    .font(taglineFont(compact: true))
                    .foregroundColor(contentForeground.opacity(0.68))
                    .lineLimit(2)
                    .minimumScaleFactor(0.65)
                    .multilineTextAlignment(textAlign)
            }
        }
    }

    private var skillsLine: some View {
        Text(context.design.content.skills)
            .font(.system(size: 9, weight: .medium))
            .foregroundColor(contentForeground.opacity(0.65))
            .lineLimit(2)
            .minimumScaleFactor(0.7)
    }

    private func contactBlock(compact: Bool) -> some View {
        VStack(alignment: context.hAlign, spacing: compact ? 2 : 3) {
            if !context.design.content.phone.isEmpty {
                Text(context.design.content.phone).font(contactFont(compact: compact))
            }
            if !context.design.content.email.isEmpty {
                Text(context.design.content.email).font(contactFont(compact: compact)).opacity(0.75)
            }
            if !context.design.content.website.isEmpty {
                Text(context.design.content.website).font(contactFont(compact: compact)).opacity(0.75)
            }
        }
        .foregroundColor(contentForeground)
    }

    private var footerRow: some View {
        HStack(alignment: .bottom) {
            contactBlock(compact: true)
            Spacer(minLength: 0)
            if context.design.options.showsQR,
               context.design.style.qrCanvas == nil,
               context.template != .qrFirst,
               context.template != .swissGrid {
                qrView(size: min(48, context.layout.contentRect().height * 0.38))
            }
        }
    }

    @ViewBuilder
    private func qrView(size: CGFloat) -> some View {
        if let qr = context.qrImage {
            Image(uiImage: qr)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        }
    }

    @ViewBuilder
    private var borderLayer: some View {
        switch context.design.style.borderStyle {
        case .none: EmptyView()
        case .thin:
            RoundedRectangle(cornerRadius: cornerRadius).stroke(contentForeground.opacity(0.2), lineWidth: 1)
        case .double:
            RoundedRectangle(cornerRadius: cornerRadius).stroke(contentForeground.opacity(0.22), lineWidth: 1)
                .padding(3)
                .overlay(RoundedRectangle(cornerRadius: cornerRadius - 2).stroke(contentForeground.opacity(0.12), lineWidth: 1))
        case .accent:
            RoundedRectangle(cornerRadius: cornerRadius).stroke(context.accent.opacity(0.75), lineWidth: 2)
        }
    }

    private var safeZoneOverlay: some View {
        RoundedRectangle(cornerRadius: 4)
            .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            .foregroundColor(context.accent.opacity(0.5))
            .padding(context.safeInset)
    }

    private var contentForeground: Color {
        switch context.template {
        case .boldTrade, .neonEdge: return .white
        default: return context.foreground
        }
    }

    private var monogramLetter: String {
        let name = context.design.content.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "B" : String(name.prefix(1)).uppercased()
    }

    private var spacingUnit: CGFloat { max(4, context.size.height * 0.028) }
    private var textAlign: TextAlignment { context.design.options.textAlignment == .center ? .center : .leading }

    private var nameFont: Font {
        let typo = context.design.style.typography
        let font = ProBusinessCardFontID.from(stored: typo.fontID)
        let base = max(12, context.layout.contentRect().height * 0.14) * typo.nameScale
        return font.font(size: min(base, 26), weight: .bold)
    }

    private func taglineFont(compact: Bool) -> Font {
        let typo = context.design.style.typography
        let font = ProBusinessCardFontID.from(stored: typo.fontID)
        return font.font(size: 10 * typo.taglineScale, weight: .semibold)
    }

    private func contactFont(compact: Bool) -> Font {
        let typo = context.design.style.typography
        let font = ProBusinessCardFontID.from(stored: typo.fontID)
        return font.font(size: (compact ? 9 : 10) * typo.contactScale, weight: .medium)
    }
}

// MARK: - Fit preview

struct ProBusinessCardFitPreview: View {
    let context: ProBusinessCardRenderContext
    var maxWidth: CGFloat
    var maxHeight: CGFloat
    var showSafeZone: Bool = false
    var selectedLayer: ProBusinessCardCanvasLayerKind? = nil
    var canvasContext: CardCanvasRenderContext? = nil
    var onWatermarkDrag: ((CGSize) -> Void)? = nil
    var onWatermarkPinch: ((CGFloat) -> Void)? = nil
    var onPhotoDrag: ((CGSize) -> Void)? = nil
    var onPhotoPlaceholderTap: (() -> Void)? = nil
    var onLogoPlaceholderTap: (() -> Void)? = nil

    private var safeMaxWidth: CGFloat { max(100, maxWidth.isFinite ? maxWidth : 100) }
    private var safeMaxHeight: CGFloat { max(100, maxHeight.isFinite ? maxHeight : 100) }

    private var cardSize: CGSize { canvasContext?.canvasSize ?? context.size }

    private var fitScale: CGFloat {
        let card = cardSize
        guard card.width > 0, card.height > 0 else { return 1 }
        let wScale = (safeMaxWidth - 24) / card.width
        let hScale = (safeMaxHeight - 16) / card.height
        guard wScale.isFinite, hScale.isFinite, wScale > 0, hScale > 0 else { return 0.5 }
        return max(0.08, min(wScale, hScale, 1.2))
    }

    private var fittedCardSize: CGSize {
        CGSize(
            width: max(1, cardSize.width * fitScale),
            height: max(1, cardSize.height * fitScale)
        )
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black.opacity(0.04))
            if let canvasContext {
                CardCanvasRenderer(context: canvasContext, showSafeZone: showSafeZone)
                    .scaleEffect(fitScale)
                    .frame(width: fittedCardSize.width, height: fittedCardSize.height)
                    .shadow(color: .black.opacity(0.16), radius: 14, y: 6)
            } else {
                ProBusinessCardRenderer(
                    context: context,
                    showSafeZone: showSafeZone,
                    selectedLayer: selectedLayer,
                    onWatermarkDrag: onWatermarkDrag,
                    onWatermarkPinch: onWatermarkPinch,
                    onPhotoDrag: onPhotoDrag
                )
                .scaleEffect(fitScale)
                .frame(width: fittedCardSize.width, height: fittedCardSize.height)
                .shadow(color: .black.opacity(0.16), radius: 14, y: 6)
            }
            placeholderOverlays
        }
        .frame(width: safeMaxWidth, height: max(fittedCardSize.height + 20, min(safeMaxHeight, fittedCardSize.height + 20)))
    }

    @ViewBuilder
    private var placeholderOverlays: some View {
        let cardW = fittedCardSize.width
        let design = context.design

        if design.options.showsPhoto,
           design.style.photoScale != .off,
           context.photo == nil,
           let onPhotoPlaceholderTap {
            let frame = context.layout.photoFrame()
            if frame != .zero {
                Button(action: onPhotoPlaceholderTap) {
                    ZStack {
                        photoPlaceholderShape(frame: frame, cardW: cardW)
                            .fill(context.accent.opacity(0.12))
                        VStack(spacing: 4) {
                            Image(systemName: "person.crop.circle.badge.plus")
                                .font(.system(size: min(frame.width, frame.height) * 0.28, weight: .semibold))
                            Text("Add photo")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .frame(width: frame.width * fitScale, height: frame.height * fitScale)
                .position(x: frame.midX * fitScale, y: frame.midY * fitScale)
            }
        }

        if design.options.showsLogo,
           context.logo == nil,
           let onLogoPlaceholderTap {
            let size = context.logoSize * fitScale
            let inset = context.safeInset * fitScale
            Button(action: onLogoPlaceholderTap) {
                ZStack {
                    RoundedRectangle(cornerRadius: size * 0.16)
                        .fill(context.accent.opacity(0.12))
                    VStack(spacing: 3) {
                        Image(systemName: "briefcase.fill")
                            .font(.system(size: size * 0.22, weight: .semibold))
                        Text("Add logo")
                            .font(.system(size: 8, weight: .bold))
                    }
                    .foregroundStyle(.secondary)
                }
                .frame(width: size, height: size)
            }
            .buttonStyle(.plain)
            .position(x: inset + size * 0.5, y: inset + size * 0.5)
        }
    }

    private func photoPlaceholderShape(frame: CGRect, cardW: CGFloat) -> some Shape {
        switch context.design.style.photoMask {
        case .circle:
            return AnyRendererShape(Circle())
        case .roundedRect:
            return AnyRendererShape(RoundedRectangle(cornerRadius: frame.width * 0.14, style: .continuous))
        case .none:
            return AnyRendererShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
    }
}

enum ProBusinessCardRenderFactory {
    @MainActor
    static func makeContext(design: ProBusinessCardDesign, logoData: Data?) -> ProBusinessCardRenderContext {
        let rawPhoto = SimpleStudioScanImageStore.load(path: design.content.photoPath)
        let adjustedPhoto = rawPhoto.flatMap { img in
            BusinessCardPhotoLabEngine.render(source: img, adjustments: design.style.photoAdjustments) ?? img
        }
        return ProBusinessCardRenderContext(
            design: design,
            photo: adjustedPhoto,
            logo: logoData.flatMap { UIImage(data: $0) },
            backgroundPhoto: SimpleStudioScanImageStore.load(path: design.style.backgroundPhotoPath),
            qrImage: design.options.showsQR
                ? InvoiceDesignerEngine.generateQRImage(from: design.content.vCardPayload, size: 180)
                : nil
        )
    }
}

private struct AnyRendererShape: Shape {
    private let builder: @Sendable (CGRect) -> Path
    init<S: Shape>(_ shape: S) { builder = { shape.path(in: $0) } }
    func path(in rect: CGRect) -> Path { builder(rect) }
}

private struct PinchModifier: ViewModifier {
    let enabled: Bool
    var onPinch: ((CGFloat) -> Void)?

    func body(content: Content) -> some View {
        if enabled, let onPinch {
            content.gesture(MagnificationGesture().onChanged { onPinch($0) })
        } else {
            content
        }
    }
}

private struct LayerDragModifier: ViewModifier {
    let enabled: Bool
    var onDrag: ((CGSize) -> Void)?

    func body(content: Content) -> some View {
        if enabled, let onDrag {
            content.gesture(DragGesture(minimumDistance: 1).onChanged { onDrag($0.translation) })
        } else {
            content
        }
    }
}
