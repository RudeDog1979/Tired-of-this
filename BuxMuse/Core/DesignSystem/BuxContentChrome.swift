//
//  BuxContentChrome.swift
//  BuxMuse
//
//  Hero vs list card chrome — M3 material surfaces (visual only).
//

import SwiftUI

// MARK: - Landing light rim (accent shine from tinted backdrop)

enum BuxLandingLightRimIntensity {
    case hero
    case card

    func leadOpacity(isDark: Bool) -> Double {
        switch self {
        case .hero: return isDark ? 0.40 : 0.26
        case .card: return isDark ? 0.22 : 0.14
        }
    }

    func midOpacity(isDark: Bool) -> Double {
        switch self {
        case .hero: return isDark ? 0.16 : 0.11
        case .card: return isDark ? 0.09 : 0.06
        }
    }

    func trailOpacity(isDark: Bool) -> Double {
        switch self {
        case .hero: return isDark ? 0.05 : 0.03
        case .card: return isDark ? 0.03 : 0.02
        }
    }

    var lineWidth: CGFloat {
        switch self {
        case .hero: return 1
        case .card: return 0.75
        }
    }

    func glowOpacity(isDark: Bool) -> Double {
        switch self {
        case .hero: return isDark ? 0.18 : 0.11
        case .card: return isDark ? 0.10 : 0.06
        }
    }

    var glowRadius: CGFloat {
        switch self {
        case .hero: return 18
        case .card: return 10
        }
    }

    var glowY: CGFloat {
        switch self {
        case .hero: return 7
        case .card: return 4
        }
    }
}

struct BuxLandingLightRimModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager

    let cornerRadius: CGFloat
    var intensity: BuxLandingLightRimIntensity = .hero

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let accent = themeManager.current.accentColor
        let isDark = colorScheme == .dark
        let themeId = themeManager.current.id

        let rimmed = content.overlay {
            shape.strokeBorder(
                LinearGradient(
                    colors: [
                        accent.opacity(intensity.leadOpacity(isDark: isDark)),
                        accent.opacity(intensity.midOpacity(isDark: isDark)),
                        accent.opacity(intensity.trailOpacity(isDark: isDark)),
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: intensity.lineWidth
            )
            .buxAnimateThemeColors(themeId: themeId)
        }

        // Accent glow shadow — hero cards only (Apple: one shadow layer, no scroll stack).
        if intensity == .hero {
            rimmed.shadow(
                color: accent.opacity(intensity.glowOpacity(isDark: isDark)),
                radius: intensity.glowRadius,
                x: 0,
                y: intensity.glowY
            )
            .buxStableThemeLayout(themeId: themeId)
        } else {
            rimmed
                .buxStableThemeLayout(themeId: themeId)
        }
    }
}

extension View {
    /// Accent rim + soft glow — mimics tinted landing backdrop lighting the card edge.
    func buxLandingLightRim(
        cornerRadius: CGFloat,
        intensity: BuxLandingLightRimIntensity = .hero
    ) -> some View {
        modifier(BuxLandingLightRimModifier(cornerRadius: cornerRadius, intensity: intensity))
    }
}

// MARK: - Hero plate (opaque M3 surface)

struct BuxHeroCardPlateBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    let cornerRadius: CGFloat

    var body: some View {
        BuxThemedCardPlateBackground(cornerRadius: cornerRadius)
    }
}

// MARK: - Modifiers

/// Apple contact + ambient pair — dashboard hero card only (smallest lift, no scroll stack).
private struct BuxHeroDoubleShadowModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var settings = SettingsStore.shared

    func body(content: Content) -> some View {
        if settings.solarContrastModeEnabled {
            content
        } else {
            let isDark = colorScheme == .dark
            content
                .shadow(
                    color: .black.opacity(
                        isDark ? BuxTokens.Shadow.heroContactOpacityDark : BuxTokens.Shadow.heroContactOpacityLight
                    ),
                    radius: BuxTokens.Shadow.heroContactRadius,
                    x: 0,
                    y: BuxTokens.Shadow.heroContactY
                )
                .shadow(
                    color: .black.opacity(
                        isDark ? BuxTokens.Shadow.heroAmbientOpacityDark : BuxTokens.Shadow.heroAmbientOpacityLight
                    ),
                    radius: BuxTokens.Shadow.heroAmbientRadius,
                    x: 0,
                    y: BuxTokens.Shadow.heroAmbientY
                )
        }
    }
}

struct BuxHeroCardChromeModifier: ViewModifier {
    let cornerRadius: CGFloat
    var useMeshPlate: Bool = true
    @ObservedObject private var settings = SettingsStore.shared

    func body(content: Content) -> some View {
        content
            .buxMaterialCardChrome(.elevated, cornerRadius: cornerRadius, castsShadow: false)
            .modifier(BuxHeroDoubleShadowModifier())
            .modifier(BuxLandingLightRimWhenEnabled(
                cornerRadius: cornerRadius,
                enabled: settings.showsLandingCardShine
            ))
    }
}

struct BuxListCardChromeModifier: ViewModifier {
    let cornerRadius: CGFloat
    @ObservedObject private var settings = SettingsStore.shared

    func body(content: Content) -> some View {
        content
            .buxMaterialCardChrome(.outlined, cornerRadius: cornerRadius)
            .modifier(BuxLandingLightRimWhenEnabled(
                cornerRadius: cornerRadius,
                enabled: settings.showsLandingCardShine
            ))
    }
}

struct BuxLandingLightRimWhenEnabled: ViewModifier {
    let cornerRadius: CGFloat
    let enabled: Bool

    func body(content: Content) -> some View {
        if enabled {
            content.buxLandingLightRim(cornerRadius: cornerRadius, intensity: .card)
        } else {
            content
        }
    }
}

extension View {
    /// Hero card — M3 Elevated (one per screen).
    func buxHeroCardChrome(cornerRadius: CGFloat = BuxTokens.Radius.hero, useMeshPlate: Bool = true) -> some View {
        modifier(BuxHeroCardChromeModifier(cornerRadius: cornerRadius, useMeshPlate: useMeshPlate))
    }

    /// List / grid card — M3 Outlined.
    func buxListCardChrome(cornerRadius: CGFloat = BuxTokens.Radius.card) -> some View {
        modifier(BuxListCardChromeModifier(cornerRadius: cornerRadius))
    }

    @ViewBuilder
    func buxCardChrome(tier: BuxCardChromeTier, cornerRadius: CGFloat) -> some View {
        switch tier {
        case .hero:
            buxHeroCardChrome(cornerRadius: cornerRadius)
        case .list:
            buxListCardChrome(cornerRadius: cornerRadius)
        }
    }
}
