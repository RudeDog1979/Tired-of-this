//
//  AgreementImportedSignatureCaptureSheet.swift
//  BuxMuse — Tap-to-place signature capture with transparent PNG output.
//

import PencilKit
import SwiftUI

struct AgreementImportedSignatureCaptureSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager

    let role: AgreementSignatureRole
    let onCapture: (Data) -> Void

    @State private var drawing = PKDrawing()

    private var canvasHeight: CGFloat {
        BuxPadIdiom.isPad ? 240 : 180
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: BuxTokens.section) {
                Text(role.prompt)
                    .font(.system(size: 13, weight: .medium))
                    .buxLabelSecondary()
                    .fixedSize(horizontal: false, vertical: true)

                ZStack(alignment: .bottomTrailing) {
                    Group {
                        if BuxPadIdiom.isPad {
                            BuxPadPencilCanvasView(
                                drawing: $drawing,
                                drawingPolicy: .anyInput,
                                showsToolPicker: true
                            )
                        } else {
                            StudioSignaturePadView(drawing: $drawing)
                        }
                    }
                    .frame(height: canvasHeight)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: BuxTokens.Radius.card, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: BuxTokens.Radius.card, style: .continuous)
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

                BuxCatalogDynamicText(key: "Your signature is saved without a background and placed where you tapped.")
                    .font(.system(size: 11, weight: .medium))
                    .buxLabelSecondary()
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(BuxTokens.marginRegular)
            .navigationTitle(role.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    BuxToolbarCancelButton { dismiss() }
                }
                ToolbarItem(placement: .bottomBar) {
                    Button("Clear pad") {
                        drawing = PKDrawing()
                    }
                    .font(.system(size: 15, weight: .semibold))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        guard let png = AgreementImportedSignatureRasterizer.transparentPNG(from: drawing) else { return }
                        onCapture(png)
                        BuxSaveFeedback.success()
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .bold))
                    .disabled(drawing.bounds.isEmpty)
                }
            }
        }
        .buxStudioSheetContent()
        .presentationDetents([.medium, .large])
    }
}
