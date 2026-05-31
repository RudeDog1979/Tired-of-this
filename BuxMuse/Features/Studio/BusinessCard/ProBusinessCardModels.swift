//
//  ProBusinessCardModels.swift
//  BuxMuse
//
//  Pro Business Card Studio — layer-ready documents, 15 templates, style system.
//

import Foundation
import CoreGraphics

// MARK: - Template (15 launch templates)

public enum ProBusinessCardTemplate: String, Codable, CaseIterable, Identifiable, Sendable {
    case classic
    case boldTrade
    case watermark
    case monogram
    case editorial
    case swissGrid
    case qrFirst
    case gradientPro
    case logoMark
    case twoToneSplit
    case minimalMono
    case glassFrost
    case stampBadge
    case neonEdge
    case letterpress
    case photoForward // legacy decode only
    // Geometric collection (Adobe Stock–inspired)
    case geometricGrid
    case diagonalBands
    case circleFrame
    case hexAccent
    case cornerBlocks
    case splitVertical
    case lineMinimal
    case arcSweep

    public var id: String { rawValue }

    public static var launchTemplates: [ProBusinessCardTemplate] {
        allCases.filter { $0 != .photoForward }
    }

    public var title: String {
        switch self {
        case .classic: return "Classic"
        case .boldTrade: return "Bold Trade"
        case .watermark: return "Watermark"
        case .monogram: return "Monogram"
        case .editorial: return "Editorial"
        case .swissGrid: return "Swiss Grid"
        case .qrFirst: return "QR First"
        case .gradientPro: return "Gradient Pro"
        case .logoMark: return "Logo Mark"
        case .twoToneSplit: return "Two-Tone"
        case .minimalMono: return "Minimal"
        case .glassFrost: return "Glass Frost"
        case .stampBadge: return "Stamp Badge"
        case .neonEdge: return "Neon Edge"
        case .letterpress: return "Letterpress"
        case .photoForward: return "Brand Portrait"
        case .geometricGrid: return "Geo Grid"
        case .diagonalBands: return "Diagonal"
        case .circleFrame: return "Circle Frame"
        case .hexAccent: return "Hex Accent"
        case .cornerBlocks: return "Corner Blocks"
        case .splitVertical: return "Split Panel"
        case .lineMinimal: return "Line Stack"
        case .arcSweep: return "Arc Sweep"
        }
    }

    public var subtitle: String {
        switch self {
        case .classic: return "Accent stripe · clean hierarchy"
        case .boldTrade: return "Dark slab · strong type"
        case .watermark: return "Oversized name texture"
        case .monogram: return "Letter seal + logo"
        case .editorial: return "Luxury serif spacing"
        case .swissGrid: return "Swiss precision grid"
        case .qrFirst: return "Scan-first layout"
        case .gradientPro: return "Gradient header band"
        case .logoMark: return "Logo-forward hero"
        case .twoToneSplit: return "Diagonal color block"
        case .minimalMono: return "Type-only elegance"
        case .glassFrost: return "Frosted glass panel"
        case .stampBadge: return "Circular seal mark"
        case .neonEdge: return "Neon glow edge"
        case .letterpress: return "Embossed classic rule"
        case .photoForward: return "Logo-led portrait"
        case .geometricGrid: return "Modular grid geometry"
        case .diagonalBands: return "Parallel slash stripes"
        case .circleFrame: return "Bold circle motif"
        case .hexAccent: return "Honeycomb accent"
        case .cornerBlocks: return "Stacked corner shapes"
        case .splitVertical: return "Two-panel vertical split"
        case .lineMinimal: return "Swiss line rhythm"
        case .arcSweep: return "Quarter arc flourish"
        }
    }

    public var systemImage: String {
        switch self {
        case .classic: return "rectangle.leadinghalf.filled"
        case .boldTrade: return "bold"
        case .watermark: return "textformat.size.larger"
        case .monogram: return "seal.fill"
        case .editorial: return "text.book.closed.fill"
        case .swissGrid: return "square.grid.3x3.fill"
        case .qrFirst: return "qrcode"
        case .gradientPro: return "paintbrush.fill"
        case .logoMark: return "building.2.fill"
        case .twoToneSplit: return "square.split.diagonal.fill"
        case .minimalMono: return "textformat"
        case .glassFrost: return "rectangle.inset.filled"
        case .stampBadge: return "circle.circle.fill"
        case .neonEdge: return "sparkles"
        case .letterpress: return "lanyardcard.fill"
        case .photoForward: return "person.crop.circle.fill"
        case .geometricGrid: return "grid"
        case .diagonalBands: return "line.diagonal"
        case .circleFrame: return "circle.grid.2x2.fill"
        case .hexAccent: return "hexagon.fill"
        case .cornerBlocks: return "square.stack.3d.up.fill"
        case .splitVertical: return "rectangle.split.2x1.fill"
        case .lineMinimal: return "line.3.horizontal"
        case .arcSweep: return "circle.bottomhalf.filled"
        }
    }

