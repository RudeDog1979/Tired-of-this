//
//  CardLayerPanel.swift
//  BuxMuse
//

import SwiftUI

struct CardLayerPanel: View {
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    @Binding var document: CardCanvasDocument
    @Binding var selectedID: UUID?
    @Binding var backgroundSelected: Bool
    var onChange: () -> Void

    private var orderedLayers: [CardCanvasLayer] {
        document.layers.filter { !$0.isHidden }.reversed()
    }

    var body: some View {
        List {
            Section(BusinessCardL10n.line("Canvas", locale: appSettingsManager.interfaceLocale)) {
                layerRow(
                    title: BusinessCardL10n.line("Background", locale: appSettingsManager.interfaceLocale),
                    icon: "photo.fill.on.rectangle.fill",
                    isSelected: backgroundSelected
                ) {
                    selectedID = nil
                    backgroundSelected = true
                }
            }

            Section(BusinessCardL10n.line("Elements · top to bottom", locale: appSettingsManager.interfaceLocale)) {
                ForEach(orderedLayers) { layer in
                    layerRow(
                        title: layer.name,
                        icon: icon(for: layer),
                        isSelected: selectedID == layer.id,
                        isLocked: layer.isLocked
                    ) {
                        selectedID = layer.id
                        backgroundSelected = false
                    }
                    .swipeActions(edge: .trailing) {
                        if !layer.isLocked {
                            Button { reorder(.front, layer) } label: { Label("Front", systemImage: "square.3.layers.3d.top.filled") }
                            Button { reorder(.forward, layer) } label: { Label("Up", systemImage: "arrow.up") }
                        }
                    }
                    .swipeActions(edge: .leading) {
                        if !layer.isLocked {
                            Button { reorder(.backward, layer) } label: { Label("Down", systemImage: "arrow.down") }
                            Button { reorder(.back, layer) } label: { Label("Back", systemImage: "square.3.layers.3d.bottom.filled") }
                        }
                    }
                }
            }
        }
        .environment(\.editMode, .constant(.active))
    }

    private enum ReorderAction { case front, forward, backward, back }

    private func reorder(_ action: ReorderAction, _ layer: CardCanvasLayer) {
        switch action {
        case .front: document.bringToFront(id: layer.id)
        case .forward: document.bringForward(id: layer.id)
        case .backward: document.sendBackward(id: layer.id)
        case .back: document.sendToBack(id: layer.id)
        }
        document.markCustomized()
        onChange()
    }

    private func layerRow(title: String, icon: String, isSelected: Bool, isLocked: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .frame(width: 20)
                Text(title)
                    .font(.system(size: 14, weight: isSelected ? .bold : .regular))
                Spacer()
                if isLocked {
                    Image(systemName: "lock.fill").font(.caption).foregroundStyle(.secondary)
                }
                if isSelected {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.tint)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func icon(for layer: CardCanvasLayer) -> String {
        switch layer.kind {
        case .text: return "textformat"
        case .image:
            if case .image(let p) = layer.payload, p.source == .profileLogo { return "building.2.fill" }
            return "photo"
        case .qr: return "qrcode"
        case .shape: return "triangle.fill"
        case .watermark: return "textformat.size.larger"
        }
    }
}
