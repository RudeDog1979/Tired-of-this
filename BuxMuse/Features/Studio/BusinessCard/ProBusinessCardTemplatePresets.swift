//
//  ProBusinessCardTemplatePresets.swift
//  BuxMuse
//
//  Complete template presets — palettes, layout, geometric shapes.
//

import CoreGraphics
import Foundation

enum ProBusinessCardTemplatePresets {

    struct LayoutSpec {
        var logoCenter: (x: Double, y: Double)?
        var logoScale: ProBusinessCardLogoScale?
        var nameCenter: (x: Double, y: Double)?
        var contactCenter: (x: Double, y: Double)?
        var qrCenter: (x: Double, y: Double)?
        var textAlign: ProBusinessCardAlignment?
    }

    // MARK: - Apply

    static func apply(to design: inout ProBusinessCardDesign) {
        let t = design.template.renderTemplate
        design.style.photoCanvas = nil
        design.style.logoCanvas = nil
        design.style.nameCanvas = nil
        design.style.qrCanvas = nil
        design.style.watermark.isEnabled = false

        if let palette = palette(for: t) {
            design.palette = palette
        }
        applyStyle(t, to: &design.style, name: design.content.name)
        applyOptions(t, to: &design.options)
        enrichPlaceholderContent(&design.content)
        CardCanvasSync.applyTemplateReseed(to: &design)
        design.updatedAt = Date()
    }

    private static func enrichPlaceholderContent(_ content: inout ProBusinessCardContent) {
        if content.phone.isEmpty { content.phone = "+1 555 0100" }
        if content.email.isEmpty, !content.name.isEmpty {
            let slug = content.name.lowercased().split(separator: " ").first.map(String.init) ?? "hello"
            content.email = "\(slug)@business.com"
        }
        if content.website.isEmpty { content.website = "www.yoursite.com" }
        if content.tagline.isEmpty { content.tagline = "Professional services" }
    }

    // MARK: - Palettes

    static func palette(for template: ProBusinessCardTemplate) -> ProBusinessCardPalette? {
        switch template {
        case .classic:
            return ProBusinessCardPalette(accentHex: "#0B3D5C", backgroundHex: "#FFFFFF", foregroundHex: "#0A1628")
        case .boldTrade:
            return ProBusinessCardPalette(accentHex: "#FBBF24", backgroundHex: "#0B1220", foregroundHex: "#F8FAFC")
        case .neonEdge:
            return ProBusinessCardPalette(accentHex: "#22D3EE", backgroundHex: "#020617", foregroundHex: "#F0FDFA")
        case .editorial, .letterpress:
            return ProBusinessCardPalette(accentHex: "#57534E", backgroundHex: "#FAFAF9", foregroundHex: "#1C1917")
        case .swissGrid, .lineMinimal:
            return ProBusinessCardPalette(accentHex: "#E11D48", backgroundHex: "#FFFFFF", foregroundHex: "#0F172A")
        case .gradientPro:
            return ProBusinessCardPalette(accentHex: "#4F46E5", backgroundHex: "#FFFFFF", foregroundHex: "#1E1B4B")
        case .logoMark:
            return ProBusinessCardPalette(accentHex: "#6366F1", backgroundHex: "#FFFFFF", foregroundHex: "#111827")
        case .twoToneSplit:
            return ProBusinessCardPalette(accentHex: "#0284C7", backgroundHex: "#F8FAFC", foregroundHex: "#0C4A6E")
        case .minimalMono:
            return ProBusinessCardPalette(accentHex: "#18181B", backgroundHex: "#FFFFFF", foregroundHex: "#18181B")
        case .glassFrost:
            return ProBusinessCardPalette(accentHex: "#4F46E5", backgroundHex: "#CBD5E1", foregroundHex: "#0F172A")
        case .stampBadge:
            return ProBusinessCardPalette(accentHex: "#92400E", backgroundHex: "#FFFBEB", foregroundHex: "#451A03")
        case .monogram:
            return ProBusinessCardPalette(accentHex: "#7C3AED", backgroundHex: "#FFFFFF", foregroundHex: "#1F2937")
        case .watermark:
            return ProBusinessCardPalette(accentHex: "#475569", backgroundHex: "#FFFFFF", foregroundHex: "#0F172A")
        case .qrFirst:
            return ProBusinessCardPalette(accentHex: "#047857", backgroundHex: "#FFFFFF", foregroundHex: "#064E3B")
        case .geometricGrid:
            return ProBusinessCardPalette(accentHex: "#1D4ED8", backgroundHex: "#FFFFFF", foregroundHex: "#1E3A8A")
        case .diagonalBands:
            return ProBusinessCardPalette(accentHex: "#F43F5E", backgroundHex: "#FFFBFA", foregroundHex: "#881337")
        case .circleFrame:
            return ProBusinessCardPalette(accentHex: "#0E7490", backgroundHex: "#FFFFFF", foregroundHex: "#164E63")
        case .hexAccent:
            return ProBusinessCardPalette(accentHex: "#4D7C0F", backgroundHex: "#F7FEE7", foregroundHex: "#365314")
        case .cornerBlocks:
            return ProBusinessCardPalette(accentHex: "#C2410C", backgroundHex: "#FFFFFF", foregroundHex: "#431407")
        case .splitVertical:
            return ProBusinessCardPalette(accentHex: "#312E81", backgroundHex: "#FFFFFF", foregroundHex: "#1E1B4B")
        case .arcSweep:
            return ProBusinessCardPalette(accentHex: "#A21CAF", backgroundHex: "#FAF5FF", foregroundHex: "#581C87")
        case .photoForward:
            return nil
        }
    }

