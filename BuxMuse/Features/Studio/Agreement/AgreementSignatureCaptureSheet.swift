//
//  AgreementSignatureCaptureSheet.swift
//  BuxMuse
//

import PencilKit
import SwiftUI

enum AgreementSignatureRole {
    case client
    case provider

    var title: String {
        switch self {
        case .client: "Client signature"
        case .provider: "Your signature"
        }
    }

    var prompt: String {
        switch self {
        case .client: "Hand the device to your client to sign with a finger or stylus."
        case .provider: "Sign to confirm you agree to the terms above."
        }
    }
}

struct AgreementSignatureCaptureSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager

    let role: AgreementSignatureRole
    let onCapture: (Data) -> Void

    @State private var drawing = PKDrawing()

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: BuxTokens.section) {
                Text(role.prompt)
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
                        guard let png = StudioSignatureRasterizer.pngData(from: drawing) else { return }
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
    }
}
