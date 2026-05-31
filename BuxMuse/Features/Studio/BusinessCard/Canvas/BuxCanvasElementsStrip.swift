//
//  BuxCanvasElementsStrip.swift
//  BuxMuse — tap-to-select layer list (shapes, text, photo, logo…)
//

import SwiftUI

struct BuxCanvasElementsStrip: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager

    let layers: [CardCanvasLayer]
    @Binding var selectedID: UUID?
    @Binding var backgroundSelected: Bool
    var onSelect: (UUID?) -> Void

    private var reversedLayers: [CardCanvasLayer] {
        layers.filter { !$0.isHidden }.reversed()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Elements")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    elementChip(title: "Background", icon: "photo.fill.on.rectangle.fill", isSelected: backgroundSelected) {
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
            }
        }
    }

    private func elementChip(title: String, icon: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 10, weight: .semibold))
                Text(title)
                    .font(.system(size: 10, weight: .bold))
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? Color.white : themeManager.labelPrimary(for: colorScheme))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                isSelected
                    ? themeManager.current.accentColor
                    : themeManager.current.accentColor.opacity(colorScheme == .dark ? 0.14 : 0.07),
                in: Capsule()
            )
            .overlay {
                if !isSelected {
                    Capsule()
                        .strokeBorder(themeManager.current.accentColor.opacity(0.12), lineWidth: 0.5)
                }
            }
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
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
