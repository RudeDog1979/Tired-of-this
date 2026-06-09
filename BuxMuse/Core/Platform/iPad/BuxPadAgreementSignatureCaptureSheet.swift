//
//  BuxPadAgreementSignatureCaptureSheet.swift
//  BuxMuse — iPad Pencil-first agreement signatures (reuses existing rasterizer).
//

import PencilKit
import SwiftUI

struct BuxPadAgreementSignatureCaptureSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    let role: AgreementSignatureRole
    let onCapture: (Data) -> Void

    @State private var drawing = PKDrawing()

    private var locale: Locale { appSettingsManager.interfaceLocale }

    private var canvasHeight: CGFloat {
        BuxPadIdiom.isPad ? 260 : 180
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: BuxTokens.section) {
                HStack(spacing: 8) {
                    Image(systemName: "applepencil.gen1")
                        .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                    BuxCatalogDynamicText(key: "Use Apple Pencil or your finger in the box below.")
                        .font(.system(size: 13, weight: .medium))
                        .buxLabelSecondary()
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text(role.catalogPrompt(locale: locale))
                    .font(.system(size: 13, weight: .medium))
                    .buxLabelSecondary()
                    .fixedSize(horizontal: false, vertical: true)

                ZStack(alignment: .bottomTrailing) {
                    BuxPadPencilCanvasView(
                        drawing: $drawing,
                        drawingPolicy: .anyInput,
                        showsToolPicker: true
                    )
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

                BuxCatalogDynamicText(key: "Sign inside the box. Use Clear to start over.")
                    .font(.system(size: 11, weight: .medium))
                    .buxLabelSecondary()
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
                        guard let png = StudioSignatureRasterizer.pngData(from: drawing) else { return }
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
        .presentationDetents([.large])
    }
}
