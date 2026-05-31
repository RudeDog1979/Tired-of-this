//
//  CardCanvasModels.swift
//  BuxMuse
//
//  Pro Canvas layer document — every card element is an editable layer.
//

import CoreGraphics
import Foundation

// MARK: - Document

public struct CardCanvasDocument: Codable, Equatable, Sendable {
    public static let schemaVersion = 1

    public var version: Int
    public var canvasWidth: Double
    public var canvasHeight: Double
    public var safeInsetRatio: Double
    public var background: CardBackgroundSpec
    public var layers: [CardCanvasLayer]
    public var templateID: String?
    public var isCustomized: Bool

    public init(
        version: Int = CardCanvasDocument.schemaVersion,
        canvasWidth: Double,
        canvasHeight: Double,
        safeInsetRatio: Double = 0.07,
        background: CardBackgroundSpec = CardBackgroundSpec(),
        layers: [CardCanvasLayer] = [],
        templateID: String? = nil,
        isCustomized: Bool = false
    ) {
        self.version = version
        self.canvasWidth = canvasWidth
        self.canvasHeight = canvasHeight
        self.safeInsetRatio = safeInsetRatio
        self.background = background
        self.layers = layers
        self.templateID = templateID
        self.isCustomized = isCustomized
    }

    public var canvasSize: CGSize {
        CGSize(width: canvasWidth, height: canvasHeight)
    }

    public mutating func markCustomized() { isCustomized = true }

    public func layer(id: UUID) -> CardCanvasLayer? {
        layers.first { $0.id == id }
    }

    public mutating func updateLayer(_ layer: CardCanvasLayer) {
        guard let idx = layers.firstIndex(where: { $0.id == layer.id }) else { return }
        layers[idx] = layer
    }

    public mutating func removeLayer(id: UUID) {
        layers.removeAll { $0.id == id }
    }

    public mutating func bringForward(id: UUID) {
        guard let idx = layers.firstIndex(where: { $0.id == id }), idx < layers.count - 1 else { return }
        layers.swapAt(idx, idx + 1)
    }

    public mutating func sendBackward(id: UUID) {
        guard let idx = layers.firstIndex(where: { $0.id == id }), idx > 0 else { return }
        layers.swapAt(idx, idx - 1)
    }

    public mutating func bringToFront(id: UUID) {
        guard let idx = layers.firstIndex(where: { $0.id == id }) else { return }
        let layer = layers.remove(at: idx)
        layers.append(layer)
    }

    public mutating func sendToBack(id: UUID) {
        guard let idx = layers.firstIndex(where: { $0.id == id }) else { return }
        let layer = layers.remove(at: idx)
        layers.insert(layer, at: 0)
    }

    public mutating func duplicateLayer(id: UUID) -> UUID? {
        guard let source = layer(id: id) else { return nil }
        var copy = source
        copy.id = UUID()
        copy.name = "\(source.name) copy"
        copy.transform.centerX += 0.02
        copy.transform.centerY += 0.02
        layers.append(copy)
        return copy.id
    }
}

// MARK: - Layer

public struct CardCanvasLayer: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var kind: CardLayerKind
    public var transform: CardLayerTransform
    public var isLocked: Bool
    public var isHidden: Bool
    public var opacity: Double
    public var effects: CardLayerEffects
    public var payload: CardLayerPayload

    public init(
        id: UUID = UUID(),
        name: String,
        kind: CardLayerKind,
        transform: CardLayerTransform,
        isLocked: Bool = false,
        isHidden: Bool = false,
        opacity: Double = 1,
        effects: CardLayerEffects = CardLayerEffects(),
        payload: CardLayerPayload
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.transform = transform
        self.isLocked = isLocked
        self.isHidden = isHidden
        self.opacity = opacity
        self.effects = effects
        self.payload = payload
    }
}

