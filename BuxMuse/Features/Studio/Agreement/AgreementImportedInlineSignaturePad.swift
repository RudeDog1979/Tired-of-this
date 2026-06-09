//
//  AgreementImportedInlineSignaturePad.swift
//  BuxMuse — Clear-canvas signature pad (transparent export) for imported agreements.
//

import Combine
import PencilKit
import SwiftUI

final class AgreementImportedSignatureDrawingUndo: ObservableObject {
    @Published private(set) var canUndo = false
    private weak var canvasView: PKCanvasView?

    func bind(_ canvas: PKCanvasView) {
        canvasView = canvas
        refresh()
    }

    func undo() {
        canvasView?.undoManager?.undo()
        refresh()
    }

    func refresh() {
        let can = canvasView?.undoManager?.canUndo ?? false
        if canUndo != can {
            canUndo = can
        }
    }
}

struct AgreementImportedInlineSignaturePad: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager

    let role: AgreementSignatureRole
    @Binding var drawing: PKDrawing
    var onCancel: () -> Void
    var onSave: (Data) -> Void

    @StateObject private var drawingUndo = AgreementImportedSignatureDrawingUndo()

    private var accent: Color {
        themeManager.contrastAccentColor(for: colorScheme)
    }

    private var canvasHeight: CGFloat {
        BuxPadIdiom.isPad ? 240 : 160
    }

    var body: some View {
        VStack(spacing: 0) {
            headerRow
            actionRow
            canvasBlock
                .padding(.horizontal, BuxTokens.marginRegular)
                .padding(.bottom, 12)
        }
        .background(.regularMaterial)
    }

    private var headerRow: some View {
        HStack {
            Text(role.title)
                .font(.system(size: 15, weight: .bold))
            Spacer()
            BuxActionButton(
                title: "Cancel",
                systemImage: "xmark",
                role: .secondary,
                accent: accent,
                size: .compact,
                action: onCancel
            )
        }
        .padding(.horizontal, BuxTokens.marginRegular)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private var actionRow: some View {
        HStack(spacing: 8) {
            BuxActionButton(
                title: "Clear",
                systemImage: "trash",
                role: .secondary,
                accent: accent,
                size: .regular,
                action: { drawing = PKDrawing() }
            )

            BuxActionButton(
                title: "Undo",
                systemImage: "arrow.uturn.backward",
                role: .secondary,
                accent: accent,
                size: .regular,
                isEnabled: drawingUndo.canUndo,
                action: { drawingUndo.undo() }
            )

            BuxActionButton(
                title: "Place signature",
                systemImage: "signature",
                role: .primary,
                accent: accent,
                size: .regular,
                isEnabled: !drawing.bounds.isEmpty,
                action: {
                    guard let png = AgreementImportedSignatureRasterizer.transparentPNG(from: drawing) else { return }
                    onSave(png)
                }
            )
        }
        .buxNativeGlassButtonRowContainer(spacing: 8)
        .padding(.horizontal, BuxTokens.marginRegular)
        .padding(.bottom, 10)
    }

    private var canvasBlock: some View {
        ZStack(alignment: .bottomTrailing) {
            AgreementImportedClearSignatureCanvas(drawing: $drawing, drawingUndo: drawingUndo)
                .frame(height: canvasHeight)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
                )

            if drawing.bounds.isEmpty {
                Text("Sign here")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary.opacity(0.7))
                    .padding(12)
                    .allowsHitTesting(false)
            }
        }
    }
}

private struct AgreementImportedClearSignatureCanvas: UIViewRepresentable {
    @Binding var drawing: PKDrawing
    @ObservedObject var drawingUndo: AgreementImportedSignatureDrawingUndo

    func makeCoordinator() -> Coordinator {
        Coordinator(drawing: $drawing, drawingUndo: drawingUndo)
    }

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.drawing = drawing
        canvas.drawingPolicy = .anyInput
        canvas.tool = PKInkingTool(.monoline, color: .black, width: 0.25)
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.delegate = context.coordinator
        drawingUndo.bind(canvas)

        if BuxPadIdiom.isPad {
            let picker = PKToolPicker()
            picker.setVisible(true, forFirstResponder: canvas)
            picker.addObserver(canvas)
            canvas.becomeFirstResponder()
            context.coordinator.toolPicker = picker
        }

        return canvas
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        context.coordinator.syncFromViewIfNeeded(uiView, binding: $drawing)
        drawingUndo.bind(uiView)
    }

    static func dismantleUIView(_ uiView: PKCanvasView, coordinator: Coordinator) {
        coordinator.toolPicker?.setVisible(false, forFirstResponder: uiView)
        coordinator.toolPicker?.removeObserver(uiView)
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        private var drawingBinding: Binding<PKDrawing>
        private let drawingUndo: AgreementImportedSignatureDrawingUndo
        var toolPicker: PKToolPicker?
        private var isSyncingFromSwiftUI = false

        init(drawing: Binding<PKDrawing>, drawingUndo: AgreementImportedSignatureDrawingUndo) {
            drawingBinding = drawing
            self.drawingUndo = drawingUndo
        }

        func syncFromViewIfNeeded(_ canvasView: PKCanvasView, binding: Binding<PKDrawing>) {
            drawingBinding = binding
            guard canvasView.drawing != binding.wrappedValue else { return }
            isSyncingFromSwiftUI = true
            canvasView.drawing = binding.wrappedValue
            isSyncingFromSwiftUI = false
            drawingUndo.refresh()
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            guard !isSyncingFromSwiftUI else { return }
            let updated = canvasView.drawing
            DispatchQueue.main.async { [drawingBinding, drawingUndo] in
                if drawingBinding.wrappedValue != updated {
                    drawingBinding.wrappedValue = updated
                }
                drawingUndo.refresh()
            }
        }
    }
}
