//
//  AboutSettingsView.swift
//  BuxMuse
//
//  Credits, offline privacy agreement, and advanced developer diagnostics.
//

import SwiftUI

struct AboutSettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @ObservedObject private var store = SettingsStore.shared
    
    private var bgColor: Color {
        themeManager.screenBackground(for: colorScheme)
    }

    private var appVersionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        let format = BuxCatalogLabel.string("Version %@ (Build %@)", locale: appSettingsManager.interfaceLocale)
        return String(format: format, version, build)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
                VStack(spacing: BuxTokens.block) {
                    
                    // Brand Header
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(themeManager.current.accentColor.opacity(0.12))
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: "banknote.fill")
                                .font(.system(size: 38))
                                .foregroundColor(themeManager.current.accentColor)
                        }
                        .padding(.top, 24)
                        
                        VStack(spacing: 4) {
                            BuxCatalogDynamicText(key: "BuxMuse")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                            BuxCatalogDynamicText(key: "Your premium offline co-pilot")
                                .font(.system(size: 13, weight: .semibold))
                                .buxLabelSecondary()
                        }
                        
                        Text(appVersionString)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.gray.opacity(0.7))
                    }
                    
                    // Privacy Manifesto
                    VStack(alignment: .leading, spacing: 12) {
                        BuxSectionHeader(title: "Privacy")
                            .padding(.horizontal, 20)
                        
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "checkmark.shield.fill")
                                    .foregroundColor(.green)
                                BuxCatalogDynamicText(key: "100% on-device local sandbox parsing. Your bank statements and scanned documents never touch the cloud.")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                            }
                            
                            Divider().padding(.vertical, 4)
                            
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "network.slash")
                                    .foregroundColor(.red)
                                BuxCatalogDynamicText(key: "Zero network analytics trackers. Zero external APIs. BuxMuse operates fully private and autonomous.")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                            }
                        }
                        .padding(20)
                        .settingsThemedCardChrome(cornerRadius: 20)
                        .padding(.horizontal, 20)
                    }
                    
                    // Advanced Developer Diagnostics
                    VStack(alignment: .leading, spacing: 12) {
                        BuxSectionHeader(title: "Advanced diagnostics")
                            .padding(.horizontal, 20)
                        
                        VStack(spacing: 0) {
                            Toggle(isOn: $store.enableDebugOverlay) {
                                Text(BuxCatalogLabel.string("Enable debug diagnostics overlay", locale: appSettingsManager.interfaceLocale))
                            }
                            .padding(.horizontal, BuxLayout.section)
                            .padding(.vertical, 12)
                            
                            Divider().opacity(0.08)
                            
                            Toggle(isOn: $store.showPerformanceMetrics) {
                                Text(BuxCatalogLabel.string("Show FPS & cache latency", locale: appSettingsManager.interfaceLocale))
                            }
                            .padding(.horizontal, BuxLayout.section)
                            .padding(.vertical, 12)
                        }
                        .settingsThemedCardChrome(cornerRadius: 20)
                        .padding(.horizontal, 20)
                    }
                }
                .padding(.bottom, 40)
            }
            .buxScrollContentMargins()
            .buxSoftScrollChrome()
        .buxCatalogNavigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: store.enableDebugOverlay) { _, _ in store.save() }
        .onChange(of: store.showPerformanceMetrics) { _, _ in store.save() }
    }
}
