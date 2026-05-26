//
//  ThemeManager.swift
//  BuxMuse
//
//  Global Theme Engine — iOS 26 first, iOS 18 fallback.
//  Inject via .environmentObject(ThemeManager()) in BuxMuseApp.
//

import SwiftUI
import Combine

// MARK: - App Theme Definition

struct AppTheme: Identifiable, Equatable {
    let id: String
    let name: String
    let icon: String

    // Hero card gradient (works in both dark and light mode)
    let heroDarkGradient: [Color]
    let heroLightGradient: [Color]

    // Primary accent — used on pills, active icons, buttons, CTAs
    let accentColor: Color

    // Radial glow color on hero card
    let glowColor: Color

    // Preview swatch colors for the theme picker (2 colors shown as a gradient pill)
    var swatchColors: [Color] { heroDarkGradient }
}

// MARK: - Built-in Themes

extension AppTheme {
    /// Default BuxMuse Purple/Indigo
    static let buxDefault = AppTheme(
        id: "bux_default",
        name: "Bux",
        icon: "bolt.fill",
        heroDarkGradient: [
            Color(red: 90/255, green: 85/255, blue: 245/255),
            Color(red: 60/255, green: 55/255, blue: 180/255)
        ],
        heroLightGradient: [
            Color(red: 110/255, green: 105/255, blue: 255/255),
            Color(red: 80/255, green: 75/255, blue: 210/255)
        ],
        accentColor: Color(red: 90/255, green: 85/255, blue: 245/255),
        glowColor: Color(red: 90/255, green: 85/255, blue: 245/255)
    )

    /// Midnight Ocean — Deep Teal/Blue
    static let midnightOcean = AppTheme(
        id: "midnight_ocean",
        name: "Ocean",
        icon: "drop.fill",
        heroDarkGradient: [
            Color(red: 0/255, green: 180/255, blue: 216/255),
            Color(red: 0/255, green: 80/255, blue: 160/255)
        ],
        heroLightGradient: [
            Color(red: 0/255, green: 200/255, blue: 240/255),
            Color(red: 0/255, green: 100/255, blue: 190/255)
        ],
        accentColor: Color(red: 0/255, green: 180/255, blue: 216/255),
        glowColor: Color(red: 0/255, green: 180/255, blue: 216/255)
    )

    /// Sunset Vibes — Coral/Warm Pink
    static let sunsetVibes = AppTheme(
        id: "sunset_vibes",
        name: "Sunset",
        icon: "sun.horizon.fill",
        heroDarkGradient: [
            Color(red: 255/255, green: 107/255, blue: 107/255),
            Color(red: 200/255, green: 60/255, blue: 120/255)
        ],
        heroLightGradient: [
            Color(red: 255/255, green: 130/255, blue: 100/255),
            Color(red: 220/255, green: 80/255, blue: 130/255)
        ],
        accentColor: Color(red: 255/255, green: 107/255, blue: 107/255),
        glowColor: Color(red: 255/255, green: 107/255, blue: 107/255)
    )

    /// Emerald Cyber — Vibrant Lime Green/Spruce
    static let emeraldCyber = AppTheme(
        id: "emerald_cyber",
        name: "Emerald",
        icon: "leaf.fill",
        heroDarkGradient: [
            Color(red: 0/255, green: 245/255, blue: 160/255),
            Color(red: 0/255, green: 120/255, blue: 80/255)
        ],
        heroLightGradient: [
            Color(red: 0/255, green: 255/255, blue: 180/255),
            Color(red: 0/255, green: 150/255, blue: 100/255)
        ],
        accentColor: Color(red: 0/255, green: 200/255, blue: 130/255),
        glowColor: Color(red: 0/255, green: 245/255, blue: 160/255)
    )

    /// Sakura Dream — Delicate Cherry Rose/Plum
    static let sakuraDream = AppTheme(
        id: "sakura_dream",
        name: "Sakura",
        icon: "heart.fill",
        heroDarkGradient: [
            Color(red: 255/255, green: 158/255, blue: 174/255),
            Color(red: 180/255, green: 60/255, blue: 100/255)
        ],
        heroLightGradient: [
            Color(red: 255/255, green: 180/255, blue: 195/255),
            Color(red: 210/255, green: 80/255, blue: 120/255)
        ],
        accentColor: Color(red: 255/255, green: 120/255, blue: 145/255),
        glowColor: Color(red: 255/255, green: 158/255, blue: 174/255)
    )

