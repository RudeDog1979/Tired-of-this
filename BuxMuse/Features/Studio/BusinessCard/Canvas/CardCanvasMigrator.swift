//
//  CardCanvasMigrator.swift
//  BuxMuse
//
//  Migrates legacy ProBusinessCardDesign → CardCanvasDocument.
//

import CoreGraphics
import Foundation

enum CardCanvasMigrator {

    static func migrate(from design: ProBusinessCardDesign) -> CardCanvasDocument {
        let size = design.aspect.previewSize
        var doc = CardCanvasDocument(
            canvasWidth: Double(size.width),
            canvasHeight: Double(size.height),
            safeInsetRatio: design.aspect.safeInsetRatio,
            background: background(from: design),
            templateID: design.template.rawValue
        )

        var layers: [CardCanvasLayer] = []
        layers.append(contentsOf: templateShapeLayers(from: design, canvasSize: size))
        layers.append(contentsOf: imageLayers(from: design, canvasSize: size))
        layers.append(contentsOf: textLayers(from: design, canvasSize: size))
        if design.options.showsQR { layers.append(qrLayer(from: design, canvasSize: size)) }
        if design.style.watermark.isEnabled { layers.append(watermarkLayer(from: design)) }

        doc.layers = layers
        return doc
    }

    // MARK: - Background

    private static func background(from design: ProBusinessCardDesign) -> CardBackgroundSpec {
        CardBackgroundSpec(
            style: design.style.backgroundStyle,
            solidHex: design.palette.backgroundHex,
            accentHex: design.palette.accentHex,
            photoPath: design.style.backgroundPhotoPath,
            photoOpacity: design.style.backgroundPhotoOpacity,
            photoTransform: ProBusinessCardPhotoTransform()
        )
    }

    // MARK: - Shapes

    private static func templateShapeLayers(from design: ProBusinessCardDesign, canvasSize: CGSize) -> [CardCanvasLayer] {
        ProBusinessCardTemplatePresets.shapeLayers(for: design, canvasSize: canvasSize)
    }

    // MARK: - Images

    private static func imageLayers(from design: ProBusinessCardDesign, canvasSize: CGSize) -> [CardCanvasLayer] {
        var layers: [CardCanvasLayer] = []

        if design.options.showsLogo {
            let t = logoTransform(from: design, canvasSize: canvasSize)
            layers.append(CardCanvasLayer(
                name: "Logo",
                kind: .image,
                transform: t,
                payload: .image(CardImagePayload(
                    source: .profileLogo,
                    mask: design.style.logoMask,
                    cornerRadius: design.style.logoCornerRadius
                ))
            ))
        }

        if design.options.showsPhoto, design.style.photoScale != .off {
            let t = photoTransform(from: design, canvasSize: canvasSize)
            layers.append(CardCanvasLayer(
                name: "Photo",
                kind: .image,
                transform: t,
                payload: .image(CardImagePayload(
                    source: .profilePhoto,
                    assetPath: design.content.photoPath,
                    mask: design.style.photoPlacement.isStrip ? .none : design.style.photoMask,
                    adjustments: design.style.photoAdjustments,
                    photoTransform: design.style.photoTransform
                ))
            ))
        }

        return layers
    }

    private static func logoTransform(from design: ProBusinessCardDesign, canvasSize: CGSize) -> CardLayerTransform {
        if let c = design.style.logoCanvas {
            return CardLayerTransform(
                centerX: c.normalizedX, centerY: c.normalizedY,
                width: design.style.logoScale.pointRatio * 1.1,
                height: design.style.logoScale.pointRatio * 1.1,
                rotation: c.rotation, scale: c.scale
            )
        }
        let layout = ProBusinessCardTemplatePresets.layout(for: design)
        let scale = layout.logoScale ?? design.style.logoScale
        let s = Double(scale.pointRatio)
        if let pos = layout.logoCenter {
            return CardLayerTransform(centerX: pos.x, centerY: pos.y, width: s * 1.1, height: s * 1.1)
        }
        let inset = canvasSize.height * design.aspect.safeInsetRatio
        return CardLayerTransform(
            centerX: Double((inset + CGFloat(s) * canvasSize.width * 0.5) / canvasSize.width),
            centerY: Double((inset + CGFloat(s) * canvasSize.height * 0.5) / canvasSize.height),
            width: s * 1.1, height: s * 1.1
        )
    }

    private static func photoTransform(from design: ProBusinessCardDesign, canvasSize: CGSize) -> CardLayerTransform {
        if let c = design.style.photoCanvas {
            let ratio = design.style.photoScale.pointRatio
            return CardLayerTransform(
                centerX: c.normalizedX, centerY: c.normalizedY,
                width: Double(ratio), height: Double(ratio),
                rotation: c.rotation, scale: c.scale
            )
        }
        let engine = ProBusinessCardLayoutEngine(
            cardSize: canvasSize,
            safeInset: canvasSize.height * design.aspect.safeInsetRatio,
            photoScale: design.style.photoScale,
            placement: design.style.photoPlacement,
            showsPhoto: true
        )
        let frame = engine.photoFrame()
        guard frame != .zero else {
            return CardLayerTransform(centerX: 0.85, centerY: 0.85, width: 0.2, height: 0.2)
        }
        return CardLayerTransform(
            centerX: Double(frame.midX / canvasSize.width),
            centerY: Double(frame.midY / canvasSize.height),
            width: Double(frame.width / canvasSize.width),
            height: Double(frame.height / canvasSize.height),
            rotation: design.style.photoTransform.rotation
        )
    }

    // MARK: - Text