    public var collection: ProBusinessCardCollection {
        switch self {
        case .classic, .editorial, .minimalMono, .letterpress, .swissGrid, .lineMinimal, .splitVertical:
            return .corporate
        case .boldTrade, .stampBadge, .twoToneSplit, .cornerBlocks:
            return .trade
        case .watermark, .monogram, .glassFrost, .neonEdge, .gradientPro, .arcSweep:
            return .creative
        case .qrFirst, .logoMark, .photoForward:
            return .digital
        case .geometricGrid, .diagonalBands, .circleFrame, .hexAccent:
            return .geometric
        }
    }

    public var renderTemplate: ProBusinessCardTemplate {
        self == .photoForward ? .logoMark : self
    }
}

public enum ProBusinessCardCollection: String, CaseIterable, Identifiable, Sendable {
    case corporate, trade, creative, digital, geometric
    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .corporate: return "Corporate"
        case .trade: return "Trade & Field"
        case .creative: return "Creative"
        case .digital: return "Digital & QR"
        case .geometric: return "Geometric"
        }
    }

    public var templates: [ProBusinessCardTemplate] {
        ProBusinessCardTemplate.launchTemplates.filter { $0.collection == self }
    }
}

// MARK: - Aspect

public enum ProBusinessCardAspect: String, Codable, CaseIterable, Identifiable, Sendable {
    case standardUS
    case portraitVertical
    case a8
    case squareSocial

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .standardUS: return "Landscape"
        case .portraitVertical: return "Portrait"
        case .a8: return "A8"
        case .squareSocial: return "Square"
        }
    }

    public var detail: String {
        switch self {
        case .standardUS: return "3.5 × 2 in"
        case .portraitVertical: return "2 × 3.5 in"
        case .a8: return "74 × 52 mm"
        case .squareSocial: return "Social post"
        }
    }

    public var previewWidth: CGFloat { 340 }

    public var aspectRatio: CGFloat {
        switch self {
        case .standardUS: return 3.5 / 2.0
        case .portraitVertical: return 2.0 / 3.5
        case .a8: return 74.0 / 52.0
        case .squareSocial: return 1.0
        }
    }

    public var previewSize: CGSize {
        CGSize(width: previewWidth, height: previewWidth / aspectRatio)
    }

    public var printSize: CGSize {
        switch self {
        case .standardUS: return CGSize(width: 252, height: 144)
        case .portraitVertical: return CGSize(width: 144, height: 252)
        case .a8: return CGSize(width: 210, height: 147)
        case .squareSocial: return CGSize(width: 360, height: 360)
        }
    }

    public var safeInsetRatio: CGFloat { 0.07 }

    public var isPortrait: Bool { self == .portraitVertical }
}

public enum ProBusinessCardAlignment: String, Codable, CaseIterable, Identifiable, Sendable {
    case leading, center
    public var id: String { rawValue }
}

public enum ProBusinessCardIdentityMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case business, balanced, personal
    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .business: return "Business"
        case .balanced: return "Balanced"
        case .personal: return "Personal"
        }
    }

    public var subtitle: String {
        switch self {
        case .business: return "Large logo · no portrait — best for companies"
        case .balanced: return "Logo + corner photo — professional mix"
        case .personal: return "Hero portrait strip · smaller logo — freelancer look"
        }
    }
}

public enum ProBusinessCardLogoScale: String, Codable, CaseIterable, Identifiable, Sendable {
    case small, medium, large, hero
    public var id: String { rawValue }

    public var pointRatio: CGFloat {
        switch self {
        case .small: return 0.14
        case .medium: return 0.20
        case .large: return 0.28
        case .hero: return 0.38
        }
    }
}

public enum ProBusinessCardPhotoScale: String, Codable, CaseIterable, Identifiable, Sendable {
    case off, corner, medium, hero
    public var id: String { rawValue }

