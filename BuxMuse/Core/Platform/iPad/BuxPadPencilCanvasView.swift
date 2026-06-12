//
//  BuxPadPencilCanvasView.swift
//  BuxMuse — PencilKit canvas with tool picker (iPad Stage Manager / Magic Keyboard).
//

import PencilKit
import SwiftUI
import UIKit

struct BuxPadPencilCanvasView: UIViewRepresentable {
    @Binding var drawing: PKDrawing
    var drawingPolicy: PKCanvasViewDrawingPolicy = .anyInput
    var showsToolPicker: Bool = true
    var inkColor: UIColor = AgreementSignatureInk.black
    var inkWidth: CGFloat = 3

    func makeCoordinator() -> Coordinator {
        Coordinator(
            drawing: $drawing,
            inkColor: inkColor,
            inkWidth: inkWidth,
            pinsLiteralInk: !showsToolPicker
        )
    }

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.drawing = drawing
        canvas.drawingPolicy = drawingPolicy
        if !showsToolPicker {
            AgreementSignatureInk.preparePhoneSignatureCanvas(canvas)
            AgreementSignatureInk.applyPenInk(inkColor, width: inkWidth, to: canvas)
        } else {
            canvas.tool = PKInkingTool(.pen, color: inkColor, width: inkWidth)
        }
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.delegate = context.coordinator

        if showsToolPicker, BuxPadIdiom.isPad {
            let picker = PKToolPicker()
            picker.setVisible(true, forFirstResponder: canvas)
            picker.addObserver(canvas)
            canvas.becomeFirstResponder()
            context.coordinator.toolPicker = picker
        }

        return canvas
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        if uiView.drawing != drawing {
            uiView.drawing = drawing
        }
        uiView.drawingPolicy = drawingPolicy
        if !showsToolPicker {
            context.coordinator.applyInkColor(inkColor, inkWidth: inkWidth, to: uiView)
        }
    }

    static func dismantleUIView(_ uiView: PKCanvasView, coordinator: Coordinator) {
        coordinator.toolPicker?.setVisible(false, forFirstResponder: uiView)
        coordinator.toolPicker?.removeObserver(uiView)
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        @Binding var drawing: PKDrawing
        var toolPicker: PKToolPicker?
        private let pinsLiteralInk: Bool
        private var appliedInkColor: UIColor
        private var appliedInkWidth: CGFloat

        init(
            drawing: Binding<PKDrawing>,
            inkColor: UIColor,
            inkWidth: CGFloat,
            pinsLiteralInk: Bool
        ) {
            _drawing = drawing
            self.pinsLiteralInk = pinsLiteralInk
            appliedInkColor = inkColor
            appliedInkWidth = inkWidth
        }

        func applyInkColor(_ inkColor: UIColor, inkWidth: CGFloat, to canvasView: PKCanvasView) {
            guard appliedInkColor.cgColor != inkColor.cgColor || appliedInkWidth != inkWidth else { return }
            appliedInkColor = inkColor
            appliedInkWidth = inkWidth
            AgreementSignatureInk.applyPenInk(inkColor, width: inkWidth, to: canvasView)
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            if pinsLiteralInk {
                AgreementSignatureInk.applyPenInk(appliedInkColor, width: appliedInkWidth, to: canvasView)
            }
            let updated = canvasView.drawing
            DispatchQueue.main.async { [self] in
                if drawing != updated {
                    drawing = updated
                }
            }
        }
    }
}

enum BuxPadPencilRasterizer {
    static func pngData(from drawing: PKDrawing, canvasSize: CGSize) -> Data? {
        StudioSignatureRasterizer.pngData(from: drawing, size: canvasSize)
    }

    static func composite(base: UIImage, drawing: PKDrawing) -> UIImage? {
        guard !drawing.bounds.isEmpty else { return base }
        let markupImage = drawing.image(from: drawing.bounds, scale: base.scale)
        let size = base.size
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            base.draw(in: CGRect(origin: .zero, size: size))
            markupImage.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
