//
//  ProBusinessCardPalettePicker.swift
//  BuxMuse
//
//  Tri-swatch presets + custom color sheet for card editor.
//

import SwiftUI

struct ProBusinessCardPalettePicker: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager

    let design: ProBusinessCardDesign
    var onSelect: (ProBusinessCardPalette) -> Void

    @State private var showCustomSheet = false

    private var fadeBackground: Color {
        themeManager.cardFill(for: colorScheme)
    }

    var body: some View {
        BuxThemedCardForm {
            BuxFormSection(title: "Colors") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        customSwatchButton
                        ForEach(BuxBrandStyleEngine.suggestedPalettes(for: design), id: \.name) { preset in
                            presetButton(preset)
                        }
                    }
                    .padding(.horizontal, BuxLayout.section)
                    .padding(.vertical, 6)
                }
                .buxHorizontalScrollEdgeFade(background: fadeBackground, width: 16)
            }
        }
        .sheet(isPresented: $showCustomSheet) {
            ProBusinessCardCustomColorSheet(
                palette: design.palette,
                onApply: { onSelect($0) }
            )
            .environmentObject(themeManager)
        }
    }

    private var customSwatchButton: some View {
        Button { showCustomSheet = true } label: {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(
                            AngularGradient(
                                colors: [.red, .yellow, .green, .cyan, .blue, .purple, .red],
                                center: .center
                            )
                        )
                        .frame(width: 52, height: 52)
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                }
                BuxCatalogDynamicText(key: "Custom")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(themeManager.labelPrimary(for: colorScheme))
            }
            .frame(width: 64)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Custom colors")
    }

    private func presetButton(_ preset: (name: String, palette: ProBusinessCardPalette)) -> some View {
        let selected = design.palette == preset.palette
        return Button {
            onSelect(preset.palette)
        } label: {
            VStack(spacing: 6) {
                ProBusinessCardPaletteSwatch(palette: preset.palette, selected: selected)
                Text(preset.name)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(themeManager.labelPrimary(for: colorScheme))
                    .lineLimit(1)
            }
            .frame(width: 64)
        }
        .buttonStyle(.plain)
    }
}

struct ProBusinessCardPaletteSwatch: View {
    @EnvironmentObject private var themeManager: ThemeManager

    let palette: ProBusinessCardPalette
    var selected: Bool = false

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                Color(hex: palette.accentHex)
                Color(hex: palette.backgroundHex)
                Color(hex: palette.foregroundHex)
            }
            .frame(width: 52, height: 52)
            .clipShape(Circle())

            if selected {
                Circle()
                    .strokeBorder(themeManager.current.accentColor, lineWidth: 3)
                    .frame(width: 56, height: 56)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
            }
        }
        .frame(width: 58, height: 58)
    }
}

// MARK: - Custom color sheet

struct ProBusinessCardCustomColorSheet: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager

    @State private var accent: Color
    @State private var background: Color
    @State private var foreground: Color

    let onApply: (ProBusinessCardPalette) -> Void

    init(palette: ProBusinessCardPalette, onApply: @escaping (ProBusinessCardPalette) -> Void) {
        _accent = State(initialValue: Color(hex: palette.accentHex))
        _background = State(initialValue: Color(hex: palette.backgroundHex))
        _foreground = State(initialValue: Color(hex: palette.foregroundHex))
        self.onApply = onApply
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: BuxTokens.block) {
                    previewStrip
                    colorWheelSection(title: "Accent", binding: $accent, icon: "paintbrush.fill")
                    colorWheelSection(title: "Background", binding: $background, icon: "square.fill")
                    colorWheelSection(title: "Text", binding: $foreground, icon: "textformat")
                }
                .padding(BuxTokens.marginRegular)
            }
            .background(themeManager.screenBackground(for: colorScheme).ignoresSafeArea())
            .buxCatalogNavigationTitle("Custom palette")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        onApply(
                            ProBusinessCardPalette(
                                accentHex: accent.buxHexString,
                                backgroundHex: background.buxHexString,
                                foregroundHex: foreground.buxHexString
                            )
                        )
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var previewStrip: some View {
        HStack(spacing: 0) {
            accent.frame(maxWidth: .infinity, maxHeight: .infinity)
            background.frame(maxWidth: .infinity, maxHeight: .infinity)
            foreground.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: 72)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        }
    }

    private func colorWheelSection(title: String, binding: Binding<Color>, icon: String) -> some View {
        BuxThemedCardForm {
            BuxFormSection(title: title) {
                HStack(spacing: 14) {
                    Label(title, systemImage: icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(themeManager.labelPrimary(for: colorScheme))
                    Spacer(minLength: 0)
                    Circle()
                        .fill(binding.wrappedValue)
                        .frame(width: 36, height: 36)
                        .overlay(Circle().strokeBorder(Color.primary.opacity(0.12), lineWidth: 1))
                }
                .buxFormFieldPadding()
                BuxFormRowDivider()
                ColorPicker("\(title) color", selection: binding, supportsOpacity: false)
                    .labelsHidden()
                    .buxFormFieldPadding()
            }
        }
    }
}

private extension Color {
    var buxHexString: String {
        UIColor(self).buxHexString
    }
}

private extension UIColor {
    var buxHexString: String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}