    public var pointRatio: CGFloat {
        switch self {
        case .off: return 0
        case .corner: return 0.16
        case .medium: return 0.24
        case .hero: return 0.38
        }
    }
}

public enum ProBusinessCardPhotoPlacement: String, Codable, CaseIterable, Identifiable, Sendable {
    case topLeft, top, topRight
    case left, center, right
    case bottomLeft, bottom, bottomRight
    case leftBand, topBand, rightBand, bottomBand

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .topLeft: return "Top left"
        case .top: return "Top"
        case .topRight: return "Top right"
        case .left: return "Left"
        case .center: return "Center"
        case .right: return "Right"
        case .bottomLeft: return "Bottom left"
        case .bottom: return "Bottom"
        case .bottomRight: return "Bottom right"
        case .leftBand: return "Left strip"
        case .topBand: return "Top strip"
        case .rightBand: return "Right strip"
        case .bottomBand: return "Bottom strip"
        }
    }
}

public struct ProBusinessCardCanvasLayer: Codable, Equatable, Sendable {
    public var normalizedX: Double
    public var normalizedY: Double
    public var scale: Double
    public var rotation: Double

    public init(normalizedX: Double = 0.5, normalizedY: Double = 0.5, scale: Double = 1, rotation: Double = 0) {
        self.normalizedX = normalizedX
        self.normalizedY = normalizedY
        self.scale = scale
        self.rotation = rotation
    }
}

public enum ProBusinessCardCanvasLayerKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case photo, logo, name, qr, watermark

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .photo: return "Photo"
        case .logo: return "Logo"
        case .name: return "Name"
        case .qr: return "QR"
        case .watermark: return "Watermark"
        }
    }

    public func isActive(in design: ProBusinessCardDesign) -> Bool {
        switch self {
        case .photo: return design.options.showsPhoto && design.style.photoScale != .off
        case .logo: return design.options.showsLogo
        case .name: return true
        case .qr: return design.options.showsQR
        case .watermark: return design.style.watermark.isEnabled
        }
    }

    public static func enable(_ kind: Self, in design: inout ProBusinessCardDesign) {
        switch kind {
        case .photo:
            design.options.showsPhoto = true
            if design.style.photoScale == .off { design.style.photoScale = .medium }
        case .logo:
            design.options.showsLogo = true
        case .name:
            break
        case .qr:
            design.options.showsQR = true
        case .watermark:
            design.style.watermark.isEnabled = true
        }
    }
}

public struct ProBusinessCardPhotoAdjustments: Codable, Equatable, Sendable {
    public var filterName: String
    public var brightness: Double
    public var contrast: Double
    public var saturation: Double
    public var sharpness: Double
    public var exposure: Double
    public var brilliance: Double

    public init(
        filterName: String = "none",
        brightness: Double = 0,
        contrast: Double = 1,
        saturation: Double = 1,
        sharpness: Double = 0,
        exposure: Double = 0,
        brilliance: Double = 0
    ) {
        self.filterName = filterName
        self.brightness = brightness
        self.contrast = contrast
        self.saturation = saturation
        self.sharpness = sharpness
        self.exposure = exposure
        self.brilliance = brilliance
    }

    private enum CodingKeys: String, CodingKey {
        case filterName, brightness, contrast, saturation, sharpness, exposure, brilliance
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        filterName = try c.decodeIfPresent(String.self, forKey: .filterName) ?? "none"
        brightness = try c.decodeIfPresent(Double.self, forKey: .brightness) ?? 0
        contrast = try c.decodeIfPresent(Double.self, forKey: .contrast) ?? 1
        saturation = try c.decodeIfPresent(Double.self, forKey: .saturation) ?? 1
        sharpness = try c.decodeIfPresent(Double.self, forKey: .sharpness) ?? 0
        exposure = try c.decodeIfPresent(Double.self, forKey: .exposure) ?? 0
        brilliance = try c.decodeIfPresent(Double.self, forKey: .brilliance) ?? 0
    }
}

public struct ProBusinessCardTypography: Codable, Equatable, Sendable {
    public var fontID: String
    public var nameScale: Double
    public var taglineScale: Double
    public var contactScale: Double

    public init(
        fontID: String = "modernRounded",
        nameScale: Double = 1,
        taglineScale: Double = 1,
        contactScale: Double = 1
    ) {
        self.fontID = fontID
        self.nameScale = nameScale
        self.taglineScale = taglineScale
        self.contactScale = contactScale
    }
}

