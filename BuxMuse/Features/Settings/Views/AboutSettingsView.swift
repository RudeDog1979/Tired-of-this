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
    @ObservedObject private var store = SettingsStore.shared
    
    private var bgColor: Color {
        themeManager.screenBackground(for: colorScheme)
    }
    
    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    
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
                            Text("BuxMuse")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(colorScheme == .dark ? .white : .black)
                            Text("Your Premium Offline Co-pilot")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.gray)
                        }
                        
                        Text("Version 1.0.0 (Build 26)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.gray.opacity(0.7))
                    }
                    
                    // Privacy Manifesto
                    VStack(alignment: .leading, spacing: 12) {
                        Text("PRIVACY MANIFESTO")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.gray)
                            .padding(.horizontal, 20)
                            .kerning(1.2)
                        
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "checkmark.shield.fill")
                                    .foregroundColor(.green)
                                Text("100% on-device local sandbox parsing. Your bank statements and scanned documents never touch the cloud.")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(colorScheme == .dark ? .white : .black)
                            }
                            
                            Divider().padding(.vertical, 4)
                            
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "network.slash")
                                    .foregroundColor(.red)
                                Text("Zero network analytics trackers. Zero external APIs. BuxMuse operates fully private and autonomous.")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(colorScheme == .dark ? .white : .black)
                            }
                        }
                        .padding(20)
                        .background(colorScheme == .dark ? Color(red: 24/255, green: 26/255, blue: 32/255) : .white)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(colorScheme == .dark ? Color.white.opacity(0.04) : Color.black.opacity(0.03), lineWidth: 1)
                        )
                        .padding(.horizontal, 20)
                    }
                    
                    // Advanced Developer Diagnostics
                    VStack(alignment: .leading, spacing: 12) {
                        Text("ADVANCED DIAGNOSTICS")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.gray)
                            .padding(.horizontal, 20)
                            .kerning(1.2)
                        
                        VStack(spacing: 0) {
                            Toggle("Enable Debug Diagnostics Overlay", isOn: $store.enableDebugOverlay)
                                .padding(.horizontal, BuxLayout.section)
                                .padding(.vertical, 12)
                            
                            Divider().opacity(0.08)
                            
                            Toggle("Show FPS & Cache Latency", isOn: $store.showPerformanceMetrics)
                                .padding(.horizontal, BuxLayout.section)
                                .padding(.vertical, 12)
                        }
                        .background(colorScheme == .dark ? Color(red: 24/255, green: 26/255, blue: 32/255) : .white)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(colorScheme == .dark ? Color.white.opacity(0.04) : Color.black.opacity(0.03), lineWidth: 1)
                        )
                        .padding(.horizontal, 20)
                    }
                }
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: store.enableDebugOverlay) { _, _ in store.save() }
        .onChange(of: store.showPerformanceMetrics) { _, _ in store.save() }
    }
}
