//
//  AppearanceSettingsView.swift
//  BuxMuse
//
//  Appearance and branding customization console.
//

import SwiftUI

struct AppearanceSettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @EnvironmentObject private var tutorialCoordinator: AppTutorialCoordinator
    @ObservedObject private var store = SettingsStore.shared

    private var landingBackdropLockedByBrandThemes: Bool {
        store.brandThemesEnabled
    }

    private var landingBackdropBinding: Binding<Bool> {
        Binding(
            get: {
                if landingBackdropLockedByBrandThemes { return true }
                return store.landingBackdropEnabled
            },
            set: { newValue in
                guard !landingBackdropLockedByBrandThemes else { return }
                store.landingBackdropEnabled = newValue
            }
        )
    }

    var body: some View {
        BuxThemedCardForm {
            themePresetPicker

            appearanceSectionsBelowThemePicker
        }
        .tutorialAnchor(.settingsAppearanceDetail, coordinator: tutorialCoordinator)
        .buxCatalogNavigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            store.applyBrandThemesAppearance(to: themeManager)
        }
        .onChange(of: store.themeMode) { _, _ in store.save() }
        .onChange(of: store.useGlassmorphism) { _, _ in store.save() }
        .onChange(of: store.reducedMotion) { _, _ in store.save() }
        .onChange(of: store.solarContrastModeEnabled) { _, _ in store.save() }
        .onChange(of: store.showVisualHorizonBackground) { _, _ in store.save() }
        .onChange(of: store.neutralAccentId) { _, _ in
            store.applyBrandThemesAppearance(to: themeManager)
            store.save()
        }
        .onChange(of: store.brandThemesEnabled) { _, _ in
            store.applyBrandThemesAppearance(to: themeManager)
            store.save()
        }
        .onChange(of: store.landingBackdropEnabled) { _, _ in store.save() }
        .onChange(of: store.greetingHeaderEnabled) { _, _ in store.save() }
        .onChange(of: store.greetingShowIcon) { _, _ in store.save() }
        .onChange(of: store.greetingFontStyle) { _, _ in store.save() }
    }

    private var brandThemesBinding: Binding<Bool> {
        Binding(
            get: { store.brandThemesEnabled },
            set: { newValue in
                withAnimation(BuxMotion.brandThemesToggle) {
                    store.brandThemesEnabled = newValue
                }
            }
        )
    }

    /// Sections below the theme picker — move as one rigid block; row interiors stay locked.
    @ViewBuilder
    private var appearanceSectionsBelowThemePicker: some View {
        VStack(alignment: .leading, spacing: BuxLayout.section) {
            BuxFormSection(title: "Interface") {
                interfaceSectionContent
            }

            if BuxPadIdiom.isPad {
                BuxFormSection(title: "Expense quick actions") {
                    BuxSettingsMenuPickerRow(
                        titleKey: "iPad FAB shortcut",
                        selection: $store.ipadFabShortcut
                    ) {
                        ForEach(DashboardFabPadShortcut.availableShortcuts(studioEnabled: store.studioEnabled)) { shortcut in
                            BuxCatalogDynamicText(key: shortcut.titleKey)
                                .tag(shortcut)
                        }
                    }
                }
            }

            BuxFormSection(title: "Dashboard greeting") {
                greetingSectionContent
            }
        }
        .environment(\.buxInstantAppearanceSectionChrome, true)
        .animation(nil, value: store.brandThemesEnabled)
        .transaction(value: store.brandThemesEnabled) { transaction in
            transaction.disablesAnimations = true
        }
    }

    @ViewBuilder
    private var interfaceSectionContent: some View {
        BuxSettingsToggleRow(
            titleKey: "Brand themes",
            subtitleKey: "Full themed surfaces and presets — off uses standard iOS light/dark",
            isOn: brandThemesBinding
        )

        BuxFormRowDivider()

        BuxSettingsMenuPickerRow(titleKey: "Display mode", selection: $store.themeMode) {
            ForEach(ThemeMode.allCases) { mode in
                Text(mode.catalogLabel(locale: appSettingsManager.interfaceLocale)).tag(mode)
            }
        }

        BuxFormRowDivider()

        AppearanceLandingBackdropToggleRow(
            isLocked: landingBackdropLockedByBrandThemes,
            isOn: landingBackdropBinding,
            neutralSubtitle: BuxCatalogLabel.string(
                "Top-left ambient light and card edge shine — off uses plain iOS surfaces",
                locale: appSettingsManager.interfaceLocale
            ),
            lockedSubtitle: BuxCatalogLabel.string(
                "Included with brand design presets",
                locale: appSettingsManager.interfaceLocale
            )
        )

        BuxFormRowDivider()

        BuxSettingsToggleRow(
            titleKey: "Glass navigation chrome",
            subtitleKey: "Liquid Glass tab bar and icon buttons (cards stay mesh-tinted)",
            isOn: $store.useGlassmorphism
        )

        BuxFormRowDivider()

        BuxSettingsToggleRow(
            titleKey: "Reduced motion",
            subtitleKey: "Simplify transition animations for comfort",
            isOn: $store.reducedMotion
        )

        BuxFormRowDivider()

        BuxSettingsToggleRow(
            titleKey: "Solar contrast mode",
            subtitleKey: "Optimize contrast and text weight for direct tropical sunlight",
            isOn: $store.solarContrastModeEnabled
        )

        BuxFormRowDivider()

        BuxSettingsToggleRow(
            titleKey: "visual horizon background",
            subtitleKey: "show spending trend lines in the dashboard wallet card",
            isOn: $store.showVisualHorizonBackground
        )
    }

    @ViewBuilder
    private var greetingSectionContent: some View {
        BuxSettingsToggleRow(
            titleKey: "Show greeting header on dashboard",
            isOn: $store.greetingHeaderEnabled
        )

        if store.greetingHeaderEnabled {
            BuxFormRowDivider()

            BuxSettingsToggleRow(
                titleKey: "Show greeting icon",
                subtitleKey: "Show animated time icon beside text",
                isOn: $store.greetingShowIcon
            )

            BuxFormRowDivider()

            BuxSettingsMenuPickerRow(titleKey: "Greeting style", selection: $store.greetingFontStyle) {
                ForEach(GreetingFontStyle.allCases) { style in
                    Text(style.localizedDisplayName(locale: appSettingsManager.interfaceLocale)).tag(style)
                }
            }
        }
    }

    @ViewBuilder
    private var themePresetPicker: some View {
        ZStack(alignment: .topLeading) {
            if store.brandThemesEnabled {
                brandPresetPickerSection
                    .transition(appearanceBrandPresetTransition)
            } else {
                accentPresetPickerSection
                    .transition(appearanceAccentPresetTransition)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: BuxAppearancePresetSlot.slotHeight, alignment: .top)
        .compositingGroup()
        .animation(BuxMotion.brandThemesToggle, value: store.brandThemesEnabled)
        .buxProMotionBoost(on: store.brandThemesEnabled)
    }

    /// Brand enters from the right; leaves to the right when accent pushes back.
    private var appearanceBrandPresetTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .trailing).combined(with: .opacity)
        )
    }

    /// Accent enters from the left; leaves to the left when brand pushes in.
    private var appearanceAccentPresetTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .leading).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }

    private var accentPresetPickerSection: some View {
        BuxFormSection(title: "Accent color") {
            BuxAccentPickerCarousel()
        }
    }

    private var brandPresetPickerSection: some View {
        BuxFormSection(title: "Brand design presets") {
            BuxAppearanceThemeRow()
        }
    }
}