public struct ProBusinessCardPhotoTransform: Codable, Equatable, Sendable {
    public var zoom: Double
    public var offsetX: Double
    public var offsetY: Double
    public var rotation: Double

    public init(zoom: Double = 1.0, offsetX: Double = 0, offsetY: Double = 0, rotation: Double = 0) {
        self.zoom = zoom
        self.offsetX = offsetX
        self.offsetY = offsetY
        self.rotation = rotation
    }

    private enum CodingKeys: String, CodingKey { case zoom, offsetX, offsetY, rotation }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        zoom = try c.decodeIfPresent(Double.self, forKey: .zoom) ?? 1.0
        offsetX = try c.decodeIfPresent(Double.self, forKey: .offsetX) ?? 0
        offsetY = try c.decodeIfPresent(Double.self, forKey: .offsetY) ?? 0
        rotation = try c.decodeIfPresent(Double.self, forKey: .rotation) ?? 0
    }
}

public enum ProBusinessCardBackgroundStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    case solid, gradient, patternDots, patternLines, photo
    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .solid: return "Solid"
        case .gradient: return "Gradient"
        case .patternDots: return "Dots"
        case .patternLines: return "Lines"
        case .photo: return "Photo"
        }
    }
}

public enum ProBusinessCardFontPairing: String, Codable, CaseIterable, Identifiable, Sendable {
    case modern, classic, bold
    public var id: String { rawValue }
}

public enum ProBusinessCardBorderStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    case none, thin, double, accent
    public var id: String { rawValue }
}

public enum ProBusinessCardEditorMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case quick, canvas
    public var id: String { rawValue }
}

public struct ProBusinessCardWatermark: Codable, Equatable, Sendable {
    public var isEnabled: Bool
    public var text: String
    public var opacity: Double
    public var scale: Double
    public var rotation: Double
    public var normalizedX: Double
    public var normalizedY: Double

    public init(
        isEnabled: Bool = false,
        text: String = "",
        opacity: Double = 0.10,
        scale: Double = 1.0,
        rotation: Double = -12,
        normalizedX: Double = 0.5,
        normalizedY: Double = 0.45
    ) {
        self.isEnabled = isEnabled
        self.text = text
        self.opacity = opacity
        self.scale = scale
        self.rotation = rotation
        self.normalizedX = normalizedX
        self.normalizedY = normalizedY
    }
}

public struct ProBusinessCardStyle: Codable, Equatable, Sendable {
    public var identityMode: ProBusinessCardIdentityMode
    public var logoScale: ProBusinessCardLogoScale
    public var photoScale: ProBusinessCardPhotoScale
    public var backgroundStyle: ProBusinessCardBackgroundStyle
    public var backgroundPhotoPath: String?
    public var backgroundPhotoOpacity: Double
    public var fontPairing: ProBusinessCardFontPairing
    public var borderStyle: ProBusinessCardBorderStyle
    public var watermark: ProBusinessCardWatermark
    public var editorMode: ProBusinessCardEditorMode
    public var photoPlacement: ProBusinessCardPhotoPlacement
    public var photoTransform: ProBusinessCardPhotoTransform
    public var photoCanvas: ProBusinessCardCanvasLayer?
    public var logoCanvas: ProBusinessCardCanvasLayer?
    public var nameCanvas: ProBusinessCardCanvasLayer?
    public var qrCanvas: ProBusinessCardCanvasLayer?
    public var photoAdjustments: ProBusinessCardPhotoAdjustments
    public var typography: ProBusinessCardTypography
    public var photoMask: CardImageMask
    public var logoMask: CardImageMask
    public var logoCornerRadius: Double