    // MARK: - Style & options

    private static func applyStyle(_ t: ProBusinessCardTemplate, to style: inout ProBusinessCardStyle, name: String) {
        style.backgroundStyle = .solid
        style.borderStyle = .none
        style.fontPairing = .modern
        style.logoMask = .roundedRect
        style.photoMask = .circle
        style.logoScale = .medium
        style.photoScale = .off
        style.photoPlacement = .bottomRight
        style.logoCornerRadius = 12

        switch t {
        case .classic:
            style.borderStyle = .accent
            style.fontPairing = .classic
            style.logoScale = .large
        case .boldTrade:
            style.backgroundStyle = .solid
            style.fontPairing = .bold
            style.logoScale = .large
        case .watermark:
            style.watermark.isEnabled = true
            style.watermark.text = name
            style.watermark.opacity = 0.1
            style.watermark.normalizedX = 0.5
            style.watermark.normalizedY = 0.48
            style.logoScale = .medium
        case .monogram:
            style.logoScale = .large
            style.logoMask = .circle
        case .editorial:
            style.fontPairing = .classic
            style.borderStyle = .thin
            style.logoScale = .medium
        case .swissGrid, .lineMinimal:
            style.fontPairing = .modern
            style.logoScale = .medium
            style.backgroundStyle = .patternLines
        case .minimalMono:
            style.logoScale = .small
        case .qrFirst:
            style.logoScale = .large
        case .gradientPro:
            style.backgroundStyle = .gradient
            style.logoScale = .hero
        case .logoMark:
            style.logoScale = .hero
            style.logoMask = .roundedRect
        case .twoToneSplit:
            style.backgroundStyle = .gradient
        case .glassFrost:
            style.backgroundStyle = .solid
        case .stampBadge:
            style.borderStyle = .double
            style.backgroundStyle = .patternDots
            style.logoMask = .circle
        case .neonEdge:
            style.borderStyle = .accent
            style.logoScale = .large
        case .letterpress:
            style.fontPairing = .classic
            style.borderStyle = .thin
        case .geometricGrid, .hexAccent:
            style.logoScale = .large
            style.logoMask = .none
        case .diagonalBands, .cornerBlocks:
            style.logoScale = .medium
        case .circleFrame:
            style.logoScale = .hero
            style.logoMask = .circle
        case .splitVertical:
            style.logoScale = .large
            style.backgroundStyle = .gradient
        case .arcSweep:
            style.logoScale = .medium
            style.logoMask = .circle
        case .photoForward:
            break
        }
    }

