//
//  CardBackgroundEditor.swift
//  BuxMuse
//

import PhotosUI
import SwiftUI

struct CardBackgroundEditor: View {
    @Binding var background: CardBackgroundSpec
    var brandPalette: ProBusinessCardPalette = .defaultPreset
    var cardAspect: ProBusinessCardAspect = .standardUS
    var onPickPhoto: () -> Void
    var onPhotoPicked: ((UIImage) -> Void)?
    var onAdjustPhoto: (() -> Void)?
    var onChange: () -> Void

    @State private var photoPickerItem: PhotosPickerItem?

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Recommended: \(cardAspect.detail)", systemImage: "rectangle.portrait.rotate")
                        .font(.system(size: 13, weight: .bold))
                    Text("You do not need a perfect photo size. Choose any image, then pan, zoom, crop to the card, or pick a free region.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)

                Button {
                    background.style = .photo
                    onPickPhoto()
                } label: {
                    Label("Choose photo from library", systemImage: "photo.on.rectangle.angled")
                }

                PhotosPicker(selection: $photoPickerItem, matching: .images) {
                    Label("Pick with Photos picker", systemImage: "photo.badge.plus")
                }

                if background.photoPath != nil {
                    Button {
                        onAdjustPhoto?()
                    } label: {
                        Label("Adjust for card size", systemImage: "arrow.up.left.and.arrow.down.right")
                    }
                    Button(role: .destructive) {
                        background.photoPath = nil
                        background.style = .solid
                        onChange()
                    } label: {
                        Label("Remove photo", systemImage: "trash")
                    }
                }
            } header: {
                Text("Background photo")
            }

            Picker("Style", selection: $background.style) {
                ForEach(ProBusinessCardBackgroundStyle.allCases) { Text($0.title).tag($0) }
            }
            .onChange(of: background.style) { _, style in
                if style == .photo, background.photoPath == nil {
                    onPickPhoto()
                } else {
                    onChange()
                }
            }

            Section("Colors") {
                BuxDesignerColorFormRow(title: "Background", hex: $background.solidHex, brandPalette: brandPalette, onChange: onChange)
                BuxDesignerColorFormRow(title: "Accent", hex: $background.accentHex, brandPalette: brandPalette, onChange: onChange)
                if background.overlayHex != nil {
                    BuxDesignerColorFormRow(
                        title: "Overlay",
                        hex: Binding(
                            get: { background.overlayHex ?? "#000000" },
                            set: { background.overlayHex = $0 }
                        ),
                        brandPalette: brandPalette,
                        onChange: onChange
                    )
                } else {
                    Button("Add overlay tint") {
                        background.overlayHex = "#000000"
                        background.overlayOpacity = 0.25
                        onChange()
                    }
                }
                if background.overlayHex != nil {
                    Slider(value: $background.overlayOpacity, in: 0...0.85)
                        .onChange(of: background.overlayOpacity) { _, _ in onChange() }
                    LabeledContent("Overlay strength") {
                        Text("\(Int(background.overlayOpacity * 100))%")
                    }
                }
            }

            if background.style == .photo || background.photoPath != nil {
                Section("Photo tuning") {
                    Slider(value: $background.photoOpacity, in: 0.2...1)
                        .onChange(of: background.photoOpacity) { _, _ in onChange() }
                    LabeledContent("Photo opacity") { Text("\(Int(background.photoOpacity * 100))%") }
                    Slider(value: $background.saturation, in: 0...2)
                        .onChange(of: background.saturation) { _, _ in onChange() }
                    LabeledContent("Saturation") { Text(String(format: "%.1f", background.saturation)) }
                    Slider(value: $background.brightness, in: -0.5...0.5)
                        .onChange(of: background.brightness) { _, _ in onChange() }
                    LabeledContent("Brightness") { Text(String(format: "%.2f", background.brightness)) }
                }
            }
        }
        .onChange(of: background.solidHex) { _, _ in onChange() }
        .onChange(of: background.accentHex) { _, _ in onChange() }
        .onChange(of: photoPickerItem) { _, item in
            guard let item else { return }
            Task {
                if let image = await PhotoImageLoader.loadUIImage(from: item) {
                    await MainActor.run {
                        background.style = .photo
                        if let onPhotoPicked {
                            onPhotoPicked(image)
                        } else {
                            onPickPhoto()
                        }
                        photoPickerItem = nil
                    }
                }
            }
        }
    }
}
