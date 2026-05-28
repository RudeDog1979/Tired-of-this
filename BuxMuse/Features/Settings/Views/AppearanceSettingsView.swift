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
        ZStack {
            bgColor.ignoresSafeArea()
            BuxThemedBackdrop()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {

                    if store.brandThemesEnabled {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("BRAND DESIGN PRESETS")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.gray)
                                .padding(.horizontal, 20)
                                .kerning(1.2)

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
                        Text("USER INTERFACE RULES")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.gray)
                            .padding(.horizontal, 20)
                            .kerning(1.2)
                        
                        VStack(spacing: 0) {
                            Toggle(isOn: $store.brandThemesEnabled) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Brand Themes")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                                    Text("Colorful mesh presets and accent styling across the app")
                                        .font(.system(size: 11))
                                        .foregroundColor(.gray)
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
                                    Text("Frosted Glassmorphism")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                                    Text("Premium backdrop filters and transparency effects")
                                        .font(.system(size: 11))
                                        .foregroundColor(.gray)
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
                                        .foregroundColor(.gray)
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
        }
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