    private static func applyOptions(_ t: ProBusinessCardTemplate, to options: inout ProBusinessCardOptions) {
        options.showsLogo = true
        options.showsQR = true
        options.showsPhoto = false
        options.textAlignment = .leading
        options.showsSkills = false

        switch t {
        case .minimalMono:
            options.showsLogo = false
            options.showsQR = false
            options.textAlignment = .center
        case .editorial, .letterpress, .watermark:
            options.showsQR = false
        case .logoMark, .gradientPro, .circleFrame:
            options.textAlignment = .center
        case .qrFirst:
            options.showsQR = true
            options.textAlignment = .leading
        case .swissGrid, .lineMinimal, .geometricGrid, .diagonalBands:
            options.textAlignment = .leading
        case .monogram:
            options.showsQR = false
        case .photoForward:
            break
        default:
            break
        }
    }

    // MARK: - Canvas shapes

    static func shapeLayers(for design: ProBusinessCardDesign, canvasSize: CGSize) -> [CardCanvasLayer] {
        let t = design.template.renderTemplate
        let accent = design.palette.accentHex
        let fg = design.palette.foregroundHex
        var result: [CardCanvasLayer] = []

        func add(
            _ name: String, _ type: CardShapeType,
            fill: String, cx: Double, cy: Double, w: Double, h: Double,
            stroke: String? = nil, strokeWidth: Double = 0,
            useGradient: Bool = false, rotation: Double = 0, opacity: Double = 1
        ) {
            var layer = shape(name: name, type: type, fill: fill, centerX: cx, centerY: cy, width: w, height: h,
                              stroke: stroke, strokeWidth: strokeWidth, useGradient: useGradient, rotation: rotation)
            layer.opacity = opacity
            result.append(layer)
        }

        switch t {
        case .classic:
            add("Accent column", .rectangle, fill: accent, cx: 0.035, cy: 0.5, w: 0.07, h: 1.02)
            add("Corner arc", .quarterCircle, fill: accent, cx: 0.96, cy: 0.06, w: 0.28, h: 0.28, opacity: 0.22)
            add("Corner dot", .circle, fill: accent, cx: 0.88, cy: 0.14, w: 0.05, h: 0.05, opacity: 0.55)
        case .boldTrade:
            add("Corner wedge", .triangleHalf, fill: accent, cx: 0.96, cy: 0.96, w: 0.52, h: 0.52, rotation: 90, opacity: 0.55)
            add("Top slab", .rectangle, fill: accent, cx: 0.5, cy: 0.035, w: 0.92, h: 0.045, useGradient: true)
            add("Side bar", .accentBar, fill: accent, cx: 0.04, cy: 0.5, w: 0.018, h: 0.72, opacity: 0.85)
        case .editorial:
            add("Top rule", .accentBar, fill: fg, cx: 0.5, cy: 0.085, w: 0.28, h: 0.01, opacity: 0.35)
            add("Diamond", .diamond, fill: accent, cx: 0.5, cy: 0.085, w: 0.055, h: 0.055, opacity: 0.65)
            add("Bottom rule", .accentBar, fill: fg, cx: 0.5, cy: 0.915, w: 0.42, h: 0.006, opacity: 0.18)
        case .swissGrid:
            add("Left column", .rectangle, fill: accent, cx: 0.075, cy: 0.5, w: 0.15, h: 1.02)
            add("Grid chevron", .chevron, fill: fg, cx: 0.075, cy: 0.5, w: 0.08, h: 0.32, opacity: 0.95)
            add("Cross H", .accentBar, fill: fg, cx: 0.58, cy: 0.36, w: 0.72, h: 0.004, opacity: 0.14)
            add("Cross V", .accentBar, fill: fg, cx: 0.58, cy: 0.62, w: 0.004, h: 0.55, opacity: 0.14)
            add("Accent square", .rectangle, fill: accent, cx: 0.94, cy: 0.12, w: 0.1, h: 0.1, opacity: 0.35)
        case .gradientPro:
            add("Gradient band", .rectangle, fill: accent, cx: 0.5, cy: design.aspect.isPortrait ? 0.1 : 0.11,
                w: 0.98, h: design.aspect.isPortrait ? 0.18 : 0.22, useGradient: true)
            add("Band accent", .circle, fill: accent, cx: 0.92, cy: 0.2, w: 0.14, h: 0.14, opacity: 0.2)
        case .twoToneSplit:
            add("Split panel", .triangleHalf, fill: accent, cx: 0.9, cy: 0.82, w: 0.48, h: 0.48, useGradient: true, opacity: 0.32)
            add("Split line", .accentBar, fill: accent, cx: 0.72, cy: 0.5, w: 0.006, h: 0.88, opacity: 0.35)
        case .neonEdge:
            add("Neon corner", .triangleHalf, fill: accent, cx: 0.98, cy: 0.04, w: 0.22, h: 0.22, rotation: 180, opacity: 0.75)
            add("Neon bar", .accentBar, fill: accent, cx: 0.5, cy: 0.96, w: 0.78, h: 0.014, opacity: 0.55)
            add("Glow dot", .circle, fill: accent, cx: 0.08, cy: 0.12, w: 0.08, h: 0.08, opacity: 0.45)
        case .stampBadge:
            add("Badge ring", .circle, fill: "#00000000", cx: 0.78, cy: 0.34, w: 0.34, h: 0.34, stroke: accent, strokeWidth: 3)
            add("Badge fill", .circle, fill: accent, cx: 0.78, cy: 0.34, w: 0.22, h: 0.22, opacity: 0.12)
        case .glassFrost:
            add("Frost panel", .rectangle, fill: "#FFFFFF", cx: 0.5, cy: 0.52, w: 0.9, h: 0.8, opacity: 0.62)
            add("Frost corner", .quarterCircle, fill: accent, cx: 0.04, cy: 0.96, w: 0.24, h: 0.24, opacity: 0.15)
        case .letterpress:
            add("Top rule", .accentBar, fill: fg, cx: 0.5, cy: 0.1, w: 0.32, h: 0.008, opacity: 0.25)
            add("Bottom rule", .accentBar, fill: fg, cx: 0.5, cy: 0.9, w: 0.55, h: 0.006, opacity: 0.2)
        case .logoMark:
            add("Logo halo", .circle, fill: accent, cx: 0.5, cy: 0.34, w: 0.56, h: 0.56, opacity: 0.14)
            add("Logo diamond", .diamond, fill: accent, cx: 0.5, cy: 0.34, w: 0.12, h: 0.12, opacity: 0.22)
            add("Bottom accent", .accentBar, fill: accent, cx: 0.5, cy: 0.92, w: 0.4, h: 0.008, opacity: 0.35)
        case .monogram:
            add("Seal ring", .circle, fill: "#00000000", cx: 0.14, cy: 0.28, w: 0.26, h: 0.26, stroke: accent, strokeWidth: 2)
            add("Seal fill", .circle, fill: accent, cx: 0.14, cy: 0.28, w: 0.16, h: 0.16, opacity: 0.1)
        case .minimalMono:
            add("Center rule", .accentBar, fill: fg, cx: 0.5, cy: 0.5, w: 0.42, h: 0.008, opacity: 0.3)
            add("Side ticks", .accentBar, fill: fg, cx: 0.28, cy: 0.5, w: 0.006, h: 0.12, opacity: 0.2)
            add("Side ticks R", .accentBar, fill: fg, cx: 0.72, cy: 0.5, w: 0.006, h: 0.12, opacity: 0.2)
        case .qrFirst:
            add("QR panel", .rectangle, fill: accent, cx: 0.82, cy: 0.5, w: 0.32, h: 0.78, opacity: 0.12)
            add("QR stripe", .accentBar, fill: accent, cx: 0.66, cy: 0.5, w: 0.012, h: 0.72, opacity: 0.35)
        case .geometricGrid:
            add("Block TL", .rectangle, fill: accent, cx: 0.1, cy: 0.12, w: 0.2, h: 0.2, opacity: 0.28)
            add("Block TR", .circle, fill: accent, cx: 0.92, cy: 0.14, w: 0.18, h: 0.18, opacity: 0.2)
            add("Block BR", .rectangle, fill: accent, cx: 0.9, cy: 0.88, w: 0.22, h: 0.22, opacity: 0.24)
            add("Block BL", .hexagon, fill: accent, cx: 0.1, cy: 0.88, w: 0.16, h: 0.16, opacity: 0.18)
            add("Grid V", .accentBar, fill: fg, cx: 0.68, cy: 0.5, w: 0.005, h: 0.9, opacity: 0.12)
            add("Grid H", .accentBar, fill: fg, cx: 0.5, cy: 0.58, w: 0.88, h: 0.005, opacity: 0.12)
        case .diagonalBands:
            add("Band 1", .parallelogram, fill: accent, cx: 0.86, cy: 0.18, w: 0.42, h: 0.1, rotation: -38, opacity: 0.48)
            add("Band 2", .parallelogram, fill: accent, cx: 0.9, cy: 0.36, w: 0.48, h: 0.08, rotation: -38, opacity: 0.32)
            add("Band 3", .parallelogram, fill: accent, cx: 0.88, cy: 0.52, w: 0.38, h: 0.06, rotation: -38, opacity: 0.2)
            add("Band dot", .circle, fill: accent, cx: 0.12, cy: 0.88, w: 0.08, h: 0.08, opacity: 0.35)
        case .circleFrame:
            add("Outer ring", .circle, fill: "#00000000", cx: 0.5, cy: 0.32, w: 0.54, h: 0.54, stroke: accent, strokeWidth: 2.5)
            add("Mid ring", .circle, fill: "#00000000", cx: 0.5, cy: 0.32, w: 0.38, h: 0.38, stroke: accent, strokeWidth: 1, opacity: 0.35)
            add("Inner dot", .circle, fill: accent, cx: 0.5, cy: 0.32, w: 0.1, h: 0.1, opacity: 0.45)
        case .hexAccent:
            add("Hex large", .hexagon, fill: accent, cx: 0.9, cy: 0.16, w: 0.28, h: 0.28, opacity: 0.28)
            add("Hex mid", .hexagon, fill: accent, cx: 0.78, cy: 0.28, w: 0.14, h: 0.14, opacity: 0.18)
            add("Hex small", .hexagon, fill: accent, cx: 0.08, cy: 0.88, w: 0.12, h: 0.12, opacity: 0.22)
            add("Hex line", .accentBar, fill: accent, cx: 0.5, cy: 0.92, w: 0.55, h: 0.008, opacity: 0.3)
        case .cornerBlocks:
            add("Block A", .rectangle, fill: accent, cx: 0.07, cy: 0.09, w: 0.14, h: 0.14, opacity: 0.45)
            add("Block B", .rectangle, fill: accent, cx: 0.16, cy: 0.09, w: 0.14, h: 0.14, opacity: 0.28)
            add("Block C", .rectangle, fill: accent, cx: 0.07, cy: 0.18, w: 0.14, h: 0.14, opacity: 0.18)
            add("Corner triangle", .triangle, fill: accent, cx: 0.94, cy: 0.92, w: 0.22, h: 0.22, rotation: 180, opacity: 0.35)
            add("Corner circle", .circle, fill: accent, cx: 0.92, cy: 0.12, w: 0.1, h: 0.1, opacity: 0.25)
        case .splitVertical:
            add("Left panel", .rectangle, fill: accent, cx: 0.24, cy: 0.5, w: 0.42, h: 0.98, useGradient: true, opacity: 0.22)
            add("Left slab", .rectangle, fill: accent, cx: 0.08, cy: 0.5, w: 0.12, h: 0.98, opacity: 0.55)
            add("Divider", .accentBar, fill: accent, cx: 0.46, cy: 0.5, w: 0.008, h: 0.9, opacity: 0.5)
        case .lineMinimal:
            add("Line 1", .accentBar, fill: accent, cx: 0.065, cy: 0.5, w: 0.012, h: 0.72)
            add("Line 2", .accentBar, fill: fg, cx: 0.095, cy: 0.42, w: 0.006, h: 0.52, opacity: 0.35)
            add("Line 3", .accentBar, fill: fg, cx: 0.12, cy: 0.36, w: 0.006, h: 0.38, opacity: 0.2)
            add("Accent square", .rectangle, fill: accent, cx: 0.92, cy: 0.1, w: 0.08, h: 0.08, opacity: 0.4)
        case .arcSweep:
            add("Arc sweep", .quarterCircle, fill: accent, cx: 0.02, cy: 0.98, w: 0.55, h: 0.55, opacity: 0.28)
            add("Arc inner", .quarterCircle, fill: accent, cx: 0.06, cy: 0.94, w: 0.32, h: 0.32, opacity: 0.15)
            add("Accent dot", .circle, fill: accent, cx: 0.92, cy: 0.1, w: 0.08, h: 0.08, opacity: 0.5)
            add("Accent bar", .accentBar, fill: accent, cx: 0.88, cy: 0.22, w: 0.18, h: 0.008, opacity: 0.35)
        case .watermark, .photoForward:
            break
        }

        if design.style.borderStyle != .none {
            result.append(borderShape(from: design))
        }
        return result
    }