// MARK: - Landing backdrop row (fixed subtitle slot — no layout shift on brand toggle)

private enum AppearanceLandingBackdropLayout {
    /// Reserved for two subtitle lines at 12pt — keeps Interface rows from jumping.
    static let subtitleSlotHeight: CGFloat = 34
}

private struct AppearanceLandingBackdropToggleRow: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.buxSettingsUsesStackedRows) private var usesStackedRows
    @EnvironmentObject private var themeManager: ThemeManager

    let isLocked: Bool
    @Binding var isOn: Bool
    let neutralSubtitle: String
    let lockedSubtitle: String

    var body: some View {
        Group {
            if usesStackedRows {
                VStack(alignment: .leading, spacing: 10) {
                    labelBlock
                    Toggle("", isOn: $isOn)
                        .labelsHidden()
                        .tint(themeManager.contrastAccentColor(for: colorScheme))
                }
            } else {
                Toggle(isOn: $isOn) {
                    labelBlock
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .tint(themeManager.contrastAccentColor(for: colorScheme))
            }
        }
        .buxFormFieldPadding()
        .disabled(isLocked)
        .opacity(isLocked ? 0.42 : 1)
    }

    private var labelBlock: some View {
        VStack(alignment: .leading, spacing: 3) {
            BuxCatalogDynamicText(key: "Landing backdrop glow")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(1)

            ZStack(alignment: .topLeading) {
                Text(neutralSubtitle)
                    .opacity(isLocked ? 0 : 1)
                Text(lockedSubtitle)
                    .opacity(isLocked ? 1 : 0)
            }
            .font(.system(size: 12, weight: .medium))
            .buxLabelSecondary()
            .lineLimit(2)
            .minimumScaleFactor(0.85)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, minHeight: AppearanceLandingBackdropLayout.subtitleSlotHeight, alignment: .topLeading)
        }
    }
}

// MARK: - Accent swatch (neutral mode) — preserved for grid layouts

private struct AccentSwatchButton: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    let accent: BuxSystemAccent
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(accent.color(for: colorScheme))
                        .frame(width: 44, height: 44)

                    if isSelected {
                        Circle()
                            .strokeBorder(Color.white, lineWidth: 2.5)
                            .frame(width: 44, height: 44)
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }

                Text(accent.localizedDisplayName(locale: appSettingsManager.interfaceLocale))
                    .font(.system(size: 10, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(isSelected
                        ? themeManager.labelPrimary(for: colorScheme)
                        : themeManager.labelSecondary(for: colorScheme))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buxSettingsRowInteraction()
    }
}
