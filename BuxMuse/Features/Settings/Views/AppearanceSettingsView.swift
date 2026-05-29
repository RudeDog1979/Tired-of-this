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
    @ObservedObject private var store = SettingsStore.shared
    
    private var bgColor: Color {
        themeManager.screenBackground(for: colorScheme)
    }

    let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var body: some View {
        ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {

                    if store.brandThemesEnabled {
                        VStack(alignment: .leading, spacing: 12) {
                            BuxSectionHeader(title: "Brand design presets")
                                .padding(.horizontal, 20)

                            LazyVGrid(columns: columns, spacing: 16) {
                                ForEach(AppTheme.all) { theme in
                                    ThemeSwatchCard(theme: theme, isSelected: themeManager.current.id == theme.id) {
                                        themeManager.select(theme)
                                        store.accentColorId = theme.name
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
                                    Text("Brand Themes")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                                    Text("Colorful mesh presets and accent styling across the app")
                                        .font(.system(size: 11))
                                        .buxLabelSecondary()
                                }
                            }
                            .padding(.horizontal, BuxLayout.section)
                            .padding(.vertical, 12)

                            Divider().opacity(0.08)

                            // Theme mode selector
                            HStack {
                                Text("Display Mode")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                                Spacer()
                                Picker("Display Mode", selection: $store.themeMode) {
                                    ForEach(ThemeMode.allCases) { mode in
                                        Text(mode.rawValue).tag(mode)
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                            .padding(.horizontal, BuxLayout.section)
                            .padding(.vertical, 14)
                            
                            Divider().opacity(0.08)
                            
                            // Glassmorphism Toggle
                            Toggle(isOn: $store.useGlassmorphism) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Glass navigation chrome")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                                    Text("Liquid Glass tab bar and icon buttons (cards stay mesh-tinted)")
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
                                    Text("Reduced Motion")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                                    Text("Simplify transition animations for comfort")
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
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            store.applyBrandThemesAppearance(to: themeManager)
        }
        .onChange(of: store.themeMode) { _, _ in store.save() }
        .onChange(of: store.useGlassmorphism) { _, _ in store.save() }
        .onChange(of: store.reducedMotion) { _, _ in store.save() }
        .onChange(of: store.brandThemesEnabled) { _, enabled in
            store.applyBrandThemesAppearance(to: themeManager)
            store.save()
        }
    }
}
