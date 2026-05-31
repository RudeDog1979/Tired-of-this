//
//  CardCanvasSync.swift
//  BuxMuse
//
//  Syncs Quick Studio content ↔ canvas layers.
//

import Foundation

enum CardCanvasSync {

    /// Ensures a canvas document exists and structural/content bindings are current.
    static func ensureDocument(on design: inout ProBusinessCardDesign) {
        if design.canvasDocument == nil {
            design.canvasDocument = CardCanvasMigrator.migrate(from: design)
        }
        applyContentBindings(to: &design)
        reconcileStructure(to: &design)
    }

    /// Push Quick Studio palette / background / typography into canvas (does not stomp customized text fonts).
    static func pushQuickStudioVisuals(to design: inout ProBusinessCardDesign) {
        guard var doc = design.canvasDocument else { return }
        let palette = design.palette
        let typo = design.style.typography

        doc.background.style = design.style.backgroundStyle
        doc.background.solidHex = palette.backgroundHex
        doc.background.accentHex = palette.accentHex
        doc.background.photoPath = design.style.backgroundPhotoPath
        doc.background.photoOpacity = design.style.backgroundPhotoOpacity
        doc.background.photoTransform = design.style.photoTransform

        for idx in doc.layers.indices {
            switch doc.layers[idx].payload {
            case .text(var payload):
                payload.style.colorHex = palette.foregroundHex
                payload.style.fontID = typo.fontID
                if payload.binding == .name {
                    payload.style.fontSize = 20 * typo.nameScale
                    payload.style.isBold = true
                    doc.layers[idx].transform.scale = typo.nameScale
                }
                if payload.binding == .tagline {
                    payload.style.fontSize = 11 * typo.taglineScale
                    doc.layers[idx].transform.scale = typo.taglineScale
                }
                doc.layers[idx].payload = .text(payload)

            case .shape(var payload) where doc.layers[idx].isLocked:
                CardCanvasSync.applyPalette(to: &payload, layerName: doc.layers[idx].name, palette: palette)
                doc.layers[idx].payload = .shape(payload)

            case .watermark(var wp):
                wp.fontID = typo.fontID
                wp.colorHex = palette.foregroundHex
                doc.layers[idx].payload = .watermark(wp)

            case .image(var payload) where payload.source == .profilePhoto:
                payload.adjustments = design.style.photoAdjustments
                payload.mask = design.style.photoPlacement.isStrip ? .none : design.style.photoMask
                payload.photoTransform = design.style.photoTransform
                doc.layers[idx].payload = .image(payload)

            case .image(var payload) where payload.source == .profileLogo:
                payload.mask = design.style.logoMask
                payload.cornerRadius = design.style.logoCornerRadius
                doc.layers[idx].payload = .image(payload)

            case .qr(var qr):
                qr.foregroundHex = palette.foregroundHex
                qr.backgroundHex = palette.backgroundHex
                doc.layers[idx].payload = .qr(qr)

            default:
                break
            }
        }

        design.canvasDocument = doc
    }

    /// Ensures studio business logo appears on the canvas when profile logo exists.
    static func syncLogoFromStudio(to design: inout ProBusinessCardDesign, logoData: Data?) {
        guard logoData != nil else { return }
        design.options.showsLogo = true
        ensureDocument(on: &design)
        reconcileStructure(to: &design)
    }

    static func applyContentBindings(to design: inout ProBusinessCardDesign) {
        guard var doc = design.canvasDocument else { return }
        for idx in doc.layers.indices {
            switch doc.layers[idx].payload {
            case .text(var payload):
                if let text = boundText(for: payload.binding, design: design) {
                    payload.text = text
                    doc.layers[idx].payload = .text(payload)
                }
            case .watermark(var wp):
                if let text = boundText(for: wp.binding, design: design) {
                    wp.text = text
                    doc.layers[idx].payload = .watermark(wp)
                }
            default:
                break
            }
        }
        design.canvasDocument = doc
    }