    private static func textLayers(from design: ProBusinessCardDesign, canvasSize: CGSize) -> [CardCanvasLayer] {
        let engine = ProBusinessCardLayoutEngine(
            cardSize: canvasSize,
            safeInset: canvasSize.height * design.aspect.safeInsetRatio,
            photoScale: design.style.photoScale,
            placement: design.style.photoPlacement,
            showsPhoto: design.options.showsPhoto
        )
        let content = engine.contentRect()
        let align = (ProBusinessCardTemplatePresets.layout(for: design).textAlign ?? design.options.textAlignment) == .center ? "center" : "leading"
        let typo = design.style.typography
        let fg = design.palette.foregroundHex
        let layout = ProBusinessCardTemplatePresets.layout(for: design)
        var layers: [CardCanvasLayer] = []

        let nameX: Double
        let nameY: Double
        if let c = design.style.nameCanvas {
            nameX = c.normalizedX
            nameY = c.normalizedY
        } else if let pos = layout.nameCenter {
            nameX = pos.x
            nameY = pos.y
        } else {
            nameX = Double(content.midX / canvasSize.width)
            nameY = Double((content.minY + 24) / canvasSize.height)
        }

        layers.append(CardCanvasLayer(
            name: "Name",
            kind: .text,
            transform: CardLayerTransform(centerX: nameX, centerY: nameY, width: 0.75, height: 0.12, scale: typo.nameScale),
            payload: .text(CardTextPayload(
                text: design.content.name,
                binding: .name,
                style: CardTextStyle(fontID: typo.fontID, fontSize: 20, colorHex: fg, alignment: align, isBold: true)
            ))
        ))

        if !design.content.tagline.isEmpty {
            layers.append(CardCanvasLayer(
                name: "Tagline",
                kind: .text,
                transform: CardLayerTransform(
                    centerX: nameX,
                    centerY: nameY + 0.08 * typo.taglineScale,
                    width: 0.72, height: 0.08, scale: typo.taglineScale
                ),
                payload: .text(CardTextPayload(
                    text: design.content.tagline,
                    binding: .tagline,
                    style: CardTextStyle(fontID: typo.fontID, fontSize: 11, colorHex: fg, alignment: align, isBold: false)
                ))
            ))
        }

        var contactLines: [String] = []
        if !design.content.phone.isEmpty { contactLines.append(design.content.phone) }
        if !design.content.email.isEmpty { contactLines.append(design.content.email) }
        if !design.content.website.isEmpty { contactLines.append(design.content.website) }
        if !contactLines.isEmpty {
            let contactText = contactLines.joined(separator: "\n")
            let contactX: Double
            let contactY: Double
            if let pos = layout.contactCenter {
                contactX = pos.x
                contactY = pos.y
            } else {
                contactX = align == "center" ? 0.5 : Double(content.minX / canvasSize.width) + 0.28
                contactY = Double((content.maxY - 28) / canvasSize.height)
            }
            layers.append(CardCanvasLayer(
                name: "Contact",
                kind: .text,
                transform: CardLayerTransform(
                    centerX: contactX,
                    centerY: contactY,
                    width: 0.55, height: 0.14, scale: typo.contactScale
                ),
                payload: .text(CardTextPayload(
                    text: contactText,
                    binding: .none,
                    style: CardTextStyle(fontID: typo.fontID, fontSize: 9, colorHex: fg, alignment: align, isBold: false)
                ))
            ))
        }

        if design.options.showsSkills, !design.content.skills.isEmpty {
            layers.append(CardCanvasLayer(
                name: "Skills",
                kind: .text,
                transform: CardLayerTransform(centerX: nameX, centerY: nameY + 0.16, width: 0.7, height: 0.07),
                payload: .text(CardTextPayload(
                    text: design.content.skills,
                    binding: .skills,
                    style: CardTextStyle(fontID: typo.fontID, fontSize: 9, colorHex: fg, alignment: align)
                ))
            ))
        }

        return layers
    }

    // MARK: - QR & watermark

    private static func qrLayer(from design: ProBusinessCardDesign, canvasSize: CGSize) -> CardCanvasLayer {
        let layout = ProBusinessCardTemplatePresets.layout(for: design)
        let t: CardLayerTransform
        if let c = design.style.qrCanvas {
            t = CardLayerTransform(centerX: c.normalizedX, centerY: c.normalizedY, width: 0.16, height: 0.16, rotation: c.rotation, scale: c.scale)
        } else if let pos = layout.qrCenter {
            t = CardLayerTransform(centerX: pos.x, centerY: pos.y, width: 0.14, height: 0.14)
        } else {
            t = CardLayerTransform(centerX: 0.88, centerY: 0.88, width: 0.14, height: 0.14)
        }
        return CardCanvasLayer(
            name: "QR Code",
            kind: .qr,
            transform: t,
            payload: .qr(CardQRPayload())
        )
    }

    private static func watermarkLayer(from design: ProBusinessCardDesign) -> CardCanvasLayer {
        let wm = design.style.watermark
        return CardCanvasLayer(
            name: "Watermark",
            kind: .watermark,
            transform: CardLayerTransform(
                centerX: wm.normalizedX, centerY: wm.normalizedY,
                width: 0.7, height: 0.2,
                rotation: wm.rotation, scale: wm.scale
            ),
            opacity: wm.opacity,
            payload: .watermark(CardWatermarkPayload(
                text: wm.text.isEmpty ? design.content.name : wm.text,
                fontID: design.style.typography.fontID,
                colorHex: design.palette.foregroundHex,
                binding: .name
            ))
        )
    }
}