    // MARK: - Layout overrides

    static func layout(for design: ProBusinessCardDesign) -> LayoutSpec {
        let t = design.template.renderTemplate
        switch t {
        case .logoMark, .circleFrame, .gradientPro:
            return LayoutSpec(logoCenter: (0.5, 0.34), logoScale: .hero, nameCenter: (0.5, 0.58), contactCenter: (0.5, 0.82), textAlign: .center)
        case .minimalMono:
            return LayoutSpec(nameCenter: (0.5, 0.42), contactCenter: (0.5, 0.62), textAlign: .center)
        case .editorial, .letterpress:
            return LayoutSpec(logoCenter: (0.5, 0.2), nameCenter: (0.5, 0.42), contactCenter: (0.5, 0.72), textAlign: .center)
        case .swissGrid, .lineMinimal:
            return LayoutSpec(logoCenter: (0.22, 0.18), nameCenter: (0.52, 0.28), contactCenter: (0.52, 0.82), qrCenter: (0.88, 0.18))
        case .qrFirst:
            return LayoutSpec(logoCenter: (0.2, 0.2), nameCenter: (0.38, 0.38), contactCenter: (0.38, 0.72), qrCenter: (0.82, 0.5))
        case .monogram:
            return LayoutSpec(logoCenter: (0.28, 0.28), nameCenter: (0.58, 0.26), contactCenter: (0.58, 0.72))
        case .splitVertical:
            return LayoutSpec(logoCenter: (0.72, 0.22), nameCenter: (0.72, 0.42), contactCenter: (0.72, 0.78), textAlign: .leading)
        case .boldTrade, .neonEdge:
            return LayoutSpec(logoCenter: (0.18, 0.2), nameCenter: (0.42, 0.38), contactCenter: (0.42, 0.78))
        case .geometricGrid, .hexAccent, .cornerBlocks:
            return LayoutSpec(logoCenter: (0.2, 0.22), nameCenter: (0.48, 0.32), contactCenter: (0.48, 0.8))
        case .diagonalBands, .arcSweep:
            return LayoutSpec(logoCenter: (0.18, 0.22), nameCenter: (0.42, 0.36), contactCenter: (0.42, 0.78))
        case .classic:
            return LayoutSpec(logoCenter: (0.2, 0.2), nameCenter: (0.48, 0.32), contactCenter: (0.48, 0.8), qrCenter: (0.88, 0.85))
        default:
            return LayoutSpec(logoCenter: (0.18, 0.2), nameCenter: (0.42, 0.34), contactCenter: (0.42, 0.78), qrCenter: (0.88, 0.85))
        }
    }

    // MARK: - Shape helpers

    private static func shape(
        name: String, type: CardShapeType, fill: String,
        centerX: Double, centerY: Double, width: Double, height: Double,
        stroke: String? = nil, strokeWidth: Double = 0,
        useGradient: Bool = false, rotation: Double = 0
    ) -> CardCanvasLayer {
        CardCanvasLayer(
            name: name, kind: .shape,
            transform: CardLayerTransform(centerX: centerX, centerY: centerY, width: width, height: height, rotation: rotation),
            isLocked: true,
            payload: .shape(CardShapePayload(shapeType: type, fillHex: fill, strokeHex: stroke, strokeWidth: strokeWidth, useGradient: useGradient))
        )
    }

    private static func borderShape(from design: ProBusinessCardDesign) -> CardCanvasLayer {
        shape(
            name: "Border", type: .rectangle, fill: "#00000000",
            centerX: 0.5, centerY: 0.5, width: 0.96, height: 0.94,
            stroke: design.palette.foregroundHex,
            strokeWidth: design.style.borderStyle == .accent ? 2 : 1
        )
    }
}
