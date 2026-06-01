//
//  BuxMaterialScheme.swift
//  BuxMuse Design System
//
//  Full Material Design 3 tonal color system — every AppTheme seeds surfaces,
//  containers, outlines, and accents. Visual only; SF Pro elsewhere.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - M3 color roles

struct BuxMaterialScheme: Equatable {
    let primary: Color
    let onPrimary: Color
    let primaryContainer: Color
    let onPrimaryContainer: Color
    let secondary: Color
    let onSecondary: Color
    let surface: Color
    let onSurface: Color
    let onSurfaceVariant: Color
    let surfaceContainerLowest: Color
    let surfaceContainerLow: Color
    let surfaceContainer: Color
    let surfaceContainerHigh: Color
    let surfaceContainerHighest: Color
    let outline: Color
    let outlineVariant: Color
    let error: Color
    let onError: Color

    // MARK: - Generation

    static func generate(
        theme: AppTheme,
        colorScheme: ColorScheme,
        branded: Bool,
        interactiveAccent: Color? = nil
    ) -> BuxMaterialScheme {
        if SettingsStore.shared.solarContrastModeEnabled {
            return BuxMaterialScheme(
                primary: .black,
                onPrimary: .white,
                primaryContainer: .white,
                onPrimaryContainer: .black,
                secondary: .black,
                onSecondary: .white,
                surface: .white,
                onSurface: .black,
                onSurfaceVariant: .black,
                surfaceContainerLowest: .white,
                surfaceContainerLow: .white,
                surfaceContainer: .white,
                surfaceContainerHigh: .white,
                surfaceContainerHighest: .white,
                outline: .black,
                outlineVariant: .black,
                error: .red,
                onError: .white
            )
        }

        if !branded {
            let accent = interactiveAccent ?? BuxSystemAccent.systemBlue.color(for: colorScheme)
            if colorScheme == .dark {
                return generateNeutralDark(accent: accent)
            }
            return generateNeutralLight(accent: accent)
        }

        let hue = theme.materialHue(for: colorScheme)
        if colorScheme == .dark {
            return generateDark(theme: theme, hue: hue, branded: branded)
        }
        return generateLight(theme: theme, hue: hue, branded: branded)
    }

    // MARK: Apple neutral (Brand Themes off)

    private static func generateNeutralLight(accent: Color) -> BuxMaterialScheme {
        let surfaces = appleNeutralSurfaces(dark: false)
        return BuxMaterialScheme(
            primary: accent,
            onPrimary: .white,
            primaryContainer: accent.opacity(0.14),
            onPrimaryContainer: accent,
            secondary: accent.opacity(0.72),
            onSecondary: .white,
            surface: surfaces.surface,
            onSurface: surfaces.onSurface,
            onSurfaceVariant: surfaces.onSurfaceVariant,
            surfaceContainerLowest: surfaces.containerLowest,
            surfaceContainerLow: surfaces.containerLow,
            surfaceContainer: surfaces.container,
            surfaceContainerHigh: surfaces.containerHigh,
            surfaceContainerHighest: surfaces.containerHighest,
            outline: surfaces.outline,
            outlineVariant: surfaces.outlineVariant,
            error: Color(red: 179/255, green: 38/255, blue: 30/255),
            onError: .white
        )
    }

    private static func generateNeutralDark(accent: Color) -> BuxMaterialScheme {
        let surfaces = appleNeutralSurfaces(dark: true)
        return BuxMaterialScheme(
            primary: accent,
            onPrimary: Color(red: 18/255, green: 18/255, blue: 18/255),
            primaryContainer: accent.opacity(0.28),
            onPrimaryContainer: accent,
            secondary: accent.opacity(0.80),
            onSecondary: Color(red: 18/255, green: 18/255, blue: 18/255),
            surface: surfaces.surface,
            onSurface: surfaces.onSurface,
            onSurfaceVariant: surfaces.onSurfaceVariant,
            surfaceContainerLowest: surfaces.containerLowest,
            surfaceContainerLow: surfaces.containerLow,
            surfaceContainer: surfaces.container,
            surfaceContainerHigh: surfaces.containerHigh,
            surfaceContainerHighest: surfaces.containerHighest,
            outline: surfaces.outline,
            outlineVariant: surfaces.outlineVariant,
            error: Color(red: 242/255, green: 184/255, blue: 181/255),
            onError: Color(red: 96/255, green: 20/255, blue: 16/255)
        )
    }

