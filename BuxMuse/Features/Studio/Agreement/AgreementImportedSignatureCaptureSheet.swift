//
//  AgreementImportedSignatureCaptureSheet.swift
//  BuxMuse — Tap-to-place signature capture with transparent PNG output.
//

import PencilKit
import SwiftUI

struct AgreementImportedSignatureCaptureSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    let role: AgreementSignatureRole
    let onCapture: (Data) -> Void

    @State private var drawing = PKDrawing()
    @State private var inkColor = Color(red: 0, green: 0, blue: 0)
    @State private var inkUIColor = AgreementSignatureInk.black

    private var locale: Locale { appSettingsManager.interfaceLocale }

    private var canvasHeight: CGFloat {
        BuxPadIdiom.isPad ? 240 : 180
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: BuxTokens.section) {
                Text(role.catalogPrompt(locale: locale))
                    .font(.system(size: 13, weight: .medium))
                    .buxLabelSecondary()
                    .fixedSize(horizontal: false, vertical: true)

                if !BuxPadIdiom.isPad {
                    AgreementSignatureInkColorPicker(inkColor: $inkColor, inkUIColor: $inkUIColor)
                }

                ZStack(alignment: .bottomTrailing) {
                    Group {
                        if BuxPadIdiom.isPad {
                            BuxPadPencilCanvasView(
                                drawing: $drawing,
                                drawingPolicy: .anyInput,
                                showsToolPicker: true
                            )
                        } else {
                            BuxPadPencilCanvasView(
                                drawing: $drawing,
                                drawingPolicy: .anyInput,
                                showsToolPicker: false,
                                inkColor: inkUIColor,
                                inkWidth: 2.5
                            )
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
                        BuxCatalogDynamicText(key: "Sign here")
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
            .buxCatalogNavigationTitle(role.catalogTitle(locale: locale))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    BuxToolbarCancelButton { dismiss() }
                }
                ToolbarItem(placement: .bottomBar) {
                    Button {
                        drawing = PKDrawing()
                    } label: {
                        BuxCatalogDynamicText(key: "Clear pad")
                    }
                    .font(.system(size: 15, weight: .semibold))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        let png = BuxPadIdiom.isPad
                            ? AgreementImportedSignatureRasterizer.transparentPNG(from: drawing)
                            : AgreementImportedSignatureRasterizer.transparentPNG(from: drawing, literalInk: inkUIColor)
                        guard let png else { return }
                        onCapture(png)
                        BuxSaveFeedback.success()
                        dismiss()
                    } label: {
                        BuxCatalogDynamicText(key: "Save")
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
