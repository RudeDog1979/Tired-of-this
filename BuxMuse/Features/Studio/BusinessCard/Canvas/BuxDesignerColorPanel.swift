//
//  BuxDesignerColorPanel.swift
//  BuxMuse — compact inline swatches + color well (opens pro picker)
//

import SwiftUI

struct BuxDesignerColorPanel: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    let title: String
    let currentHex: String
    var brandPalette: ProBusinessCardPalette
    var layerOpacity: Binding<Double>?
    let onPick: (String) -> Void

    @State private var showSheet = false

    private let swatchSize: CGFloat = 28
    private let rowHeight: CGFloat = 36

    private var controlTint: Color {
        themeManager.contrastAccentColor(for: colorScheme)
    }

    private var quickSwatches: [(String, String)] {
        BuxDesignerColorPresets.swatches(for: brandPalette) + [
            ("Black", "#111827"),
            ("White", "#FFFFFF"),
            ("Clear", "#00000000"),
        ]
    }

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(BusinessCardL10n.line(title, locale: appSettingsManager.interfaceLocale))
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.secondary)
                .frame(width: 72, alignment: .leading)
                .lineLimit(1)

            HStack(alignment: .center, spacing: 6) {
                Button { showSheet = true } label: {
                    BuxDesignerColorWell(hex: currentHex, size: swatchSize, showsRing: true)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    BuxLocalizedString.format(
                        "%@, open color picker",
                        locale: appSettingsManager.interfaceLocale,
                        BusinessCardL10n.line(title, locale: appSettingsManager.interfaceLocale)
                    )
                )

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .center, spacing: 6) {
                        ForEach(quickSwatches, id: \.0) { label, hex in
                            presetSwatch(label: label, hex: hex)
                        }
                        moreColorsButton
                    }
                }
            }
            .frame(height: rowHeight)
        }
        .frame(minHeight: rowHeight)
        .sheet(isPresented: $showSheet) {
            BuxDesignerColorPickerSheet(
                title: title,
                initialHex: currentHex,
                brandPalette: brandPalette,
                layerOpacity: layerOpacity,
                onCommit: onPick
            )
            .environmentObject(themeManager)
        }
    }

    private var moreColorsButton: some View {
        Button { showSheet = true } label: {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(controlTint)
                .frame(width: swatchSize, height: swatchSize)
                .background(controlTint.opacity(0.12), in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            BuxLocalizedString.format(
                "More colors for %@",
                locale: appSettingsManager.interfaceLocale,
                BusinessCardL10n.line(title, locale: appSettingsManager.interfaceLocale)
            )
        )
    }

    private func presetSwatch(label: String, hex: String) -> some View {
        let selected = currentHex.uppercased() == hex.uppercased()
        return Button {
            onPick(hex)
        } label: {
            BuxDesignerColorWell(hex: hex, size: swatchSize, showsRing: selected)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(BusinessCardL10n.line(label, locale: appSettingsManager.interfaceLocale))
    }
}
