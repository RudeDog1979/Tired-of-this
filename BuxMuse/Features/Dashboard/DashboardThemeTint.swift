//
//  DashboardThemeTint.swift
//  BuxMuse
//
//  Home + Studio + Expenses + Settings card tint — base fill + light mesh wash (CategoryPillBar stack).
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

private struct DashboardEnhancedTintKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var dashboardEnhancedTint: Bool {
        get { self[DashboardEnhancedTintKey.self] }
        set { self[DashboardEnhancedTintKey.self] = newValue }
    }
}

private struct StudioEnhancedTintKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// Studio tab — same mesh card chrome as the Home dashboard.
    var studioEnhancedTint: Bool {
        get { self[StudioEnhancedTintKey.self] }
        set { self[StudioEnhancedTintKey.self] = newValue }
    }
}

private struct ExpensesEnhancedTintKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// Expenses tab — same mesh card chrome as Home / Studio.
    var expensesEnhancedTint: Bool {
        get { self[ExpensesEnhancedTintKey.self] }
        set { self[ExpensesEnhancedTintKey.self] = newValue }
    }
}

private struct SettingsEnhancedTintKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// Settings tab — same mesh card chrome as Home / Studio / Expenses.
    var settingsEnhancedTint: Bool {
        get { self[SettingsEnhancedTintKey.self] }
        set { self[SettingsEnhancedTintKey.self] = newValue }
    }
}

// MARK: - Light mesh (meshLightPalette only)

private extension Color {
    var buxRGB: (r: CGFloat, g: CGFloat, b: CGFloat) {
        #if canImport(UIKit)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        return (r, g, b)
        #else
        return (0.5, 0.5, 0.5)
        #endif
    }

    var buxLuminance: CGFloat {
        let c = buxRGB
        return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b
    }

    var buxChroma: CGFloat {
        let c = buxRGB
        let maxC = max(c.r, max(c.g, c.b))
        let minC = min(c.r, min(c.g, c.b))
        guard maxC > 0.001 else { return 0 }
        return (maxC - minC) / maxC
    }
}

private extension AppTheme {
    var dashboardLightMeshTint: Color {
        let lightMesh = meshLightPalette.filter { color in
            let luminance = color.buxLuminance
            return luminance >= 0.64 && luminance <= 0.97
        }
        let pool = lightMesh.isEmpty ? meshLightPalette : lightMesh
        let bestMesh = pool.max(by: { $0.buxChroma < $1.buxChroma }) ?? meshLightPalette[0]

        guard bestMesh.buxChroma < 0.22, let heroLight = heroLightGradient.first else {
            return bestMesh
        }
        return heroLight
    }

    func dashboardLightMeshWashOpacity(for tint: Color) -> CGFloat {
        switch tint.buxChroma {
        case ..<0.18: return 0.22
        case ..<0.30: return 0.18
        default: return 0.15
        }
    }
}

enum DashboardThemeTint {
    /// M3 surface-container wash — themed pill track / legacy call sites.
    static func dashboardSurfaceWash(themeManager: ThemeManager, colorScheme: ColorScheme) -> Color {
        pillTrackWash(themeManager: themeManager, colorScheme: colorScheme)
    }

    /// M3 surface-container-high wash for pill track (non-glass mode).
    static func pillTrackWash(themeManager: ThemeManager, colorScheme: ColorScheme) -> Color {
        let scheme = themeManager.materialScheme(for: colorScheme)
        return scheme.surfaceContainerHigh.opacity(colorScheme == .dark ? 0.85 : 0.92)
    }

    /// Studio surfaces use the same mesh wash as Home cards.
    static func studioSurfaceWash(themeManager: ThemeManager, colorScheme: ColorScheme) -> Color {
        dashboardSurfaceWash(themeManager: themeManager, colorScheme: colorScheme)
    }

    /// Expenses tab surfaces — same mesh wash as Home / Studio.
    static func expensesSurfaceWash(themeManager: ThemeManager, colorScheme: ColorScheme) -> Color {
        dashboardSurfaceWash(themeManager: themeManager, colorScheme: colorScheme)
    }

    /// Settings tab surfaces — same mesh wash as other tabs.
    static func settingsSurfaceWash(themeManager: ThemeManager, colorScheme: ColorScheme) -> Color {
        dashboardSurfaceWash(themeManager: themeManager, colorScheme: colorScheme)
    }