    public init(
        identityMode: ProBusinessCardIdentityMode = .business,
        logoScale: ProBusinessCardLogoScale = .hero,
        photoScale: ProBusinessCardPhotoScale = .off,
        backgroundStyle: ProBusinessCardBackgroundStyle = .solid,
        backgroundPhotoPath: String? = nil,
        backgroundPhotoOpacity: Double = 1.0,
        fontPairing: ProBusinessCardFontPairing = .modern,
        borderStyle: ProBusinessCardBorderStyle = .none,
        watermark: ProBusinessCardWatermark = ProBusinessCardWatermark(),
        editorMode: ProBusinessCardEditorMode = .quick,
        photoPlacement: ProBusinessCardPhotoPlacement = .bottomRight,
        photoTransform: ProBusinessCardPhotoTransform = ProBusinessCardPhotoTransform(),
        photoCanvas: ProBusinessCardCanvasLayer? = nil,
        logoCanvas: ProBusinessCardCanvasLayer? = nil,
        nameCanvas: ProBusinessCardCanvasLayer? = nil,
        qrCanvas: ProBusinessCardCanvasLayer? = nil,
        photoAdjustments: ProBusinessCardPhotoAdjustments = ProBusinessCardPhotoAdjustments(),
        typography: ProBusinessCardTypography = ProBusinessCardTypography(),
        photoMask: CardImageMask = .circle,
        logoMask: CardImageMask = .roundedRect,
        logoCornerRadius: Double = 12
    ) {
        self.identityMode = identityMode
        self.logoScale = logoScale
        self.photoScale = photoScale
        self.backgroundStyle = backgroundStyle
        self.backgroundPhotoPath = backgroundPhotoPath
        self.backgroundPhotoOpacity = backgroundPhotoOpacity
        self.fontPairing = fontPairing
        self.borderStyle = borderStyle
        self.watermark = watermark
        self.editorMode = editorMode
        self.photoPlacement = photoPlacement
        self.photoTransform = photoTransform
        self.photoCanvas = photoCanvas
        self.logoCanvas = logoCanvas
        self.nameCanvas = nameCanvas
        self.qrCanvas = qrCanvas
        self.photoAdjustments = photoAdjustments
        self.typography = typography
        self.photoMask = photoMask
        self.logoMask = logoMask
        self.logoCornerRadius = logoCornerRadius
    }

    private enum CodingKeys: String, CodingKey {
        case identityMode, logoScale, photoScale, backgroundStyle, backgroundPhotoPath
        case backgroundPhotoOpacity, fontPairing, borderStyle, watermark, editorMode
        case photoPlacement, photoTransform, photoCanvas, logoCanvas, nameCanvas, qrCanvas, photoAdjustments, typography
        case photoMask, logoMask, logoCornerRadius
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        identityMode = try c.decodeIfPresent(ProBusinessCardIdentityMode.self, forKey: .identityMode) ?? .business
        logoScale = try c.decodeIfPresent(ProBusinessCardLogoScale.self, forKey: .logoScale) ?? .hero
        photoScale = try c.decodeIfPresent(ProBusinessCardPhotoScale.self, forKey: .photoScale) ?? .off
        backgroundStyle = try c.decodeIfPresent(ProBusinessCardBackgroundStyle.self, forKey: .backgroundStyle) ?? .solid
        backgroundPhotoPath = try c.decodeIfPresent(String.self, forKey: .backgroundPhotoPath)
        backgroundPhotoOpacity = try c.decodeIfPresent(Double.self, forKey: .backgroundPhotoOpacity) ?? 1.0
        fontPairing = try c.decodeIfPresent(ProBusinessCardFontPairing.self, forKey: .fontPairing) ?? .modern
        borderStyle = try c.decodeIfPresent(ProBusinessCardBorderStyle.self, forKey: .borderStyle) ?? .none
        watermark = try c.decodeIfPresent(ProBusinessCardWatermark.self, forKey: .watermark) ?? ProBusinessCardWatermark()
        editorMode = try c.decodeIfPresent(ProBusinessCardEditorMode.self, forKey: .editorMode) ?? .quick
        photoPlacement = try c.decodeIfPresent(ProBusinessCardPhotoPlacement.self, forKey: .photoPlacement) ?? .bottomRight
        photoTransform = try c.decodeIfPresent(ProBusinessCardPhotoTransform.self, forKey: .photoTransform) ?? ProBusinessCardPhotoTransform()
        photoCanvas = try c.decodeIfPresent(ProBusinessCardCanvasLayer.self, forKey: .photoCanvas)
        logoCanvas = try c.decodeIfPresent(ProBusinessCardCanvasLayer.self, forKey: .logoCanvas)
        nameCanvas = try c.decodeIfPresent(ProBusinessCardCanvasLayer.self, forKey: .nameCanvas)
        qrCanvas = try c.decodeIfPresent(ProBusinessCardCanvasLayer.self, forKey: .qrCanvas)
        photoAdjustments = try c.decodeIfPresent(ProBusinessCardPhotoAdjustments.self, forKey: .photoAdjustments) ?? ProBusinessCardPhotoAdjustments()
        typography = try c.decodeIfPresent(ProBusinessCardTypography.self, forKey: .typography) ?? ProBusinessCardTypography()
        photoMask = try c.decodeIfPresent(CardImageMask.self, forKey: .photoMask) ?? .circle
        logoMask = try c.decodeIfPresent(CardImageMask.self, forKey: .logoMask) ?? .roundedRect
        logoCornerRadius = try c.decodeIfPresent(Double.self, forKey: .logoCornerRadius) ?? 12
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(identityMode, forKey: .identityMode)
        try c.encode(logoScale, forKey: .logoScale)
        try c.encode(photoScale, forKey: .photoScale)
        try c.encode(backgroundStyle, forKey: .backgroundStyle)
        try c.encodeIfPresent(backgroundPhotoPath, forKey: .backgroundPhotoPath)
        try c.encode(backgroundPhotoOpacity, forKey: .backgroundPhotoOpacity)
        try c.encode(fontPairing, forKey: .fontPairing)
        try c.encode(borderStyle, forKey: .borderStyle)
        try c.encode(watermark, forKey: .watermark)
        try c.encode(editorMode, forKey: .editorMode)
        try c.encode(photoPlacement, forKey: .photoPlacement)
        try c.encode(photoTransform, forKey: .photoTransform)
        try c.encodeIfPresent(photoCanvas, forKey: .photoCanvas)
        try c.encodeIfPresent(logoCanvas, forKey: .logoCanvas)
        try c.encodeIfPresent(nameCanvas, forKey: .nameCanvas)
        try c.encodeIfPresent(qrCanvas, forKey: .qrCanvas)
        try c.encode(photoAdjustments, forKey: .photoAdjustments)
        try c.encode(typography, forKey: .typography)
        try c.encode(photoMask, forKey: .photoMask)
        try c.encode(logoMask, forKey: .logoMask)
        try c.encode(logoCornerRadius, forKey: .logoCornerRadius)
    }

