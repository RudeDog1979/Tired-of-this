//
//  BuxDesignerColorPickerSheet.swift
//  BuxMuse — full color + opacity designer sheet
//

import SwiftUI

struct BuxDesignerColorPickerSheet: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager

    let title: String
    let initialHex: String
    var brandPalette: ProBusinessCardPalette?
    var layerOpacity: Binding<Double>?
    let onCommit: (String) -> Void

    @State private var hexDraft: String
    @State private var colorAlpha: Double

    init(
        title: String,
        initialHex: String,
        brandPalette: ProBusinessCardPalette? = nil,
        layerOpacity: Binding<Double>? = nil,
        onCommit: @escaping (String) -> Void
    ) {
        self.title = title
        self.initialHex = initialHex
        self.brandPalette = brandPalette
        self.layerOpacity = layerOpacity
        self.onCommit = onCommit
        _hexDraft = State(initialValue: initialHex.uppercased())
        _colorAlpha = State(initialValue: BuxDesignerColorCodec.colorOpacity(from: initialHex))
    }

    private var controlTint: Color {
        themeManager.contrastAccentColor(for: colorScheme)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: BuxTokens.section) {
                    previewCard
                    wheelSection
                    hexSection
                    colorAlphaSection
                    if let layerOpacity {
                        layerOpacitySection(layerOpacity)
                    }
                    if let brandPalette {
                        brandSection(brandPalette)
                    }
                    presetGroupsSection
                    recentsSection
                }
                .padding(.horizontal, BuxTokens.marginRegular)
                .padding(.vertical, BuxTokens.section)
            }
            .background(themeManager.screenBackground(for: colorScheme))
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") { applyAndDismiss() }
                        .fontWeight(.semibold)
                }
            }
            .onChange(of: colorAlpha) { _, newAlpha in
                applyAlpha(newAlpha)
            }
        }
        .buxRootBrandTheme()
    }

    private var previewCard: some View {
        BuxThemedCardForm {
            HStack(spacing: 14) {
                BuxDesignerColorWell(hex: previewHex, size: 56, showsRing: true)

                VStack(alignment: .leading, spacing: 6) {
                    Text(hexDraft)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    Text("Fill strength \(Int(colorAlpha * 100))%")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    if let layerOpacity {
                        Text("Layer visibility \(Int(layerOpacity.wrappedValue * 100))%")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    Text("Preview matches how the shape will look on the card.")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
                Spacer(minLength: 0)
            }
            .padding(BuxTokens.marginRegular)
        }
    }

    private var previewHex: String {
        BuxDesignerColorCodec.hexByUpdatingAlpha(
            BuxDesignerColorCodec.rgbHex(from: hexDraft),
            alpha: colorAlpha
        )
    }

    private var wheelSection: some View {
        VStack(alignment: .leading, spacing: BuxLayout.tight) {
            BuxFormSectionLabel(title: "Color wheel")
            VStack(spacing: 10) {
                BuxDesignerHSBControls(hex: $hexDraft, alpha: $colorAlpha, accent: controlTint)
                Text("Drag the field for saturation and brightness — use Fill strength for transparency.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
            .buxFormFieldPadding()
            .frame(maxWidth: .infinity)
            .buxFormSectionCard()
        }
    }

    private var hexSection: some View {
        BuxThemedCardForm {
            BuxFormSection(title: "Hex") {
                HStack(spacing: 10) {
                    TextField("#RRGGBB or #AARRGGBB", text: $hexDraft)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .onSubmit { applyHexDraft() }
                    Button("Set") { applyHexDraft() }
                        .font(.system(size: 13, weight: .bold))
                        .buxNativeButtonStyle(.secondary)
                        .foregroundStyle(controlTint)
                }
                .buxFormFieldPadding()
            }
        }
    }

    private var colorAlphaSection: some View {
        BuxThemedCardForm {
            BuxFormSection(title: "Fill strength") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 12) {
                        BuxDesignerColorWell(hex: previewHex, size: 32)
                        Slider(value: $colorAlpha, in: 0...1)
                            .tint(controlTint)
                    }
                    HStack {
                        Text("Clear")
                        Spacer()
                        Text("\(Int(colorAlpha * 100))%")
                            .fontWeight(.semibold)
                        Spacer()
                        Text("Solid")
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                }
                .buxFormFieldPadding()
            }
        }
    }

    private func layerOpacitySection(_ binding: Binding<Double>) -> some View {
        BuxThemedCardForm {
            BuxFormSection(title: "Layer fade") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Fades the whole element — text, shape, or photo.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    Slider(value: binding, in: 0.05...1)
                        .tint(controlTint)
                    Text("\(Int(binding.wrappedValue * 100))% visible")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .buxFormFieldPadding()
            }
        }
    }

    private func brandSection(_ palette: ProBusinessCardPalette) -> some View {
        swatchSection(title: "Your brand", swatches: BuxDesignerColorPresets.swatches(for: palette))
    }

    private var presetGroupsSection: some View {
        ForEach(BuxDesignerColorPresets.groups) { group in
            swatchSection(title: group.title, swatches: group.colors.map { ($0, $0) })
        }
    }

    @ViewBuilder
    private var recentsSection: some View {
        let recents = BuxDesignerColorRecents.all
        if !recents.isEmpty {
            swatchSection(title: "Recent", swatches: recents.map { ($0, $0) })
        }
    }

    private func swatchSection(title: String, swatches: [(String, String)]) -> some View {
        BuxThemedCardForm {
            BuxFormSection(title: title) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 36), spacing: 10)], spacing: 10) {
                    ForEach(swatches, id: \.1) { label, hex in
                        swatchButton(label: label, hex: hex)
                    }
                }
                .buxFormFieldPadding()
            }
        }
    }

    private func swatchButton(label: String, hex: String) -> some View {
        let selected = hexDraft.uppercased() == hex.uppercased()
        return Button {
            applyHex(hex)
        } label: {
            VStack(spacing: 4) {
                BuxDesignerColorWell(hex: hex, size: 32, showsRing: selected)
                Text(label.count > 10 ? String(label.prefix(7)) + "…" : label)
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }

    private func applyHexDraft() {
        var raw = hexDraft.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if !raw.hasPrefix("#") { raw = "#" + raw }
        applyHex(raw)
    }

    private func applyHex(_ hex: String) {
        hexDraft = hex.uppercased()
        colorAlpha = BuxDesignerColorCodec.colorOpacity(from: hexDraft)
    }

    private func applyAlpha(_ alpha: Double) {
        let next = BuxDesignerColorCodec.hexByUpdatingAlpha(
            BuxDesignerColorCodec.rgbHex(from: hexDraft),
            alpha: alpha
        )
        guard next.uppercased() != hexDraft.uppercased() else { return }
        hexDraft = next
    }

    private func applyAndDismiss() {
        let hex = BuxDesignerColorCodec.hexByUpdatingAlpha(
            BuxDesignerColorCodec.rgbHex(from: hexDraft),
            alpha: colorAlpha
        )
        BuxDesignerColorRecents.remember(hex)
        onCommit(hex)
        dismiss()
    }
}

// MARK: - Toolbar trigger

struct BuxDesignerColorToolbarButton: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager

    let title: String
    let hex: String
    var brandPalette: ProBusinessCardPalette?
    var layerOpacity: Binding<Double>?
    let onPick: (String) -> Void

    @State private var showSheet = false

    private var controlTint: Color {
        themeManager.contrastAccentColor(for: colorScheme)
    }

    var body: some View {
        Button { showSheet = true } label: {
            HStack(spacing: 6) {
                BuxDesignerColorWell(hex: hex, size: 22)
                Text(title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(controlTint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showSheet) {
            BuxDesignerColorPickerSheet(
                title: title,
                initialHex: hex,
                brandPalette: brandPalette,
                layerOpacity: layerOpacity,
                onCommit: onPick
            )
            .environmentObject(themeManager)
        }
    }

}

// MARK: - Form row (background editor)

struct BuxDesignerColorFormRow: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme

    let title: String
    @Binding var hex: String
    var brandPalette: ProBusinessCardPalette?
    var onChange: () -> Void

    @State private var showSheet = false

    var body: some View {
        Button {
            showSheet = true
        } label: {
            HStack {
                Text(title)
                    .foregroundStyle(themeManager.labelPrimary(for: colorScheme))
                Spacer()
                swatch
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .sheet(isPresented: $showSheet) {
            BuxDesignerColorPickerSheet(
                title: title,
                initialHex: hex,
                brandPalette: brandPalette,
                onCommit: { newHex in
                    hex = newHex
                    onChange()
                }
            )
            .environmentObject(themeManager)
        }
    }

    private var swatch: some View {
        BuxDesignerColorWell(hex: hex, size: 28)
    }
}