    static func reconcileStructure(to design: inout ProBusinessCardDesign) {
        guard var doc = design.canvasDocument else { return }

        setLayerPresence(
            in: &doc,
            kind: .image,
            name: "Logo",
            present: design.options.showsLogo,
            factory: { CardCanvasMigrator.migrate(from: design).layers.first(where: { $0.name == "Logo" }) }
        )
        setLayerPresence(
            in: &doc,
            kind: .image,
            name: "Photo",
            present: design.options.showsPhoto && design.style.photoScale != .off,
            factory: { CardCanvasMigrator.migrate(from: design).layers.first(where: { $0.name == "Photo" }) }
        )
        setLayerPresence(
            in: &doc,
            kind: .qr,
            name: "QR Code",
            present: design.options.showsQR,
            factory: { CardCanvasMigrator.migrate(from: design).layers.first(where: { $0.kind == .qr }) }
        )

        if !design.style.watermark.isEnabled {
            doc.layers.removeAll { $0.kind == .watermark }
        } else if !doc.layers.contains(where: { $0.kind == .watermark }) {
            if let wm = CardCanvasMigrator.migrate(from: design).layers.first(where: { $0.kind == .watermark }) {
                doc.layers.append(wm)
            }
        }

        design.canvasDocument = doc
    }

    private static func setLayerPresence(
        in doc: inout CardCanvasDocument,
        kind: CardLayerKind,
        name: String,
        present: Bool,
        factory: () -> CardCanvasLayer?
    ) {
        let has = doc.layers.contains { $0.kind == kind && ($0.name == name || kind == .qr) }
        if present, !has, let layer = factory() {
            doc.layers.append(layer)
        } else if !present {
            doc.layers.removeAll { $0.kind == kind && ($0.name == name || kind == .qr) }
        }
    }

    static func boundText(for binding: CardTextContentBinding, design: ProBusinessCardDesign) -> String? {
        switch binding {
        case .none: return nil
        case .name: return design.content.name
        case .tagline: return design.content.tagline
        case .phone: return design.content.phone
        case .email: return design.content.email
        case .website: return design.content.website
        case .skills: return design.content.skills
        }
    }

    static func syncLegacyStyle(from design: ProBusinessCardDesign) -> ProBusinessCardDesign {
        var copy = design
        guard let doc = design.canvasDocument else { return copy }

        copy.style.backgroundStyle = doc.background.style
        copy.style.backgroundPhotoPath = doc.background.photoPath
        copy.style.backgroundPhotoOpacity = doc.background.photoOpacity
        copy.style.photoTransform = doc.background.photoTransform
        copy.palette.backgroundHex = doc.background.solidHex
        copy.palette.accentHex = doc.background.accentHex

        for layer in doc.layers {
            switch layer.payload {
            case .text(let payload):
                copy.style.typography.fontID = payload.style.fontID
                if payload.binding == .name {
                    copy.style.typography.nameScale = layer.transform.scale
                    copy.style.nameCanvas = legacyCanvas(from: layer.transform)
                }
                if payload.binding == .tagline {
                    copy.style.typography.taglineScale = layer.transform.scale
                }

            case .image(let img) where img.source == .profilePhoto:
                copy.style.photoCanvas = legacyCanvas(from: layer.transform)
                copy.options.showsPhoto = true
                copy.style.photoAdjustments = img.adjustments
                copy.style.photoTransform = img.photoTransform
                copy.style.photoMask = img.mask

            case .image(let img) where img.source == .profileLogo:
                copy.style.logoCanvas = legacyCanvas(from: layer.transform)
                copy.options.showsLogo = true
                copy.style.logoMask = img.mask
                copy.style.logoCornerRadius = img.cornerRadius

            case .qr:
                copy.style.qrCanvas = legacyCanvas(from: layer.transform)
                copy.options.showsQR = true

            case .watermark(let wm):
                copy.style.watermark.isEnabled = true
                copy.style.watermark.text = wm.text
                copy.style.watermark.normalizedX = layer.transform.centerX
                copy.style.watermark.normalizedY = layer.transform.centerY
                copy.style.watermark.rotation = layer.transform.rotation
                copy.style.watermark.scale = layer.transform.scale
                copy.style.watermark.opacity = layer.opacity

            default:
                break
            }
        }
        return copy
    }