    public static func businessDefault(businessName: String) -> ProBusinessCardStyle {
        ProBusinessCardStyle(
            identityMode: .business,
            logoScale: .hero,
            photoScale: .off,
            watermark: ProBusinessCardWatermark(isEnabled: false, text: businessName)
        )
    }

    public mutating func applyIdentityMode(_ mode: ProBusinessCardIdentityMode) {
        identityMode = mode
        switch mode {
        case .business:
            logoScale = .hero
            photoScale = .off
            photoPlacement = .bottomRight
        case .balanced:
            logoScale = .large
            photoScale = .corner
            photoPlacement = .topRight
        case .personal:
            logoScale = .medium
            photoScale = .hero
            photoPlacement = .leftBand
        }
        photoCanvas = nil
        logoCanvas = nil
    }

    public mutating func applyPhotoScale(_ scale: ProBusinessCardPhotoScale) {
        photoScale = scale
        switch scale {
        case .off:
            break
        case .corner:
            if photoPlacement.isStrip { photoPlacement = .bottomRight }
        case .medium:
            if photoPlacement.isStrip { photoPlacement = .right }
        case .hero:
            if !photoPlacement.isStrip && photoPlacement != .center {
                photoPlacement = .leftBand
            }
        }
    }

    /// Removes a photo background and returns to the solid palette color.
    public mutating func clearBackgroundPhoto() {
        backgroundPhotoPath = nil
        backgroundPhotoOpacity = 1.0
        if backgroundStyle == .photo {
            backgroundStyle = .solid
        }
    }

    public var hasBackgroundPhoto: Bool {
        backgroundPhotoPath != nil && !(backgroundPhotoPath?.isEmpty ?? true)
    }
}

public struct ProBusinessCardPalette: Codable, Equatable, Sendable {
    public var accentHex: String
    public var backgroundHex: String
    public var foregroundHex: String

    public init(accentHex: String, backgroundHex: String, foregroundHex: String) {
        self.accentHex = accentHex
        self.backgroundHex = backgroundHex
        self.foregroundHex = foregroundHex
    }

