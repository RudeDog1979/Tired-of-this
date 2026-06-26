//
//  CardBackgroundEditor.swift
//  BuxMuse
//

import PhotosUI
import SwiftUI

struct CardBackgroundEditor: View {
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

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
                    Label {
                        Text(
                            BuxLocalizedString.format(
                                "Recommended: %@",
                                locale: BuxInterfaceLocale.currentInterfaceLocale,
                                cardAspect.detail
                            )
                        )
                    } icon: {
                        Image(systemName: "rectangle.portrait.rotate")
                    }
                        .font(.system(size: 13, weight: .bold))
                    BuxCatalogDynamicText(key: "You do not need a perfect photo size. Choose any image, then pan, zoom, crop to the card, or pick a free region.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)

                Button {
                    background.style = .photo
                    onPickPhoto()
                } label: {
                    Label(BuxCatalogLabel.string("Choose photo from library", locale: appSettingsManager.interfaceLocale), systemImage: "photo.on.rectangle.angled")
                }

                PhotosPicker(selection: $photoPickerItem, matching: .images) {
                    Label(BuxCatalogLabel.string("Pick with Photos picker", locale: appSettingsManager.interfaceLocale), systemImage: "photo.badge.plus")
                }

                if background.photoPath != nil {
                    Button {
                        onAdjustPhoto?()
                    } label: {
                        Label(BuxCatalogLabel.string("Adjust for card size", locale: appSettingsManager.interfaceLocale), systemImage: "arrow.up.left.and.arrow.down.right")
                    }
                    Button(role: .destructive) {
                        background.photoPath = nil
                        background.style = .solid
                        onChange()
                    } label: {
                        Label(BuxCatalogLabel.string("Remove photo", locale: appSettingsManager.interfaceLocale), systemImage: "trash")
                    }
                }
            } header: {
                BuxCatalogDynamicText(key: "Background photo")
            }

            Picker(BusinessCardL10n.line("Style", locale: appSettingsManager.interfaceLocale), selection: $background.style) {
                ForEach(ProBusinessCardBackgroundStyle.allCases) {
                    Text($0.catalogTitle(locale: appSettingsManager.interfaceLocale)).tag($0)
                }
            }
            .onChange(of: background.style) { _, style in
                if style == .photo, background.photoPath == nil {
                    onPickPhoto()
                } else {
                    onChange()
                }
            }

            Section {
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
                    Button(BuxCatalogLabel.string("Add overlay tint", locale: appSettingsManager.interfaceLocale)) {
                        background.overlayHex = "#000000"
                        background.overlayOpacity = 0.25
                        onChange()
                    }
                }
                if background.overlayHex != nil {
                    Slider(value: $background.overlayOpacity, in: 0...0.85)
                        .onChange(of: background.overlayOpacity) { _, _ in onChange() }
                    LabeledContent(BuxCatalogLabel.string("Overlay strength", locale: appSettingsManager.interfaceLocale)) {
                        Text(
                            BuxLocalizedString.format(
                                "%lld%%",
                                locale: appSettingsManager.interfaceLocale,
                                Int(background.overlayOpacity * 100)
                            )
                        )
                    }
                }
            } header: {
                BuxCatalogDynamicText(key: "Colors")
            }

            if background.style == .photo || background.photoPath != nil {
                Section {
                    Slider(value: $background.photoOpacity, in: 0.2...1)
                        .onChange(of: background.photoOpacity) { _, _ in onChange() }
                    LabeledContent(BuxCatalogLabel.string("Photo opacity", locale: appSettingsManager.interfaceLocale)) {
                        Text(
                            BuxLocalizedString.format(
                                "%lld%%",
                                locale: appSettingsManager.interfaceLocale,
                                Int(background.photoOpacity * 100)
                            )
                        )
                    }
                    Slider(value: $background.saturation, in: 0...2)
                        .onChange(of: background.saturation) { _, _ in onChange() }
                    LabeledContent(BuxCatalogLabel.string("Saturation", locale: appSettingsManager.interfaceLocale)) { Text(String(format: "%.1f", background.saturation)) }
                    Slider(value: $background.brightness, in: -0.5...0.5)
                        .onChange(of: background.brightness) { _, _ in onChange() }
                    LabeledContent(BuxCatalogLabel.string("Brightness", locale: appSettingsManager.interfaceLocale)) { Text(String(format: "%.2f", background.brightness)) }
                } header: {
                    BuxCatalogDynamicText(key: "Photo tuning")
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
