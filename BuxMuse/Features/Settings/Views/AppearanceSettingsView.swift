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
    @ObservedObject private var store = SettingsStore.shared

    private var glassChromeSubtitle: String {
        BuxCatalogLabel.string(
            store.brandThemesEnabled
                ? "Liquid Glass tab bar and icon buttons (cards stay mesh-tinted)"
                : "Liquid Glass tab bar and icon buttons (cards stay neutral)",
            locale: appSettingsManager.interfaceLocale
        )
    }

    var body: some View {
        BuxThemedCardForm {
            if store.brandThemesEnabled {
                VStack(alignment: .leading, spacing: BuxLayout.tight) {
                    BuxFormSectionLabel(title: "Brand design presets")
                    BuxThemePickerCarousel()
                }
            } else {
                BuxFormSection(title: "Accent color") {
                    BuxAccentPickerCarousel()
                }
            }

            BuxFormSection(title: "Interface") {
                BuxSettingsToggleRow(
                    titleKey: "Brand themes",
                    subtitleKey: "Full themed surfaces and presets — off uses standard iOS light/dark",
                    isOn: $store.brandThemesEnabled
                )

                BuxFormRowDivider()

                BuxSettingsMenuPickerRow(titleKey: "Display mode", selection: $store.themeMode) {
                    ForEach(ThemeMode.allCases) { mode in
                        Text(mode.catalogLabel(locale: appSettingsManager.interfaceLocale)).tag(mode)
                    }
                }

                if !store.brandThemesEnabled {
                    BuxFormRowDivider()

                    BuxSettingsToggleRow(
                        titleKey: "Landing backdrop glow",
                        subtitleKey: "Top-left ambient light and card edge shine — off uses plain iOS surfaces",
                        isOn: $store.landingBackdropEnabled
                    )
                }

                BuxFormRowDivider()

                BuxSettingsToggleRow(
                    titleKey: "Glass navigation chrome",
                    subtitleText: glassChromeSubtitle,
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
        }
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
        .onChange(of: store.brandThemesEnabled) { _, enabled in
            store.applyBrandThemesAppearance(to: themeManager)
            store.save()
        }
        .onChange(of: store.landingBackdropEnabled) { _, _ in store.save() }
        .onChange(of: store.greetingHeaderEnabled) { _, _ in store.save() }
        .onChange(of: store.greetingShowIcon) { _, _ in store.save() }
        .onChange(of: store.greetingFontStyle) { _, _ in store.save() }
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