    public static let presets: [(name: String, palette: ProBusinessCardPalette)] = [
        ("Indigo", ProBusinessCardPalette(accentHex: "#5A55F5", backgroundHex: "#FFFFFF", foregroundHex: "#111827")),
        ("Ocean", ProBusinessCardPalette(accentHex: "#0B9FDA", backgroundHex: "#F0F9FF", foregroundHex: "#0C4A6E")),
        ("Emerald", ProBusinessCardPalette(accentHex: "#00C882", backgroundHex: "#FFFFFF", foregroundHex: "#064E3B")),
        ("Crimson", ProBusinessCardPalette(accentHex: "#FF3366", backgroundHex: "#FFF1F2", foregroundHex: "#881337")),
        ("Gold", ProBusinessCardPalette(accentHex: "#D4AF37", backgroundHex: "#FFFBEB", foregroundHex: "#422006")),
        ("Violet", ProBusinessCardPalette(accentHex: "#8B5CF6", backgroundHex: "#FAF5FF", foregroundHex: "#3B0764")),
        ("Slate", ProBusinessCardPalette(accentHex: "#334155", backgroundHex: "#F8FAFC", foregroundHex: "#0F172A")),
        ("Obsidian", ProBusinessCardPalette(accentHex: "#5A55F5", backgroundHex: "#1E293B", foregroundHex: "#F8FAFC")),
    ]

    public static var defaultPreset: ProBusinessCardPalette { presets[0].palette }
}

public struct ProBusinessCardContent: Codable, Equatable, Sendable {
    public var name: String
    public var tagline: String
    public var phone: String
    public var email: String
    public var skills: String
    public var website: String
    public var photoPath: String?

    public init(
        name: String = "",
        tagline: String = "",
        phone: String = "",
        email: String = "",
        skills: String = "",
        website: String = "",
        photoPath: String? = nil
    ) {
        self.name = name
        self.tagline = tagline
        self.phone = phone
        self.email = email
        self.skills = skills
        self.website = website
        self.photoPath = photoPath
    }

    public var vCardPayload: String {
        var parts: [String] = ["BEGIN:VCARD", "VERSION:3.0", "FN:\(name)"]
        if !tagline.isEmpty { parts.append("ORG:\(tagline)") }
        if !phone.isEmpty { parts.append("TEL;TYPE=CELL:\(phone)") }
        if !email.isEmpty { parts.append("EMAIL:\(email)") }
        if !website.isEmpty { parts.append("URL:\(website)") }
        parts.append("END:VCARD")
        return parts.joined(separator: "\n")
    }
}

public struct ProBusinessCardOptions: Codable, Equatable, Sendable {
    public var showsPhoto: Bool
    public var showsLogo: Bool
    public var showsQR: Bool
    public var showsSkills: Bool
    public var textAlignment: ProBusinessCardAlignment

    public init(
        showsPhoto: Bool = false,
        showsLogo: Bool = true,
        showsQR: Bool = true,
        showsSkills: Bool = true,
        textAlignment: ProBusinessCardAlignment = .leading
    ) {
        self.showsPhoto = showsPhoto
        self.showsLogo = showsLogo
        self.showsQR = showsQR
        self.showsSkills = showsSkills
        self.textAlignment = textAlignment
    }

    public static var businessDefault: ProBusinessCardOptions {
        ProBusinessCardOptions()
    }
}