public enum CardLayerKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case text, image, qr, shape, watermark

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .text: return "Text"
        case .image: return "Image"
        case .qr: return "QR"
        case .shape: return "Shape"
        case .watermark: return "Watermark"
        }
    }
}

public struct CardLayerTransform: Codable, Equatable, Sendable {
    public var centerX: Double
    public var centerY: Double
    public var width: Double
    public var height: Double
    public var rotation: Double
    public var scale: Double

    public init(
        centerX: Double = 0.5,
        centerY: Double = 0.5,
        width: Double = 0.4,
        height: Double = 0.1,
        rotation: Double = 0,
        scale: Double = 1
    ) {
        self.centerX = centerX
        self.centerY = centerY
        self.width = width
        self.height = height
        self.rotation = rotation
        self.scale = scale
    }

    public func frame(in canvasSize: CGSize) -> CGRect {
        let w = max(1, width * canvasSize.width * scale)
        let h = max(1, height * canvasSize.height * scale)
        let cx = centerX * canvasSize.width
        let cy = centerY * canvasSize.height
        return CGRect(x: cx - w / 2, y: cy - h / 2, width: w, height: h)
    }

    public mutating func translate(normalizedDX: Double, normalizedDY: Double) {
        centerX = min(1, max(0, centerX + normalizedDX))
        centerY = min(1, max(0, centerY + normalizedDY))
    }
}

public struct CardLayerEffects: Codable, Equatable, Sendable {
    public var shadowColorHex: String?
    public var shadowRadius: Double
    public var shadowOffsetX: Double
    public var shadowOffsetY: Double
    public var blendMode: String

    public init(
        shadowColorHex: String? = nil,
        shadowRadius: Double = 0,
        shadowOffsetX: Double = 0,
        shadowOffsetY: Double = 0,
        blendMode: String = "normal"
    ) {
        self.shadowColorHex = shadowColorHex
        self.shadowRadius = shadowRadius
        self.shadowOffsetX = shadowOffsetX
        self.shadowOffsetY = shadowOffsetY
        self.blendMode = blendMode
    }
}

// MARK: - Payload

public enum CardLayerPayload: Codable, Equatable, Sendable {
    case text(CardTextPayload)
    case image(CardImagePayload)
    case qr(CardQRPayload)
    case shape(CardShapePayload)
    case watermark(CardWatermarkPayload)
}

public enum CardTextContentBinding: String, Codable, CaseIterable, Sendable {
    case none, name, tagline, phone, email, website, skills
}

public struct CardTextPayload: Codable, Equatable, Sendable {
    public var text: String
    public var binding: CardTextContentBinding
    public var style: CardTextStyle

    public init(text: String, binding: CardTextContentBinding = .none, style: CardTextStyle = CardTextStyle()) {
        self.text = text
        self.binding = binding
        self.style = style
    }
}

public struct CardTextStyle: Codable, Equatable, Sendable {
    public var fontID: String
    public var fontSize: Double
    public var colorHex: String
    public var alignment: String
    public var lineSpacing: Double
    public var letterSpacing: Double
    public var isBold: Bool
    public var isItalic: Bool
    public var isUnderline: Bool
    public var effectPreset: CardTextEffectPreset
    public var outlineColorHex: String?
    public var outlineWidth: Double
    public var backgroundColorHex: String?

    public init(
        fontID: String = "modernRounded",
        fontSize: Double = 18,
        colorHex: String = "#111827",
        alignment: String = "leading",
        lineSpacing: Double = 1,
        letterSpacing: Double = 0,
        isBold: Bool = true,
        isItalic: Bool = false,
        isUnderline: Bool = false,
        effectPreset: CardTextEffectPreset = .none,
        outlineColorHex: String? = nil,
        outlineWidth: Double = 0,
        backgroundColorHex: String? = nil
    ) {
        self.fontID = fontID
        self.fontSize = fontSize
        self.colorHex = colorHex
        self.alignment = alignment
        self.lineSpacing = lineSpacing
        self.letterSpacing = letterSpacing
        self.isBold = isBold
        self.isItalic = isItalic
        self.isUnderline = isUnderline
        self.effectPreset = effectPreset
        self.outlineColorHex = outlineColorHex
        self.outlineWidth = outlineWidth
        self.backgroundColorHex = backgroundColorHex
    }
}