    private struct AppleNeutralSurfaces {
        let surface: Color
        let onSurface: Color
        let onSurfaceVariant: Color
        let containerLowest: Color
        let containerLow: Color
        let container: Color
        let containerHigh: Color
        let containerHighest: Color
        let outline: Color
        let outlineVariant: Color
    }

    /// HIG grouped backgrounds — no theme hue on structural surfaces.
    private static func appleNeutralSurfaces(dark: Bool) -> AppleNeutralSurfaces {
        #if canImport(UIKit)
        let canvas = dark
            ? Color(red: 18/255, green: 18/255, blue: 18/255)
            : Color(uiColor: .systemGroupedBackground)
        let card = Color(uiColor: .secondarySystemGroupedBackground)
        let nested = Color(uiColor: .tertiarySystemGroupedBackground)
        let label = Color(uiColor: .label)
        let secondaryLabel = Color(uiColor: .secondaryLabel)
        let separator = Color(uiColor: .separator)
        let opaqueSeparator = Color(uiColor: .opaqueSeparator)
        #else
        let canvas = dark ? Color(red: 18/255, green: 18/255, blue: 18/255) : Color(red: 242/255, green: 242/255, blue: 247/255)
        let card = dark ? Color(red: 28/255, green: 28/255, blue: 30/255) : .white
        let nested = dark ? Color(red: 44/255, green: 44/255, blue: 46/255) : Color(red: 242/255, green: 242/255, blue: 247/255)
        let label = dark ? .white : .black
        let secondaryLabel = .gray
        let separator = Color.gray.opacity(0.35)
        let opaqueSeparator = separator
        #endif

        return AppleNeutralSurfaces(
            surface: card,
            onSurface: label,
            onSurfaceVariant: secondaryLabel,
            containerLowest: card,
            containerLow: canvas,
            container: nested,
            containerHigh: nested,
            containerHighest: nested,
            outline: opaqueSeparator,
            outlineVariant: separator
        )
    }

    // MARK: Light

    private static func generateLight(theme: AppTheme, hue: CGFloat, branded: Bool) -> BuxMaterialScheme {
        let accent = theme.accentColor
        let hsb = accent.buxHSB()
        let h = hue

        let primary = Color.buxFromHSB(h: h, s: min(max(hsb.s, 0.35), 0.62), b: 0.40)
        let onPrimary = Color.buxFromHSB(h: h, s: 0.04, b: 0.99)
        let primaryContainer = tonal(h: h, tone: 90, chroma: branded ? 0.20 : 0.06)
        let onPrimaryContainer = tonal(h: h, tone: 12, chroma: branded ? 0.35 : 0.10)
        let secondary = tonal(h: h, tone: 48, chroma: branded ? 0.14 : 0.04)
        let onSecondary = Color.buxFromHSB(h: h, s: 0.04, b: 0.99)

        let surfaces = surfaceLadder(hue: h, dark: false, branded: branded)
        let border = adaptiveOutlineVariant(hue: h, theme: theme, dark: false, branded: branded)

        return BuxMaterialScheme(
            primary: primary,
            onPrimary: onPrimary,
            primaryContainer: primaryContainer,
            onPrimaryContainer: onPrimaryContainer,
            secondary: secondary,
            onSecondary: onSecondary,
            surface: surfaces.surface,
            onSurface: surfaces.onSurface,
            onSurfaceVariant: surfaces.onSurfaceVariant,
            surfaceContainerLowest: surfaces.containerLowest,
            surfaceContainerLow: surfaces.containerLow,
            surfaceContainer: surfaces.container,
            surfaceContainerHigh: surfaces.containerHigh,
            surfaceContainerHighest: surfaces.containerHighest,
            outline: border.outline,
            outlineVariant: border.variant,
            error: Color(red: 179/255, green: 38/255, blue: 30/255),
            onError: .white
        )
    }

    // MARK: Dark