    /// Gold Prestige — Luxurious Gold/Amber
    static let goldPrestige = AppTheme(
        id: "gold_prestige",
        name: "Gold",
        icon: "crown.fill",
        heroDarkGradient: [
            Color(red: 255/255, green: 215/255, blue: 0/255),
            Color(red: 180/255, green: 110/255, blue: 0/255)
        ],
        heroLightGradient: [
            Color(red: 255/255, green: 225/255, blue: 50/255),
            Color(red: 210/255, green: 130/255, blue: 10/255)
        ],
        accentColor: Color(red: 212/255, green: 175/255, blue: 55/255),
        glowColor: Color(red: 255/255, green: 215/255, blue: 0/255)
    )

    /// Crimson Ember — Fiery Crimson/Carbon Gray
    static let crimsonEmber = AppTheme(
        id: "crimson_ember",
        name: "Crimson",
        icon: "flame.fill",
        heroDarkGradient: [
            Color(red: 255/255, green: 51/255, blue: 102/255),
            Color(red: 160/255, green: 10/255, blue: 40/255)
        ],
        heroLightGradient: [
            Color(red: 255/255, green: 80/255, blue: 120/255),
            Color(red: 190/255, green: 20/255, blue: 60/255)
        ],
        accentColor: Color(red: 255/255, green: 51/255, blue: 102/255),
        glowColor: Color(red: 255/255, green: 51/255, blue: 102/255)
    )

    /// Neon Horizon — Cyberpunk Ultraviolet/Pink
    static let neonHorizon = AppTheme(
        id: "neon_horizon",
        name: "Horizon",
        icon: "sparkles",
        heroDarkGradient: [
            Color(red: 155/255, green: 93/255, blue: 229/255),
            Color(red: 241/255, green: 91/255, blue: 181/255)
        ],
        heroLightGradient: [
            Color(red: 175/255, green: 110/255, blue: 255/255),
            Color(red: 255/255, green: 120/255, blue: 200/255)
        ],
        accentColor: Color(red: 155/255, green: 93/255, blue: 229/255),
        glowColor: Color(red: 155/255, green: 93/255, blue: 229/255)
    )

    /// All themes in display order
    static let all: [AppTheme] = [
        .buxDefault, .midnightOcean, .sunsetVibes, .emeraldCyber,
        .sakuraDream, .goldPrestige, .crimsonEmber, .neonHorizon
    ]
}

// MARK: - ThemeManager

public final class ThemeManager: ObservableObject {
    @Published var current: AppTheme = .buxDefault
    private let themeKey = "selected_theme_id"
    var onThemeChanged: ((AppTheme) -> Void)?

    public init() {
        if let storedId = UserDefaults.standard.string(forKey: themeKey),
           let matchedTheme = AppTheme.all.first(where: { $0.id == storedId }) {
            current = matchedTheme
        } else {
            current = .buxDefault
        }
    }

    /// Select a theme with a smooth animated transition
    func select(_ theme: AppTheme) {
        applyTheme(theme, persist: true)
    }

    func applyTheme(_ theme: AppTheme, persist: Bool) {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.72)) {
            current = theme
        }
        if persist {
            UserDefaults.standard.set(theme.id, forKey: themeKey)
        }
        onThemeChanged?(theme)
    }

    // MARK: - Unified surfaces (light/dark)

    func screenBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 13/255, green: 14/255, blue: 18/255)
            : Color(red: 242/255, green: 244/255, blue: 247/255)
    }

    func cardFill(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(red: 24/255, green: 26/255, blue: 32/255) : .white
    }

    /// Subtle gray stroke for hero card and category pill — light mode only.
    func subtleCardStroke(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color.clear
            : Color.black.opacity(0.08)
    }

    func pillInactiveLabelColor(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 150/255, green: 155/255, blue: 160/255)
            : Color(red: 120/255, green: 125/255, blue: 130/255)
    }

    /// Hero gradient for the current color scheme
    func heroGradient(for colorScheme: ColorScheme) -> LinearGradient {
        let colors = colorScheme == .dark ? current.heroDarkGradient : current.heroLightGradient
        return LinearGradient(
            colors: colors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Environment Key for convenient access

private struct ThemeManagerKey: EnvironmentKey {
    static let defaultValue = ThemeManager()
}

extension EnvironmentValues {
    var themeManager: ThemeManager {
        get { self[ThemeManagerKey.self] }
        set { self[ThemeManagerKey.self] = newValue }
    }
}