public enum CardTextEffectPreset: String, Codable, CaseIterable, Identifiable, Sendable {
    case none, longShadow, emboss, outline, neon, letterpress, retro3D, glow, stack, classic

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .none: return "None"
        case .longShadow: return "Long Shadow"
        case .emboss: return "Emboss"
        case .outline: return "Outline"
        case .neon: return "Neon"
        case .letterpress: return "Letterpress"
        case .retro3D: return "Retro 3D"
        case .glow: return "Glow"
        case .stack: return "Stack"
        case .classic: return "Classic"
        }
    }
}

public enum CardImageSource: Codable, Equatable, Sendable {
    case profilePhoto
    case profileLogo
    case assetPath(String)
}

public struct CardImagePayload: Codable, Equatable, Sendable {
    public var source: CardImageSource
    public var assetPath: String?
    public var mask: CardImageMask
    public var cornerRadius: Double
    public var adjustments: ProBusinessCardPhotoAdjustments
    public var borderColorHex: String?
    public var borderWidth: Double
    public var flipHorizontal: Bool
    public var flipVertical: Bool
    public var photoTransform: ProBusinessCardPhotoTransform

    public init(
        source: CardImageSource,
        assetPath: String? = nil,
        mask: CardImageMask = .circle,
        cornerRadius: Double = 0,
        adjustments: ProBusinessCardPhotoAdjustments = ProBusinessCardPhotoAdjustments(),
        borderColorHex: String? = nil,
        borderWidth: Double = 0,
        flipHorizontal: Bool = false,
        flipVertical: Bool = false,
        photoTransform: ProBusinessCardPhotoTransform = ProBusinessCardPhotoTransform()
    ) {
        self.source = source
        self.assetPath = assetPath
        self.mask = mask
        self.cornerRadius = cornerRadius
        self.adjustments = adjustments
        self.borderColorHex = borderColorHex
        self.borderWidth = borderWidth
        self.flipHorizontal = flipHorizontal
        self.flipVertical = flipVertical
        self.photoTransform = photoTransform
    }
}

public enum CardImageMask: String, Codable, CaseIterable, Sendable {
    case none, circle, roundedRect
}

public struct CardQRPayload: Codable, Equatable, Sendable {
    public var foregroundHex: String
    public var backgroundHex: String
    public var cornerRadius: Double

    public init(foregroundHex: String = "#000000", backgroundHex: String = "#FFFFFF", cornerRadius: Double = 5) {
        self.foregroundHex = foregroundHex
        self.backgroundHex = backgroundHex
        self.cornerRadius = cornerRadius
    }
}

public enum CardShapeType: String, Codable, CaseIterable, Identifiable, Sendable {
    case rectangle, circle, line, star, badge, accentBar, symbol
    case triangle, triangleHalf, diamond, hexagon, quarterCircle, parallelogram, chevron, semicircle

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .rectangle: return "Rectangle"
        case .circle: return "Circle"
        case .line: return "Line"
        case .star: return "Star"
        case .badge: return "Badge"
        case .accentBar: return "Accent Bar"
        case .symbol: return "Symbol"
        case .triangle: return "Triangle"
        case .triangleHalf: return "Half Block"
        case .diamond: return "Diamond"
        case .hexagon: return "Hexagon"
        case .quarterCircle: return "Quarter Arc"
        case .parallelogram: return "Parallelogram"
        case .chevron: return "Chevron"
        case .semicircle: return "Semicircle"
        }
    }

    public static var geometricShapes: [CardShapeType] {
        [.triangle, .triangleHalf, .diamond, .hexagon, .quarterCircle, .parallelogram, .chevron, .semicircle]
    }

    public static var basicShapes: [CardShapeType] {
        [.rectangle, .circle, .line, .star, .accentBar, .diamond]
    }
}

