//
//  BuxHeroMeshBackground.swift
//  BuxMuse
//
//  Theme-based aurora wash — 2-color diagonal gradient from hero palette.
//  Card tints (DashboardThemeTint) and brand settings are unchanged.
//

import SwiftUI

/// Hero mesh backdrop — hidden when brand themes are off in Settings.
struct BuxThemedBackdrop: View {
    var opacity: Double = 1

    var body: some View {
        BuxHeroMeshBackground()
            .opacity(opacity)
    }
}

struct BuxHeroMeshBackground: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject private var settings = SettingsStore.shared

    var body: some View {
        if settings.brandThemesEnabled {
            auroraWash
        }
    }

    @ViewBuilder
    private var auroraWash: some View {
        let pair = colorScheme == .dark
            ? themeManager.current.heroDarkGradient
            : themeManager.current.heroLightGradient

        let lead = pair.first ?? themeManager.current.accentColor
        let trail = pair.dropFirst().first ?? themeManager.current.glowColor

        let leadOpacity = colorScheme == .dark ? 0.40 : 0.26
        let trailOpacity = colorScheme == .dark ? 0.22 : 0.13

        LinearGradient(
            colors: [
                lead.opacity(leadOpacity),
                trail.opacity(trailOpacity)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .allowsHitTesting(false)
        .mask {
            LinearGradient(
                colors: [.black, .black.opacity(0.75), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea(edges: .top)
    }
}