    private static func generateDark(theme: AppTheme, hue: CGFloat, branded: Bool) -> BuxMaterialScheme {
        let accent = theme.accentColor
        let hsb = accent.buxHSB()
        let h = hue

        let primary = Color.buxFromHSB(h: h, s: min(max(hsb.s * 0.9, 0.28), 0.55), b: 0.78)
        let onPrimary = tonal(h: h, tone: 16, chroma: 0.30)
        let primaryContainer = tonal(h: h, tone: 28, chroma: branded ? 0.32 : 0.12)
        let onPrimaryContainer = tonal(h: h, tone: 88, chroma: branded ? 0.12 : 0.05)
        let secondary = tonal(h: h, tone: 72, chroma: branded ? 0.14 : 0.06)
        let onSecondary = tonal(h: h, tone: 18, chroma: 0.28)

        let surfaces = surfaceLadder(hue: h, dark: true, branded: branded)
        let border = adaptiveOutlineVariant(hue: h, theme: theme, dark: true, branded: branded)

        return BuxMaterialScheme(
            primary: primary,
            onPrimary: onPrimary,
            primaryContainer: primaryContainer,
            onPrimaryContainer: onPrimaryContainer,
            secondary: secondary,
            onSecondary: onSecondary,
            surface: surfaces.surface,
            onSurface: surfaces.onSurface,
            onSurfaceVariant: surfaces.onSurfaceVariant,
            surfaceContainerLowest: surfaces.containerLowest,
            surfaceContainerLow: surfaces.containerLow,
            surfaceContainer: surfaces.container,
            surfaceContainerHigh: surfaces.containerHigh,
            surfaceContainerHighest: surfaces.containerHighest,
            outline: border.outline,
            outlineVariant: border.variant,
            error: Color(red: 242/255, green: 184/255, blue: 181/255),
            onError: Color(red: 96/255, green: 20/255, blue: 16/255)
        )
    }

    private struct BorderPair {
        let outline: Color
        let variant: Color
    }

    /// Stronger outline on low-chroma themes (Ocean/Emerald) so borders still read.
    private static func adaptiveOutlineVariant(
        hue: CGFloat,
        theme: AppTheme,
        dark: Bool,
        branded: Bool
    ) -> BorderPair {
        let vividness = theme.materialVividness(for: dark ? .dark : .light)
        // Low-chroma themes (Ocean/Emerald) need a stronger border to read on flat cards.
        let boost = branded ? max(0, 0.10 - vividness * 0.07) : 0.02
        let variantChroma = (dark ? 0.14 : 0.12) + boost
        let outlineChroma = variantChroma + (dark ? 0.04 : 0.03)

        return BorderPair(
            outline: tonal(h: hue, tone: dark ? 52 : 48, chroma: outlineChroma),
            variant: tonal(h: hue, tone: dark ? 34 : 76, chroma: variantChroma)
        )
    }

    // MARK: M3 surface ladder (tonal stops from m3.material.io)

    private struct SurfaceLadder {
        let surface: Color
        let onSurface: Color
        let onSurfaceVariant: Color
        let containerLowest: Color
        let containerLow: Color
        let container: Color
        let containerHigh: Color
        let containerHighest: Color
    }

    /// Retail flat shelf — wide tone gap: darker canvas, brighter card tile.
    private static func surfaceLadder(hue: CGFloat, dark: Bool, branded: Bool) -> SurfaceLadder {
        let c = branded ? (dark ? 0.18 : 0.14) : (dark ? 0.05 : 0.03)
        let cStep = branded ? 0.014 : 0.005

        if dark {
            // Canvas ~tone 7, cards ~tone 16 — clear lift on the shelf.
            return SurfaceLadder(
                surface: tonal(h: hue, tone: 16, chroma: max(c - 0.04, 0.06)),
                onSurface: onSurfaceText(hue: hue, dark: true),
                onSurfaceVariant: onSurfaceVariantText(hue: hue, dark: true),
                containerLowest: tonal(h: hue, tone: 16, chroma: max(c - 0.04, 0.06)),
                containerLow: tonal(h: hue, tone: 7, chroma: c + cStep),
                container: tonal(h: hue, tone: 10, chroma: c + cStep * 2),
                containerHigh: tonal(h: hue, tone: 13, chroma: c + cStep * 3),
                containerHighest: tonal(h: hue, tone: 18, chroma: c + cStep * 4)
            )
        }

        // Canvas ~tone 90, cards ~tone 96 — visibly tinted tiles (not pure white).
        return SurfaceLadder(
            surface: tonal(h: hue, tone: 96, chroma: c),
            onSurface: onSurfaceText(hue: hue, dark: false),
            onSurfaceVariant: onSurfaceVariantText(hue: hue, dark: false),
            containerLowest: tonal(h: hue, tone: 96, chroma: c),
            containerLow: tonal(h: hue, tone: 90, chroma: c + cStep * 2),
            container: tonal(h: hue, tone: 92, chroma: c + cStep * 3),
            containerHigh: tonal(h: hue, tone: 94, chroma: c + cStep * 4),
            containerHighest: tonal(h: hue, tone: 96, chroma: c + cStep * 5)
        )
    }

