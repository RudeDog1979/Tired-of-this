//
//  BuxCanvasElementsStrip.swift
//  BuxMuse — tap-to-select layer list (shapes, text, photo, logo…)
//

import SwiftUI

struct BuxCanvasElementsStrip: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @ObservedObject private var settings = SettingsStore.shared

    let layers: [CardCanvasLayer]
    @Binding var selectedID: UUID?
    @Binding var backgroundSelected: Bool
    var onSelect: (UUID?) -> Void

    private var controlTint: Color {
        themeManager.contrastAccentColor(for: colorScheme)
    }

    private var reversedLayers: [CardCanvasLayer] {
        layers.filter { !$0.isHidden }.reversed()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            BuxCatalogDynamicText(key: "Elements")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    elementChip(
                        title: BusinessCardL10n.line("Background", locale: appSettingsManager.interfaceLocale),
                        icon: "photo.fill.on.rectangle.fill",
                        isSelected: backgroundSelected
                    ) {
                        selectedID = nil
                        backgroundSelected = true
                        onSelect(nil)
                    }

                    ForEach(reversedLayers) { layer in
                        elementChip(
                            title: layer.name,
                            icon: icon(for: layer),
                            isSelected: selectedID == layer.id && !backgroundSelected
                        ) {
                            selectedID = layer.id
                            backgroundSelected = false
                            onSelect(layer.id)
                        }
                    }
                }
                .buxNativeGlassButtonRowContainer()
            }
        }
    }

    private func elementChip(title: String, icon: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label {
                Text(title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            } icon: {
                Image(systemName: icon)
            }
            .font(.system(size: 11, weight: .bold))
            .labelStyle(.titleAndIcon)
        }
        .buxNativeButtonStyle(isSelected ? .primary : .secondary)
        .buxActionButtonChrome(
            role: isSelected ? .primary : .secondary,
            accent: controlTint
        )
    }

    private func icon(for layer: CardCanvasLayer) -> String {
        switch layer.kind {
        case .text: return "textformat"
        case .image:
            if case .image(let p) = layer.payload, p.source == .profileLogo { return "building.2.fill" }
            return "person.crop.circle"
        case .qr: return "qrcode"
        case .shape: return "triangle.fill"
        case .watermark: return "textformat.size.larger"
        }
    }
}
