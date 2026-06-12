//
//  BuxShapePickerSheet.swift
//  BuxMuse
//

import SwiftUI

struct BuxShapePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    let palette: ProBusinessCardPalette
    var onPickShape: (CardShapeType) -> Void
    var onApplyPack: (BuxBrandStyleEngine.LayoutPack) -> Void

    var body: some View {
        NavigationStack {
            List {
                Section(BusinessCardL10n.line("Bux Layout Packs", locale: appSettingsManager.interfaceLocale)) {
                    ForEach(BuxBrandStyleEngine.layoutPacks) { pack in
                        Button {
                            onApplyPack(pack)
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(pack.catalogTitle(locale: appSettingsManager.interfaceLocale)).font(.headline)
                                Text(pack.catalogSubtitle(locale: appSettingsManager.interfaceLocale)).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section(BusinessCardL10n.line("Geometric shapes", locale: appSettingsManager.interfaceLocale)) {
                    ForEach(CardShapeType.geometricShapes) { shape in
                        shapeRow(shape)
                    }
                }

                Section(BusinessCardL10n.line("Basic shapes", locale: appSettingsManager.interfaceLocale)) {
                    ForEach(CardShapeType.basicShapes) { shape in
                        shapeRow(shape)
                    }
                }
            }
            .buxCatalogNavigationTitle("Bux Shapes")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(BusinessCardL10n.line("Close", locale: appSettingsManager.interfaceLocale)) { dismiss() }
                }
            }
        }
    }

    private func shapeRow(_ shape: CardShapeType) -> some View {
        Button {
            onPickShape(shape)
            dismiss()
        } label: {
            HStack(spacing: 12) {
                BuxGeometricShapeView(
                    type: shape,
                    fill: AnyShapeStyle(Color(hex: palette.accentHex)),
                    stroke: nil,
                    strokeWidth: 0,
                    cornerRadius: 4
                )
                .frame(width: 36, height: 28)
                Text(shape.catalogTitle(locale: appSettingsManager.interfaceLocale))
            }
        }
    }
}