    /// High-contrast body text — low chroma so it reads on every themed card.
    private static func onSurfaceText(hue: CGFloat, dark: Bool) -> Color {
        if dark {
            return tonal(h: hue, tone: 94, chroma: 0.03)
        }
        return tonal(h: hue, tone: 11, chroma: 0.05)
    }

    private static func onSurfaceVariantText(hue: CGFloat, dark: Bool) -> Color {
        if dark {
            return tonal(h: hue, tone: 76, chroma: 0.04)
        }
        return tonal(h: hue, tone: 36, chroma: 0.06)
    }

    /// M3 tonal stop → HSB color (tone 0–100 = brightness).
    private static func tonal(h: CGFloat, tone: CGFloat, chroma: CGFloat) -> Color {
        let brightness = max(0.04, min(0.99, tone / 100.0))
        let saturation = max(0, min(0.55, chroma))
        return Color.buxFromHSB(h: h, s: saturation, b: brightness)
    }
}

// MARK: - AppTheme hue extraction

private extension AppTheme {
    func materialHue(for colorScheme: ColorScheme) -> CGFloat {
        let palette = colorScheme == .dark ? meshDarkPalette : meshLightPalette
        let hues = palette.map { $0.buxHSB().h }
        guard !hues.isEmpty else { return accentColor.buxHSB().h }

        // Circular mean hue — captures theme family (Ocean cool, Sunset warm, etc.)
        var sumSin: CGFloat = 0
        var sumCos: CGFloat = 0
        for hue in hues {
            sumSin += sin(hue * 2 * .pi)
            sumCos += cos(hue * 2 * .pi)
        }
        if abs(sumSin) < 0.001 && abs(sumCos) < 0.001 {
            return accentColor.buxHSB().h
        }
        var mean = atan2(sumSin, sumCos) / (2 * .pi)
        if mean < 0 { mean += 1 }
        return mean
    }

    /// 0…1 — how vivid the theme mesh is (low = Ocean/Emerald, high = Sunset/Sakura).
    func materialVividness(for colorScheme: ColorScheme) -> CGFloat {
        let palette = colorScheme == .dark ? meshDarkPalette : meshLightPalette
        guard !palette.isEmpty else { return accentColor.buxHSB().s }
        let chromas = palette.map { $0.buxHSB().s }
        let avg = chromas.reduce(0, +) / CGFloat(chromas.count)
        return min(max(avg, 0), 1)
    }
}

// MARK: - Color helpers

private extension Color {
    func buxRGB() -> (r: CGFloat, g: CGFloat, b: CGFloat) {
        #if canImport(UIKit)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        return (r, g, b)
        #else
        return (0.5, 0.5, 0.5)
        #endif
    }

    func buxHSB() -> (h: CGFloat, s: CGFloat, b: CGFloat, a: CGFloat) {
        #if canImport(UIKit)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return (h, s, b, a)
        #else
        return (0, 0, 0.5, 1)
        #endif
    }

    static func buxFromHSB(h: CGFloat, s: CGFloat, b: CGFloat, opacity: Double = 1) -> Color {
        Color(hue: h, saturation: s, brightness: b, opacity: opacity)
    }
}

// MARK: - Environment

private struct BuxMaterialSchemeKey: EnvironmentKey {
    static let defaultValue: BuxMaterialScheme? = nil
}

extension EnvironmentValues {
    var buxMaterialScheme: BuxMaterialScheme? {
        get { self[BuxMaterialSchemeKey.self] }
        set { self[BuxMaterialSchemeKey.self] = newValue }
    }
}

// MARK: - ThemeManager

extension ThemeManager {
    func materialScheme(for colorScheme: ColorScheme, branded: Bool? = nil) -> BuxMaterialScheme {
        let settings = SettingsStore.shared
        let useBranded = branded ?? settings.brandThemesEnabled
        let accent: Color? = useBranded
            ? nil
            : settings.resolvedSystemAccentColor(for: colorScheme)
        return BuxMaterialScheme.generate(
            theme: current,
            colorScheme: colorScheme,
            branded: useBranded,
            interactiveAccent: accent
        )
    }
}