    static func themedCardStroke(themeManager: ThemeManager, colorScheme: ColorScheme) -> Color {
        themeManager.themedCardStroke(for: colorScheme)
    }

    static func pillActiveChipFill(themeManager: ThemeManager, colorScheme: ColorScheme) -> Color {
        themeManager.pillActiveChipFill(for: colorScheme)
    }

    static func fabAccentShadow(themeManager: ThemeManager, colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? .clear : themeManager.current.accentColor.opacity(0.08)
    }
}

// MARK: - Plate background (pill / card pattern)

struct BuxThemedCardPlateBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    let cornerRadius: CGFloat

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        shape.fill(themeManager.cardFill(for: colorScheme))
    }
}

// MARK: - Chrome (.background plate — fills Button frame correctly)

extension View {
    @ViewBuilder
    func dashboardChromeIfNeeded(_ enabled: Bool, cornerRadius: CGFloat) -> some View {
        if enabled {
            dashboardThemedCardChrome(cornerRadius: cornerRadius)
        } else {
            self
        }
    }

    /// Expense detail hero — emotional cards keep their own chrome; plain uses mesh plate.
    @ViewBuilder
    func expenseOverviewOuterChrome(hasEmotion: Bool, cornerRadius: CGFloat = 28) -> some View {
        if hasEmotion {
            self
        } else {
            expensesThemedCardChrome(cornerRadius: cornerRadius)
        }
    }

    func dashboardThemedCardChrome(cornerRadius: CGFloat = BuxMaterialChrome.cardCornerRadius, elevation: BuxElevation = .card) -> some View {
        modifier(BuxThemedCardChromeModifier(cornerRadius: cornerRadius, elevation: elevation))
    }

    /// Dashboard pill-row card label — M3 Outlined, full-card tap target (use inside `Button`).
    func dashboardPillCardLabel(cornerRadius: CGFloat = BuxMaterialChrome.cardCornerRadius) -> some View {
        buxMaterialPillCardLabel(cornerRadius: cornerRadius)
    }

    /// Shorter auxiliary row under a pill section (e.g. Goals progress CTA).
    func dashboardPillAuxCardLabel(cornerRadius: CGFloat = BuxMaterialChrome.cardCornerRadius) -> some View {
        buxMaterialPillAuxCardLabel(cornerRadius: cornerRadius)
    }

    /// Studio tab cards — identical chrome to Home dashboard cards.
    func studioThemedCardChrome(cornerRadius: CGFloat, elevation: BuxElevation = .card) -> some View {
        dashboardThemedCardChrome(cornerRadius: cornerRadius, elevation: elevation)
    }

    /// Expenses tab cards — identical chrome to Home / Studio.
    func expensesThemedCardChrome(cornerRadius: CGFloat, elevation: BuxElevation = .card) -> some View {
        dashboardThemedCardChrome(cornerRadius: cornerRadius, elevation: elevation)
    }

    /// Settings tab cards — identical chrome to Home / Studio / Expenses.
    func settingsThemedCardChrome(cornerRadius: CGFloat, elevation: BuxElevation = .card) -> some View {
        dashboardThemedCardChrome(cornerRadius: cornerRadius, elevation: elevation)
    }

    /// Shared tab mesh chrome (Home uses `dashboardThemedCardChrome` directly).
    func buxThemedCardChrome(cornerRadius: CGFloat, elevation: BuxElevation = .card) -> some View {
        dashboardThemedCardChrome(cornerRadius: cornerRadius, elevation: elevation)
    }

    func dashboardAwareCardOutline(
        themeManager: ThemeManager,
        colorScheme: ColorScheme,
        cornerRadius: CGFloat,
        dashboardEnhanced: Bool
    ) -> some View {
        dashboardThemedCardChrome(cornerRadius: cornerRadius)
    }
}

struct BuxThemedCardChromeModifier: ViewModifier {
    let cornerRadius: CGFloat
    var elevation: BuxElevation = .card

    func body(content: Content) -> some View {
        switch elevation {
        case .hero:
            content.modifier(BuxHeroCardChromeModifier(cornerRadius: cornerRadius))
        case .card, .flat:
            content.modifier(BuxListCardChromeModifier(cornerRadius: cornerRadius))
        }
    }
}

private typealias DashboardThemedCardChromeModifier = BuxThemedCardChromeModifier
