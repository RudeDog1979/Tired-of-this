//
//  BrandVisualPack.swift
//  BuxMuse
//
//  Extracts card canvas visuals for invoice header sync (additive to template motifs).
//

import Foundation

// MARK: - Stamps

public struct BrandShapeStamp: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var shapeType: CardShapeType
    public var centerX: Double
    public var centerY: Double
    public var width: Double
    public var height: Double
    public var rotation: Double
    public var scale: Double
    public var opacity: Double
    public var fillHex: String
    public var strokeHex: String?
    public var strokeWidth: Double
    public var cornerRadius: Double
    public var useGradient: Bool

    public init(
        id: UUID = UUID(),
        shapeType: CardShapeType,
        centerX: Double,
        centerY: Double,
        width: Double,
        height: Double,
        rotation: Double = 0,
        scale: Double = 1,
        opacity: Double = 1,
        fillHex: String,
        strokeHex: String? = nil,
        strokeWidth: Double = 0,
        cornerRadius: Double = 8,
        useGradient: Bool = false
    ) {
        self.id = id
        self.shapeType = shapeType
        self.centerX = centerX
        self.centerY = centerY
        self.width = width
        self.height = height
        self.rotation = rotation
        self.scale = scale
        self.opacity = opacity
        self.fillHex = fillHex
        self.strokeHex = strokeHex
        self.strokeWidth = strokeWidth
        self.cornerRadius = cornerRadius
        self.useGradient = useGradient
    }
}

public struct BrandVisualPack: Codable, Equatable, Sendable {
    public var accentHex: String
    public var foregroundHex: String
    public var backgroundHex: String
    public var background: CardBackgroundSpec
    public var headerStamps: [BrandShapeStamp]
    public var fingerprint: String

    public init(
        accentHex: String,
        foregroundHex: String,
        backgroundHex: String,
        background: CardBackgroundSpec,
        headerStamps: [BrandShapeStamp],
        fingerprint: String
    ) {
        self.accentHex = accentHex
        self.foregroundHex = foregroundHex
        self.backgroundHex = backgroundHex
        self.background = background
        self.headerStamps = headerStamps
        self.fingerprint = fingerprint
    }
}

// MARK: - Extractor

enum BrandVisualPackExtractor {

    /// Upper card fraction mapped into invoice header band height.
    static let headerBandCardHeight = 0.42
    private static let headerZoneMaxY = 0.48
    private static let maxStamps = 8

    static func extract(from design: ProBusinessCardDesign) -> BrandVisualPack {
        let doc = design.canvasDocument ?? CardCanvasMigrator.migrate(from: design)
        let stamps = headerStamps(from: doc)
        let fingerprint = makeFingerprint(design: design, doc: doc, stamps: stamps)
        return BrandVisualPack(
            accentHex: design.palette.accentHex,
            foregroundHex: design.palette.foregroundHex,
            backgroundHex: design.palette.backgroundHex,
            background: doc.background,
            headerStamps: stamps,
            fingerprint: fingerprint
        )
    }

    static func makeFingerprint(design: ProBusinessCardDesign) -> String {
        let doc = design.canvasDocument ?? CardCanvasMigrator.migrate(from: design)
        return makeFingerprint(design: design, doc: doc, stamps: headerStamps(from: doc))
    }

    private static func headerStamps(from doc: CardCanvasDocument) -> [BrandShapeStamp] {
        let shapes = doc.layers.filter { $0.kind == .shape && !$0.isHidden }
        let candidates = shapes.filter { qualifiesForHeader($0) }
        let picked = (candidates.isEmpty ? shapes : candidates).suffix(maxStamps)
        return picked.map { stamp(from: $0) }
    }

    private static func qualifiesForHeader(_ layer: CardCanvasLayer) -> Bool {
        let t = layer.transform
        if t.centerY <= headerZoneMaxY { return true }
        if t.width < 0.12 && t.height > 0.55 { return true }
        if case .shape(let p) = layer.payload,
           p.shapeType == .accentBar || p.shapeType == .line { return true }
        return false
    }

    private static func stamp(from layer: CardCanvasLayer) -> BrandShapeStamp {
        let payload: CardShapePayload = {
            if case .shape(let p) = layer.payload { return p }
            return CardShapePayload(shapeType: .rectangle, fillHex: "#5A55F5")
        }()
        return BrandShapeStamp(
            id: layer.id,
            shapeType: payload.shapeType,
            centerX: layer.transform.centerX,
            centerY: layer.transform.centerY,
            width: layer.transform.width,
            height: layer.transform.height,
            rotation: layer.transform.rotation,
            scale: layer.transform.scale,
            opacity: layer.opacity,
            fillHex: payload.fillHex,
            strokeHex: payload.strokeHex,
            strokeWidth: payload.strokeWidth,
            cornerRadius: payload.cornerRadius,
            useGradient: payload.useGradient
        )
    }

    private static func makeFingerprint(
        design: ProBusinessCardDesign,
        doc: CardCanvasDocument,
        stamps: [BrandShapeStamp]
    ) -> String {
        let stampSig = stamps.map {
            "\($0.shapeType.rawValue):\(Int($0.centerX * 1000)):\(Int($0.centerY * 1000)):\($0.fillHex):\(Int($0.rotation))"
        }.joined(separator: "|")
        let bg = "\(doc.background.style.rawValue):\(doc.background.solidHex):\(doc.background.photoPath ?? "")"
        return "\(design.template.rawValue);\(design.palette.accentHex);\(bg);\(stampSig);\(doc.isCustomized)"
    }
}
