//
//  StudioSignaturePadView.swift
//  BuxMuse
//
//  Finger / stylus signature capture for agreements.
//

import PencilKit
import SwiftUI
import UIKit

/// Literal sRGB ink on the white signing pad — not shell theme.
enum AgreementSignatureInk {
    static let black = srgbUIColor(red: 0, green: 0, blue: 0)
    static let white = srgbUIColor(red: 1, green: 1, blue: 1)

    static func fixedUIColor(from color: Color) -> UIColor {
        let rgb = literalRGB(from: color)
        return srgbUIColor(red: rgb.r, green: rgb.g, blue: rgb.b)
    }

    static func fixedUIColor(from uiColor: UIColor) -> UIColor {
        let rgb = literalRGB(from: uiColor)
        return srgbUIColor(red: rgb.r, green: rgb.g, blue: rgb.b)
    }

    static func srgbUIColor(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat = 1) -> UIColor {
        UIColor(cgColor: CGColor(srgbRed: red, green: green, blue: blue, alpha: alpha))
    }

    /// PencilKit inverts pen ink when the canvas inherits shell dark mode.
    static func preparePhoneSignatureCanvas(_ canvas: PKCanvasView) {
        canvas.overrideUserInterfaceStyle = .light
    }

    static func applyPenInk(_ ink: UIColor, width: CGFloat, to canvas: PKCanvasView) {
        canvas.tool = PKInkingTool(.pen, color: ink, width: width)
    }

    private struct RGB {
        let r: CGFloat
        let g: CGFloat
        let b: CGFloat
    }

    private static func literalRGB(from color: Color) -> RGB {
        literalRGB(from: UIColor(color))
    }

    private static func literalRGB(from uiColor: UIColor) -> RGB {
        let probe = UIView()
        probe.overrideUserInterfaceStyle = .light
        probe.backgroundColor = uiColor
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 1
        if let sampled = probe.backgroundColor, sampled.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            return RGB(r: red, g: green, b: blue)
        }
        return RGB(r: 0, g: 0, b: 0)
    }
}

struct AgreementSignatureInkColorPicker: View {
    @Binding var inkColor: Color
    @Binding var inkUIColor: UIColor

    var body: some View {
        ColorPicker(selection: $inkColor, supportsOpacity: false) {
            BuxCatalogDynamicText(key: "Ink color")
                .font(.system(size: 13, weight: .semibold))
        }
        .onAppear {
            inkUIColor = AgreementSignatureInk.fixedUIColor(from: inkColor)
        }
        .onChange(of: inkColor) { _, newValue in
            inkUIColor = AgreementSignatureInk.fixedUIColor(from: newValue)
        }
    }
}

struct StudioSignaturePadView: UIViewRepresentable {
    @Binding var drawing: PKDrawing
    var inkColor: UIColor = AgreementSignatureInk.black

    func makeCoordinator() -> Coordinator {
        Coordinator(drawing: $drawing, inkColor: inkColor)
    }

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.drawing = drawing
        canvas.drawingPolicy = .anyInput
        AgreementSignatureInk.preparePhoneSignatureCanvas(canvas)
        AgreementSignatureInk.applyPenInk(inkColor, width: 2.5, to: canvas)
        canvas.backgroundColor = .white
        canvas.isOpaque = true
        canvas.delegate = context.coordinator
        return canvas
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        if uiView.drawing != drawing {
            uiView.drawing = drawing
        }
        context.coordinator.applyInkColor(inkColor, to: uiView)
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        @Binding var drawing: PKDrawing
        private var appliedInkColor: UIColor

        init(drawing: Binding<PKDrawing>, inkColor: UIColor) {
            _drawing = drawing
            appliedInkColor = inkColor
        }

        func applyInkColor(_ inkColor: UIColor, to canvasView: PKCanvasView) {
            guard appliedInkColor.cgColor != inkColor.cgColor else { return }
            appliedInkColor = inkColor
            AgreementSignatureInk.applyPenInk(inkColor, width: 2.5, to: canvasView)
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            AgreementSignatureInk.applyPenInk(appliedInkColor, width: 2.5, to: canvasView)
            let updated = canvasView.drawing
            DispatchQueue.main.async { [self] in
                if drawing != updated {
                    drawing = updated
                }
            }
        }
    }
}

enum StudioSignatureRasterizer {
    static func pngData(from drawing: PKDrawing, size: CGSize = CGSize(width: 520, height: 160)) -> Data? {
        guard !drawing.bounds.isEmpty else { return nil }
        let bounds = drawing.bounds.insetBy(dx: -12, dy: -12)
        let image = drawing.image(from: bounds, scale: 2)
        let renderer = UIGraphicsImageRenderer(size: size)
        let composed = renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            let scale = min(
                (size.width - 24) / image.size.width,
                (size.height - 24) / image.size.height
            )
            let drawSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            let origin = CGPoint(
                x: (size.width - drawSize.width) / 2,
                y: (size.height - drawSize.height) / 2
            )
            image.draw(in: CGRect(origin: origin, size: drawSize))
        }
        return composed.pngData()
    }
}
