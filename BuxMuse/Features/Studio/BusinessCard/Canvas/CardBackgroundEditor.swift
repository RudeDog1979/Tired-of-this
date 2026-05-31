//
//  CardBackgroundEditor.swift
//  BuxMuse
//

import SwiftUI

struct CardBackgroundEditor: View {
    @Binding var background: CardBackgroundSpec
    var onPickPhoto: () -> Void
    var onOpenFocal: (() -> Void)?
    var onChange: () -> Void

    var body: some View {
        Form {
            Picker("Style", selection: $background.style) {
                ForEach(ProBusinessCardBackgroundStyle.allCases) { Text($0.title).tag($0) }
            }
            .onChange(of: background.style) { _, style in
                if style == .photo { onPickPhoto() }
                onChange()
            }

            Section("Colors") {
                colorRow("Background", hex: $background.solidHex)
                colorRow("Accent", hex: $background.accentHex)
            }

            if background.style == .photo {
                Section("Bux Photo") {
                    Slider(value: $background.photoOpacity, in: 0.2...1)
                        .onChange(of: background.photoOpacity) { _, _ in onChange() }
                    LabeledContent("Opacity") { Text("\(Int(background.photoOpacity * 100))%") }
                    Slider(value: $background.saturation, in: 0...2)
                        .onChange(of: background.saturation) { _, _ in onChange() }
                    LabeledContent("Saturation") { Text(String(format: "%.1f", background.saturation)) }
                    Slider(value: $background.brightness, in: -0.5...0.5)
                        .onChange(of: background.brightness) { _, _ in onChange() }
                    LabeledContent("Brightness") { Text(String(format: "%.2f", background.brightness)) }
                    Button("Choose photo", action: onPickPhoto)
                    if background.photoPath != nil {
                        Button("Bux Focal — pan & zoom background") { onOpenFocal?() }
                    }
                }
            }
        }
        .onChange(of: background.solidHex) { _, _ in onChange() }
        .onChange(of: background.accentHex) { _, _ in onChange() }
    }

    private func colorRow(_ title: String, hex: Binding<String>) -> some View {
        Picker(title, selection: hex) {
            ForEach(BuxCanvasColorPresets.all, id: \.self) { c in
                Text(c).tag(c)
            }
        }
    }
}
