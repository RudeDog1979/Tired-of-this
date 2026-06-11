//
//  AgreementImportedInlineSignaturePad.swift
//  BuxMuse — Clear-canvas signature pad (transparent export) for imported agreements.
//

import Combine
import PencilKit
import SwiftUI
import UIKit

final class AgreementImportedSignatureDrawingUndo: ObservableObject {
    @Published private(set) var canUndo = false
    private weak var canvasView: PKCanvasView?

    func bind(_ canvas: PKCanvasView) {
        canvasView = canvas
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
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    let role: AgreementSignatureRole
    @Binding var drawing: PKDrawing
    var onCancel: () -> Void
    var onSave: (Data) -> Void

    @StateObject private var drawingUndo = AgreementImportedSignatureDrawingUndo()
    @State private var inkColor = Color(red: 0, green: 0, blue: 0)
    @State private var inkUIColor = AgreementSignatureInk.black

    private var locale: Locale { appSettingsManager.interfaceLocale }

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
            if !BuxPadIdiom.isPad {
                AgreementSignatureInkColorPicker(inkColor: $inkColor, inkUIColor: $inkUIColor)
                    .padding(.horizontal, BuxTokens.marginRegular)
                    .padding(.bottom, 8)
            }
            canvasBlock
                .padding(.horizontal, BuxTokens.marginRegular)
                .padding(.bottom, 12)
        }
        .background(.regularMaterial)
    }

    private var headerRow: some View {
        HStack {
            Text(role.catalogTitle(locale: locale))
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
                    let png = BuxPadIdiom.isPad
                        ? AgreementImportedSignatureRasterizer.transparentPNG(from: drawing)
                        : AgreementImportedSignatureRasterizer.transparentPNG(from: drawing, literalInk: inkUIColor)
                    guard let png else { return }
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
            AgreementImportedClearSignatureCanvas(
                drawing: $drawing,
                drawingUndo: drawingUndo,
                inkColor: BuxPadIdiom.isPad ? AgreementSignatureInk.black : inkUIColor
            )
                .frame(height: canvasHeight)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
                )

            if drawing.bounds.isEmpty {
                BuxCatalogDynamicText(key: "Sign here")
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
    let drawingUndo: AgreementImportedSignatureDrawingUndo
    var inkColor: UIColor = AgreementSignatureInk.black

    func makeCoordinator() -> Coordinator {
        Coordinator(drawing: $drawing, drawingUndo: drawingUndo, inkColor: inkColor)
    }

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.drawing = drawing
        canvas.drawingPolicy = .anyInput
        if BuxPadIdiom.isPad {
            canvas.tool = PKInkingTool(.pen, color: inkColor, width: 2.5)
        } else {
            AgreementSignatureInk.preparePhoneSignatureCanvas(canvas)
            AgreementSignatureInk.applyPenInk(inkColor, width: 2.5, to: canvas)
        }
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
        if uiView.drawing != drawing {
            uiView.drawing = drawing
        }
        if !BuxPadIdiom.isPad {
            context.coordinator.applyInkColor(inkColor, to: uiView)
        }
    }

    static func dismantleUIView(_ uiView: PKCanvasView, coordinator: Coordinator) {
        coordinator.toolPicker?.setVisible(false, forFirstResponder: uiView)
        coordinator.toolPicker?.removeObserver(uiView)
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        @Binding var drawing: PKDrawing
        private let drawingUndo: AgreementImportedSignatureDrawingUndo
        var toolPicker: PKToolPicker?
        private var appliedInkColor: UIColor

        private let pinsLiteralInk: Bool

        init(
            drawing: Binding<PKDrawing>,
            drawingUndo: AgreementImportedSignatureDrawingUndo,
            inkColor: UIColor
        ) {
            _drawing = drawing
            self.drawingUndo = drawingUndo
            pinsLiteralInk = !BuxPadIdiom.isPad
            appliedInkColor = inkColor
        }

        func applyInkColor(_ inkColor: UIColor, to canvasView: PKCanvasView) {
            guard appliedInkColor.cgColor != inkColor.cgColor else { return }
            appliedInkColor = inkColor
            AgreementSignatureInk.applyPenInk(inkColor, width: 2.5, to: canvasView)
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            if pinsLiteralInk {
                AgreementSignatureInk.applyPenInk(appliedInkColor, width: 2.5, to: canvasView)
            }
            let updated = canvasView.drawing
            DispatchQueue.main.async { [self] in
                if drawing != updated {
                    drawing = updated
                }
                drawingUndo.refresh()
            }
        }
    }
}