public struct CardShapePayload: Codable, Equatable, Sendable {
    public var shapeType: CardShapeType
    public var fillHex: String
    public var strokeHex: String?
    public var strokeWidth: Double
    public var cornerRadius: Double
    public var symbolName: String?
    public var useGradient: Bool

    public init(
        shapeType: CardShapeType,
        fillHex: String,
        strokeHex: String? = nil,
        strokeWidth: Double = 0,
        cornerRadius: Double = 8,
        symbolName: String? = nil,
        useGradient: Bool = false
    ) {
        self.shapeType = shapeType
        self.fillHex = fillHex
        self.strokeHex = strokeHex
        self.strokeWidth = strokeWidth
        self.cornerRadius = cornerRadius
        self.symbolName = symbolName
        self.useGradient = useGradient
    }
}

public struct CardWatermarkPayload: Codable, Equatable, Sendable {
    public var text: String
    public var fontID: String
    public var colorHex: String
    public var binding: CardTextContentBinding

    public init(text: String, fontID: String = "modernRounded", colorHex: String = "#111827", binding: CardTextContentBinding = .name) {
        self.text = text
        self.fontID = fontID
        self.colorHex = colorHex
        self.binding = binding
    }
}

// MARK: - Background

public struct CardBackgroundSpec: Codable, Equatable, Sendable {
    public var style: ProBusinessCardBackgroundStyle
    public var solidHex: String
    public var accentHex: String
    public var photoPath: String?
    public var photoOpacity: Double
    public var photoBlur: Double
    public var overlayHex: String?
    public var overlayOpacity: Double
    public var saturation: Double
    public var brightness: Double
    public var photoTransform: ProBusinessCardPhotoTransform

    public init(
        style: ProBusinessCardBackgroundStyle = .solid,
        solidHex: String = "#FFFFFF",
        accentHex: String = "#5A55F5",
        photoPath: String? = nil,
        photoOpacity: Double = 1,
        photoBlur: Double = 0,
        overlayHex: String? = nil,
        overlayOpacity: Double = 0,
        saturation: Double = 1,
        brightness: Double = 0,
        photoTransform: ProBusinessCardPhotoTransform = ProBusinessCardPhotoTransform()
    ) {
        self.style = style
        self.solidHex = solidHex
        self.accentHex = accentHex
        self.photoPath = photoPath
        self.photoOpacity = photoOpacity
        self.photoBlur = photoBlur
        self.overlayHex = overlayHex
        self.overlayOpacity = overlayOpacity
        self.saturation = saturation
        self.brightness = brightness
        self.photoTransform = photoTransform
    }
}

public struct CardEditorPreferences: Codable, Equatable, Sendable {
    public var showSafeZone: Bool
    public var showSnapGuides: Bool
    public var showGrid: Bool

    public init(showSafeZone: Bool = true, showSnapGuides: Bool = true, showGrid: Bool = false) {
        self.showSafeZone = showSafeZone
        self.showSnapGuides = showSnapGuides
        self.showGrid = showGrid
    }
}

// MARK: - BuxMuse proprietary aliases (Bux-prefixed public surface)

public typealias BuxCanvasDocument = CardCanvasDocument
public typealias BuxCanvasLayer = CardCanvasLayer
public typealias BuxCanvasToolbarActions = BuxCanvasToolbarActionSet

public struct BuxCanvasToolbarActionSet {
    var onOpenPhotoLab: ((UUID) -> Void)?
    var onOpenFocalEditor: ((BuxFocalEditorTarget) -> Void)?
    var onOpenBackgroundEditor: (() -> Void)?
    var onLayerDuplicated: ((UUID) -> Void)?
    var onLayerDeleted: (() -> Void)?
}

public enum BuxFocalEditorTarget: Equatable {
    case background
    case imageLayer(UUID)
}
