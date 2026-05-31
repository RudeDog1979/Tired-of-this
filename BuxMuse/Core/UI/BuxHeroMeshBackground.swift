//
//  BuxHeroMeshBackground.swift
//  BuxMuse
//
//  Theme-based aurora wash — 2-color diagonal gradient from hero palette.
//  Card tints (DashboardThemeTint) and brand settings are unchanged.
//

import SwiftUI

/// Subtle accent wash for tab landing pages — light and dark only; theme accent unchanged.
struct BuxLandingTintBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        ZStack {
            themeManager.screenBackground(for: colorScheme)
            BuxThemeAccentWash(theme: themeManager.current, colorScheme: colorScheme)
        }
        .animation(BuxMotion.themeCrossfade, value: themeManager.current.id)
    }
}

extension View {
    /// Premium landing backdrop — M3 surface + subtle accent gradient (Home, Studio, Expenses, Settings).
    func buxLandingScreenBackground() -> some View {
        background(BuxLandingTintBackground().ignoresSafeArea())
    }
}

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
        // Always use the deep dark theme gradient colors to keep it rich and deep even in light mode
        let pair = themeManager.current.heroDarkGradient
        let lead = pair.first ?? themeManager.current.accentColor
        let trail = pair.dropFirst().first ?? themeManager.current.glowColor

        // High opacity to give that deep, rich, saturated look
        let leadOpacity = 0.85
        let trailOpacity = 0.60

        LinearGradient(
            colors: [
                lead.opacity(leadOpacity),
                trail.opacity(trailOpacity),
                Color.black.opacity(0.85) // Rich midnight black blend
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .allowsHitTesting(false)
        .mask {
            LinearGradient(
                colors: [.black, .black.opacity(0.85), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea(edges: .top)
    }
}