public struct ProBusinessCardDesign: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var template: ProBusinessCardTemplate
    public var aspect: ProBusinessCardAspect
    public var palette: ProBusinessCardPalette
    public var options: ProBusinessCardOptions
    public var style: ProBusinessCardStyle
    public var content: ProBusinessCardContent
    public var updatedAt: Date
    public var canvasDocument: CardCanvasDocument?
    public var editorPreferences: CardEditorPreferences?

    public init(
        id: UUID = UUID(),
        title: String,
        template: ProBusinessCardTemplate = .classic,
        aspect: ProBusinessCardAspect = .standardUS,
        palette: ProBusinessCardPalette = .defaultPreset,
        options: ProBusinessCardOptions = .businessDefault,
        style: ProBusinessCardStyle = ProBusinessCardStyle(),
        content: ProBusinessCardContent = ProBusinessCardContent(),
        updatedAt: Date = Date(),
        canvasDocument: CardCanvasDocument? = nil,
        editorPreferences: CardEditorPreferences? = nil
    ) {
        self.id = id
        self.title = title
        self.template = template
        self.aspect = aspect
        self.palette = palette
        self.options = options
        self.style = style
        self.content = content
        self.updatedAt = updatedAt
        self.canvasDocument = canvasDocument
        self.editorPreferences = editorPreferences
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, template, aspect, palette, options, style, content, updatedAt
        case canvasDocument, editorPreferences
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        template = try c.decode(ProBusinessCardTemplate.self, forKey: .template)
        aspect = try c.decode(ProBusinessCardAspect.self, forKey: .aspect)
        palette = try c.decode(ProBusinessCardPalette.self, forKey: .palette)
        options = try c.decode(ProBusinessCardOptions.self, forKey: .options)
        content = try c.decode(ProBusinessCardContent.self, forKey: .content)
        updatedAt = try c.decode(Date.self, forKey: .updatedAt)
        style = try c.decodeIfPresent(ProBusinessCardStyle.self, forKey: .style)
            ?? ProBusinessCardStyle.businessDefault(businessName: content.name)
        canvasDocument = try c.decodeIfPresent(CardCanvasDocument.self, forKey: .canvasDocument)
        editorPreferences = try c.decodeIfPresent(CardEditorPreferences.self, forKey: .editorPreferences)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encode(template, forKey: .template)
        try c.encode(aspect, forKey: .aspect)
        try c.encode(palette, forKey: .palette)
        try c.encode(options, forKey: .options)
        try c.encode(style, forKey: .style)
        try c.encode(content, forKey: .content)
        try c.encode(updatedAt, forKey: .updatedAt)
        try c.encodeIfPresent(canvasDocument, forKey: .canvasDocument)
        try c.encodeIfPresent(editorPreferences, forKey: .editorPreferences)
    }

    public mutating func ensureCanvasDocument() {
        CardCanvasSync.ensureDocument(on: &self)
    }

    public mutating func applyTemplateDefaults() {
        ProBusinessCardTemplatePresets.apply(to: &self)
    }

    public mutating func applyAspectChange(_ aspect: ProBusinessCardAspect) {
        self.aspect = aspect
        style.photoCanvas = nil
        style.logoCanvas = nil
        style.nameCanvas = nil
        style.qrCanvas = nil
        CardCanvasSync.applyTemplateReseed(to: &self)
        updatedAt = Date()
    }
}

public struct ProBusinessCardLibrary: Codable, Equatable, Sendable {
    public var designs: [ProBusinessCardDesign]
    public var selectedDesignID: UUID?

    public init(designs: [ProBusinessCardDesign] = [], selectedDesignID: UUID? = nil) {
        self.designs = designs
        self.selectedDesignID = selectedDesignID
    }

    public var selectedDesign: ProBusinessCardDesign? {
        guard let id = selectedDesignID else { return designs.first }
        return designs.first(where: { $0.id == id }) ?? designs.first
    }

    public static func starterDesigns(
        profileName: String,
        businessName: String,
        tagline: String,
        accentHex: String = ProBusinessCardPalette.defaultPreset.accentHex
    ) -> [ProBusinessCardDesign] {
        let name = businessName.isEmpty ? profileName : businessName
        let content = ProBusinessCardContent(name: name, tagline: tagline)
        let palette = ProBusinessCardPalette(
            accentHex: accentHex,
            backgroundHex: "#FFFFFF",
            foregroundHex: "#111827"
        )

        var main = ProBusinessCardDesign(title: "Main card", template: .logoMark, content: content, updatedAt: Date())
        main.applyTemplateDefaults()

        var market = ProBusinessCardDesign(
            title: "Market stall",
            template: .qrFirst,
            palette: palette,
            content: content,
            updatedAt: Date()
        )
        market.applyTemplateDefaults()

        var social = ProBusinessCardDesign(
            title: "Social square",
            template: .gradientPro,
            aspect: .squareSocial,
            palette: ProBusinessCardPalette(accentHex: accentHex, backgroundHex: "#1E293B", foregroundHex: "#F8FAFC"),
            options: ProBusinessCardOptions(showsPhoto: false, showsLogo: true, showsQR: false, textAlignment: .center),
            content: content,
            updatedAt: Date()
        )
        social.applyTemplateDefaults()

        return [main, market, social]
    }

    public static func importFromSimpleCard(_ card: SimpleBusinessCard, title: String = "Imported card") -> ProBusinessCardDesign {
        var design = ProBusinessCardDesign(
            title: title,
            template: .logoMark,
            content: ProBusinessCardContent(
                name: card.name,
                tagline: card.tagline,
                phone: card.phone,
                email: card.email,
                skills: card.skills,
                photoPath: card.photoPath
            )
        )
        design.applyTemplateDefaults()
        if card.photoPath != nil {
            design.style.photoScale = .corner
            design.options.showsPhoto = true
            CardCanvasSync.applyTemplateReseed(to: &design)
        }
        return design
    }
}
