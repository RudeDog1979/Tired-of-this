//
//  BuxCanvasElementsStrip.swift
//  BuxMuse — tap-to-select layer list (shapes, text, photo, logo…)
//

import SwiftUI

struct BuxCanvasElementsStrip: View {
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
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(0.55))

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
            .foregroundStyle(isSelected ? .white : .white.opacity(0.75))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? Color.white.opacity(0.22) : Color.white.opacity(0.08))
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
