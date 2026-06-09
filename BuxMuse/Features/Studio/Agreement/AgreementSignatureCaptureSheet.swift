//
//  AgreementSignatureCaptureSheet.swift
//  BuxMuse
//

import PencilKit
import SwiftUI

enum AgreementSignatureRole {
    case client
    case provider
}

struct AgreementSignatureCaptureSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    let role: AgreementSignatureRole
    let onCapture: (Data) -> Void

    @State private var drawing = PKDrawing()

    private var locale: Locale { appSettingsManager.interfaceLocale }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: BuxTokens.section) {
                Text(role.catalogPrompt(locale: locale))
                    .font(.system(size: 13, weight: .medium))
                    .buxLabelSecondary()
                    .fixedSize(horizontal: false, vertical: true)

                StudioSignaturePadView(drawing: $drawing)
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: BuxTokens.Radius.card, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: BuxTokens.Radius.card, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
                    )

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
    }
}
