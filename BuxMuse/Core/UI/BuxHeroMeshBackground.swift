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
    @ObservedObject private var settings = SettingsStore.shared

    var body: some View {
        ZStack {
            themeManager.screenBackground(for: colorScheme)
            if settings.brandThemesEnabled {
                BuxThemeAccentWash(theme: themeManager.current, colorScheme: colorScheme)
            } else if settings.landingBackdropEnabled {
                BuxNeutralLandingWash(
                    colorScheme: colorScheme,
                    accent: settings.resolvedSystemAccentColor(for: colorScheme)
                )
            }
        }
        .animation(BuxMotion.themeCrossfade, value: themeManager.current.id)
    }
}

/// Neutral landing wash — strong top-leading light, fading gradually; cards stay native (rim shine only).
struct BuxNeutralLandingWash: View {
    let colorScheme: ColorScheme
    let accent: Color

    private var isDark: Bool { colorScheme == .dark }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.white.opacity(isDark ? 0.34 : 0.92),
                    Color.white.opacity(isDark ? 0.18 : 0.58),
                    Color.white.opacity(isDark ? 0.06 : 0.18),
                    Color.clear
                ],
                startPoint: UnitPoint(x: 0, y: 0),
                endPoint: UnitPoint(x: 1, y: 1)
            )

            RadialGradient(
                colors: [
                    accent.opacity(isDark ? 0.32 : 0.20),
                    accent.opacity(isDark ? 0.10 : 0.07),
                    Color.clear
                ],
                center: UnitPoint(x: 0, y: 0),
                startRadius: 0,
                endRadius: isDark ? 720 : 640
            )

            LinearGradient(
                colors: [
                    Color.clear,
                    Color.white.opacity(isDark ? 0.03 : 0.06)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .allowsHitTesting(false)
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
        let pair = themeManager.current.heroDarkGradient
        let lead = pair.first ?? themeManager.current.accentColor
        let trail = pair.dropFirst().first ?? themeManager.current.glowColor

        let leadOpacity = 0.85
        let trailOpacity = 0.60

        LinearGradient(
            colors: [
                lead.opacity(leadOpacity),
                trail.opacity(trailOpacity),
                Color.black.opacity(0.85)
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
