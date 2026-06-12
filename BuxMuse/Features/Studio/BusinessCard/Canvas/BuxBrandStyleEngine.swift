//
//  BuxBrandStyleEngine.swift
//  BuxMuse — brand-aware palette + geometric layout intelligence
//

import Foundation

enum BuxBrandStyleEngine {

    struct LayoutPack: Identifiable {
        let id: String
        let title: String
        let subtitle: String
        let shapes: [ShapeSpec]

        struct ShapeSpec {
            let name: String
            let type: CardShapeType
            let centerX: Double
            let centerY: Double
            let width: Double
            let height: Double
            let fillRole: FillRole
            let rotation: Double
            let useGradient: Bool

            enum FillRole { case accent, background, foreground, mutedAccent }
        }
    }

    static let layoutPacks: [LayoutPack] = [
        LayoutPack(
            id: "geo-card",
            title: "Geometric Card",
            subtitle: "Triangles + diamond accents",
            shapes: [
                .init(name: "Corner triangle", type: .triangleHalf, centerX: 0.12, centerY: 0.18, width: 0.22, height: 0.22, fillRole: .accent, rotation: 0, useGradient: false),
                .init(name: "Corner triangle", type: .triangleHalf, centerX: 0.88, centerY: 0.82, width: 0.2, height: 0.2, fillRole: .mutedAccent, rotation: 180, useGradient: false),
                .init(name: "Diamond", type: .diamond, centerX: 0.82, centerY: 0.22, width: 0.14, height: 0.14, fillRole: .accent, rotation: 15, useGradient: true),
            ]
        ),
        LayoutPack(
            id: "swiss-geo",
            title: "Swiss Grid",
            subtitle: "Half blocks + chevron",
            shapes: [
                .init(name: "Half block", type: .semicircle, centerX: 0.08, centerY: 0.5, width: 0.12, height: 0.5, fillRole: .accent, rotation: 0, useGradient: false),
                .init(name: "Chevron", type: .chevron, centerX: 0.92, centerY: 0.5, width: 0.1, height: 0.35, fillRole: .foreground, rotation: 0, useGradient: false),
                .init(name: "Bar", type: .accentBar, centerX: 0.5, centerY: 0.06, width: 0.55, height: 0.035, fillRole: .accent, rotation: 0, useGradient: false),
            ]
        ),
        LayoutPack(
            id: "creative-blobs",
            title: "Creative Stack",
            subtitle: "Parallelogram + quarter circle",
            shapes: [
                .init(name: "Slant block", type: .parallelogram, centerX: 0.78, centerY: 0.68, width: 0.38, height: 0.28, fillRole: .accent, rotation: 0, useGradient: true),
                .init(name: "Quarter arc", type: .quarterCircle, centerX: 0.15, centerY: 0.85, width: 0.28, height: 0.28, fillRole: .mutedAccent, rotation: 0, useGradient: false),
                .init(name: "Hex seal", type: .hexagon, centerX: 0.88, centerY: 0.15, width: 0.12, height: 0.12, fillRole: .accent, rotation: 30, useGradient: false),
            ]
        ),
        LayoutPack(
            id: "trade-bold",
            title: "Trade Bold",
            subtitle: "Strong bars + triangle",
            shapes: [
                .init(name: "Side bar", type: .accentBar, centerX: 0.03, centerY: 0.5, width: 0.045, height: 0.92, fillRole: .accent, rotation: 0, useGradient: false),
                .init(name: "Top triangle", type: .triangle, centerX: 0.72, centerY: 0.12, width: 0.18, height: 0.12, fillRole: .accent, rotation: 0, useGradient: true),
            ]
        ),
    ]

    static func suggestedPalettes(for design: ProBusinessCardDesign) -> [(name: String, palette: ProBusinessCardPalette)] {
        var result = ProBusinessCardPalette.presets
        let accent = design.palette.accentHex
        if !result.contains(where: { $0.palette.accentHex == accent }) {
            result.insert(("Your brand", design.palette), at: 0)
        }
        return result
    }

    static func applyLayoutPack(_ pack: LayoutPack, to document: inout CardCanvasDocument, palette: ProBusinessCardPalette) {
        for spec in pack.shapes {
            let layer = CardCanvasLayer(
                name: spec.name,
                kind: .shape,
                transform: CardLayerTransform(
                    centerX: spec.centerX,
                    centerY: spec.centerY,
                    width: spec.width,
                    height: spec.height,
                    rotation: spec.rotation
                ),
                opacity: spec.fillRole == .mutedAccent ? 0.42 : 1,
                payload: .shape(CardShapePayload(
                    shapeType: spec.type,
                    fillHex: hex(for: spec.fillRole, palette: palette),
                    useGradient: spec.useGradient
                ))
            )
            document.layers.append(layer)
        }
        document.markCustomized()
    }

    static func hex(for role: LayoutPack.ShapeSpec.FillRole, palette: ProBusinessCardPalette) -> String {
        switch role {
        case .accent, .mutedAccent: return palette.accentHex
        case .background: return palette.backgroundHex
        case .foreground: return palette.foregroundHex
        }
    }
}
