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
    
    private var bgColor: Color {
        themeManager.screenBackground(for: colorScheme)
    }

    let themeColumns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    let accentColumns = [
        GridItem(.adaptive(minimum: 56), spacing: 12)
    ]
    
    var body: some View {
        ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {

                    if store.brandThemesEnabled {
                        VStack(alignment: .leading, spacing: 12) {
                            BuxSectionHeader(title: "Brand design presets")
                                .padding(.horizontal, 20)

                            LazyVGrid(columns: themeColumns, spacing: 16) {
                                ForEach(AppTheme.all) { theme in
                                    ThemeSwatchCard(theme: theme, isSelected: themeManager.current.id == theme.id) {
                                        store.persistThemeSelection(theme, themeManager: themeManager)
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        .padding(.top, 16)
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            BuxSectionHeader(title: "Accent color")
                                .padding(.horizontal, 20)

                            BuxCatalogDynamicText(key: "Neutral Apple surfaces with your chosen accent on buttons and controls.")
                                .font(.system(size: 12))
                                .foregroundColor(themeManager.labelSecondary(for: colorScheme))
                                .padding(.horizontal, 20)

                            LazyVGrid(columns: accentColumns, spacing: 12) {
                                ForEach(BuxSystemAccent.allCases) { accent in
                                    AccentSwatchButton(
                                        accent: accent,
                                        isSelected: store.neutralAccentId == accent.rawValue
                                    ) {
                                        store.neutralAccentId = accent.rawValue
                                        store.save()
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        .padding(.top, 16)
                    }

                    // UI Preference Rules
                    VStack(alignment: .leading, spacing: 12) {
                        BuxSectionHeader(title: "Interface")
                            .padding(.horizontal, 20)
                        
                        VStack(spacing: 0) {
                            Toggle(isOn: $store.brandThemesEnabled) {
                                VStack(alignment: .leading, spacing: 2) {
                                    BuxCatalogDynamicText(key: "Brand Themes")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                                    BuxCatalogDynamicText(key: "Full themed surfaces and presets — off uses standard iOS light/dark")
                                        .font(.system(size: 11))
                                        .buxLabelSecondary()
                                }
                            }
                            .padding(.horizontal, BuxLayout.section)
                            .padding(.vertical, 12)

                            Divider().opacity(0.08)

                            // Theme mode selector
                            HStack {
                                BuxCatalogDynamicText(key: "Display Mode")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                                Spacer()
                                Picker("Display Mode", selection: $store.themeMode) {
                                    ForEach(ThemeMode.allCases) { mode in
                                        Text(mode.catalogLabel(locale: appSettingsManager.interfaceLocale)).tag(mode)
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                            .padding(.horizontal, BuxLayout.section)
                            .padding(.vertical, 14)
                            
                            Divider().opacity(0.08)

                            if !store.brandThemesEnabled {
                                Toggle(isOn: $store.landingBackdropEnabled) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        BuxCatalogDynamicText(key: "Landing backdrop glow")
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                                        BuxCatalogDynamicText(key: "Top-left ambient light and card edge shine — off uses plain iOS surfaces")
                                            .font(.system(size: 11))
                                            .buxLabelSecondary()
                                    }
                                }
                                .padding(.horizontal, BuxLayout.section)
                                .padding(.vertical, 12)

                                Divider().opacity(0.08)
                            }

                            // Glassmorphism Toggle
                            Toggle(isOn: $store.useGlassmorphism) {
                                VStack(alignment: .leading, spacing: 2) {
                                    BuxCatalogDynamicText(key: "Glass navigation chrome")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                                    Text(store.brandThemesEnabled
                                         ? "Liquid Glass tab bar and icon buttons (cards stay mesh-tinted)"
                                         : "Liquid Glass tab bar and icon buttons (cards stay neutral)")
                                        .font(.system(size: 11))
                                        .foregroundColor(themeManager.labelSecondary(for: colorScheme))
                                }
                            }
                            .padding(.horizontal, BuxLayout.section)
                            .padding(.vertical, 12)
                            
                            Divider().opacity(0.08)
                            
                            // Reduced Motion Toggle
                            Toggle(isOn: $store.reducedMotion) {
                                VStack(alignment: .leading, spacing: 2) {
                                    BuxCatalogDynamicText(key: "Reduced Motion")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                                    BuxCatalogDynamicText(key: "Simplify transition animations for comfort")
                                        .font(.system(size: 11))
                                        .buxLabelSecondary()
                                }
                            }
                            .padding(.horizontal, BuxLayout.section)
                            .padding(.vertical, 12)
                            
                            Divider().opacity(0.08)
                            
                            // Solar Contrast Mode Toggle
                            Toggle(isOn: $store.solarContrastModeEnabled) {
                                VStack(alignment: .leading, spacing: 2) {
                                    BuxCatalogDynamicText(key: "Solar Contrast Mode")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                                    BuxCatalogDynamicText(key: "Optimize contrast and text weight for direct tropical sunlight")
                                        .font(.system(size: 11))
                                        .buxLabelSecondary()
                                }
                            }
                            .padding(.horizontal, BuxLayout.section)
                            .padding(.vertical, 12)
                        }
                        .settingsThemedCardChrome(cornerRadius: 20)
                        .padding(.horizontal, 20)
                    }
                }
            }
            .buxScrollContentMargins()
            .buxSoftScrollChrome()
        .buxCatalogNavigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            store.applyBrandThemesAppearance(to: themeManager)
        }
        .onChange(of: store.themeMode) { _, _ in store.save() }
        .onChange(of: store.useGlassmorphism) { _, _ in store.save() }
        .onChange(of: store.reducedMotion) { _, _ in store.save() }
        .onChange(of: store.solarContrastModeEnabled) { _, _ in store.save() }
        .onChange(of: store.neutralAccentId) { _, _ in
            store.applyBrandThemesAppearance(to: themeManager)
            store.save()
        }
        .onChange(of: store.brandThemesEnabled) { _, enabled in
            store.applyBrandThemesAppearance(to: themeManager)
            store.save()
        }
        .onChange(of: store.landingBackdropEnabled) { _, _ in store.save() }
    }
}

// MARK: - Accent swatch (neutral mode)

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
        .buttonStyle(.plain)
    }
}