    private static func legacyCanvas(from t: CardLayerTransform) -> ProBusinessCardCanvasLayer {
        ProBusinessCardCanvasLayer(
            normalizedX: t.centerX,
            normalizedY: t.centerY,
            scale: t.scale,
            rotation: t.rotation
        )
    }

    static func applyTemplateReseed(to design: inout ProBusinessCardDesign) {
        design.canvasDocument = CardCanvasMigrator.migrate(from: design)
        design.canvasDocument?.isCustomized = false
    }

    /// Recompute logo/photo/text layout after identity mode changes without wiping template shapes.
    static func applyIdentityLayout(to design: inout ProBusinessCardDesign) {
        ensureDocument(on: &design)
        reconcileStructure(to: &design)

        let fresh = CardCanvasMigrator.migrate(from: design)
        guard var doc = design.canvasDocument else { return }

        func syncTransform(named name: String, kind: CardLayerKind) {
            guard let freshLayer = fresh.layers.first(where: { $0.name == name && $0.kind == kind }),
                  let idx = doc.layers.firstIndex(where: { $0.name == name && $0.kind == kind }) else { return }
            doc.layers[idx].transform = freshLayer.transform
            if kind == .image {
                doc.layers[idx].payload = freshLayer.payload
            }
        }

        syncTransform(named: "Logo", kind: .image)
        syncTransform(named: "Photo", kind: .image)

        for label in ["Name", "Tagline", "Contact", "Website", "Skills"] {
            guard let freshLayer = fresh.layers.first(where: { $0.name == label }),
                  let idx = doc.layers.firstIndex(where: { $0.name == label }) else { continue }
            doc.layers[idx].transform = freshLayer.transform
        }

        design.canvasDocument = doc
        pushQuickStudioVisuals(to: &design)
    }

    /// Maps template shape fills/strokes to the three editable palette slots.
    static func applyPalette(to payload: inout CardShapePayload, layerName: String, palette: ProBusinessCardPalette) {
        let fillRole = payload.paletteRole ?? inferFillRole(layerName: layerName, fillHex: payload.fillHex, palette: palette)
        if payload.fillHex.uppercased() != "#00000000" {
            payload.fillHex = paletteHex(for: fillRole, palette: palette)
        }
        if payload.strokeHex != nil {
            let strokeRole = payload.strokePaletteRole ?? .accent
            payload.strokeHex = paletteHex(for: strokeRole, palette: palette)
        }
    }

    static func paletteHex(for role: CardShapePaletteRole, palette: ProBusinessCardPalette) -> String {
        switch role {
        case .accent: return palette.accentHex
        case .foreground: return palette.foregroundHex
        case .background: return palette.backgroundHex
        case .surface: return "#FFFFFF"
        }
    }

    private static func inferFillRole(
        layerName: String,
        fillHex: String,
        palette: ProBusinessCardPalette
    ) -> CardShapePaletteRole {
        let name = layerName.lowercased()
        if fillHex.uppercased() == "#FFFFFF" || name.contains("frost") { return .surface }
        if fillHex.caseInsensitiveCompare(palette.foregroundHex) == .orderedSame { return .foreground }
        if fillHex.caseInsensitiveCompare(palette.backgroundHex) == .orderedSame { return .background }
        if name.contains("grid") || name.contains("rule") || name.contains("tick")
            || name.contains("chevron") || name.contains("cross") || name.contains("line 2")
            || name.contains("line 3") {
            return .foreground
        }
        return .accent
    }
}
