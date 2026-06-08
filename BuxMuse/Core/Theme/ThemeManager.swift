//
//  ThemeManager.swift
//  BuxMuse
//
//  Global Theme Engine — iOS 26 first, iOS 18 fallback.
//  Inject via .environmentObject(ThemeManager()) in BuxMuseApp.
//

import SwiftUI
import Combine
#if canImport(UIKit)
import UIKit
#endif

// MARK: - App Theme Definition

struct AppTheme: Identifiable, Equatable {
    let id: String
    let name: String
    let icon: String

    // Hero card gradient (works in both dark and light mode)
    let heroDarkGradient: [Color]
    let heroLightGradient: [Color]
    
    // Mesh gradients for iOS 18+ Hero Cards
    let meshDarkPalette: [Color]
    let meshLightPalette: [Color]

    // Primary accent — used on pills, active icons, buttons, CTAs
    let accentColor: Color

    // Radial glow color on hero card
    let glowColor: Color

    // Preview swatch colors for the theme picker (2 colors shown as a gradient pill)
    var swatchColors: [Color] { heroDarkGradient }
}

// MARK: - Built-in Themes

extension AppTheme {
    /// Standard iOS appearance — neutral surfaces, user-selected system accent.
    static func standardNeutral(accent: BuxSystemAccent) -> AppTheme {
        let accentColor = Color(uiColor: accent.uiColor)
        #if canImport(UIKit)
        let lightHero = [Color(uiColor: .secondarySystemGroupedBackground), Color(uiColor: .systemGroupedBackground)]
        let darkHero = [Color(red: 28/255, green: 28/255, blue: 30/255), Color(red: 18/255, green: 18/255, blue: 18/255)]
        let lightMesh = [Color(uiColor: .systemGroupedBackground)]
        #else
        let lightHero = [Color.white, Color(red: 242/255, green: 242/255, blue: 247/255)]
        let darkHero = [Color(red: 28/255, green: 28/255, blue: 30/255), Color(red: 18/255, green: 18/255, blue: 18/255)]
        let lightMesh = [Color(red: 242/255, green: 242/255, blue: 247/255)]
        #endif
        return AppTheme(
            id: "standardNeutral",
            name: "Standard",
            icon: "circle.lefthalf.filled",
            heroDarkGradient: darkHero,
            heroLightGradient: lightHero,
            meshDarkPalette: [Color(red: 18/255, green: 18/255, blue: 18/255)],
            meshLightPalette: lightMesh,
            accentColor: accentColor,
            glowColor: accentColor
        )
    }

    /// Bux Theme
    static let buxDefault = AppTheme(
        id: "buxDefault",
        name: "Bux",
        icon: "bolt.fill",
        heroDarkGradient: [Color(red: 90/255, green: 85/255, blue: 245/255), Color(red: 62/255, green: 59/255, blue: 171/255)],
        heroLightGradient: [Color(red: 108/255, green: 102/255, blue: 255/255), Color(red: 90/255, green: 85/255, blue: 245/255)],
        meshDarkPalette: [
            Color(red: 60/255, green: 148/255, blue: 161/255),
            Color(red: 35/255, green: 31/255, blue: 147/255),
            Color(red: 146/255, green: 45/255, blue: 154/255),
            Color(red: 18/255, green: 48/255, blue: 132/255),
            Color(red: 35/255, green: 31/255, blue: 147/255),
            Color(red: 56/255, green: 18/255, blue: 132/255),
            Color(red: 79/255, green: 176/255, blue: 160/255),
            Color(red: 46/255, green: 43/255, blue: 147/255),
            Color(red: 176/255, green: 79/255, blue: 154/255)
        ],
        meshLightPalette: [
            Color(red: 175/255, green: 244/255, blue: 255/255),
            Color(red: 158/255, green: 155/255, blue: 255/255),
            Color(red: 248/255, green: 165/255, blue: 255/255),
            Color(red: 138/255, green: 166/255, blue: 242/255),
            Color(red: 158/255, green: 155/255, blue: 255/255),
            Color(red: 172/255, green: 138/255, blue: 242/255),
            Color(red: 185/255, green: 255/255, blue: 243/255),
            Color(red: 167/255, green: 165/255, blue: 255/255),
            Color(red: 255/255, green: 185/255, blue: 238/255)
        ],
        accentColor: Color(red: 90/255, green: 85/255, blue: 245/255),
        glowColor: Color(red: 90/255, green: 85/255, blue: 245/255)
    )

    /// Ocean Theme
    static let midnightOcean = AppTheme(
        id: "midnightOcean",
        name: "Ocean",
        icon: "drop.fill",
        heroDarkGradient: [Color(red: 0/255, green: 72/255, blue: 192/255), Color(red: 0/255, green: 160/255, blue: 255/255)],
        heroLightGradient: [Color(red: 0/255, green: 90/255, blue: 220/255), Color(red: 0/255, green: 180/255, blue: 255/255)],
        meshDarkPalette: [
            Color(red: 5/255, green: 142/255, blue: 42/255),
            Color(red: 0/255, green: 107/255, blue: 129/255),
            Color(red: 9/255, green: 0/255, blue: 136/255),
            Color(red: 0/255, green: 116/255, blue: 101/255),
            Color(red: 0/255, green: 107/255, blue: 129/255),
            Color(red: 0/255, green: 62/255, blue: 116/255),
            Color(red: 29/255, green: 155/255, blue: 24/255),
            Color(red: 0/255, green: 107/255, blue: 129/255),
            Color(red: 72/255, green: 24/255, blue: 155/255)
        ],
        meshLightPalette: [
            Color(red: 132/255, green: 255/255, blue: 165/255),
            Color(red: 95/255, green: 213/255, blue: 237/255),
            Color(red: 123/255, green: 114/255, blue: 249/255),
            Color(red: 72/255, green: 213/255, blue: 195/255),
            Color(red: 95/255, green: 213/255, blue: 237/255),
            Color(red: 72/255, green: 147/255, blue: 213/255),
            Color(red: 151/255, green: 255/255, blue: 147/255),
            Color(red: 109/255, green: 216/255, blue: 237/255),
            Color(red: 187/255, green: 147/255, blue: 255/255)
        ],
        accentColor: Color(red: 0/255, green: 180/255, blue: 216/255),
        glowColor: Color(red: 0/255, green: 180/255, blue: 216/255)
    )

    /// Sunset Theme
    static let sunsetVibes = AppTheme(
        id: "sunsetVibes",
        name: "Sunset",
        icon: "sun.horizon.fill",
        heroDarkGradient: [Color(red: 255/255, green: 107/255, blue: 107/255), Color(red: 178/255, green: 74/255, blue: 74/255)],
        heroLightGradient: [Color(red: 255/255, green: 128/255, blue: 128/255), Color(red: 255/255, green: 107/255, blue: 107/255)],
        meshDarkPalette: [
            Color(red: 168/255, green: 74/255, blue: 158/255),
            Color(red: 153/255, green: 46/255, blue: 46/255),
            Color(red: 160/255, green: 150/255, blue: 59/255),
            Color(red: 137/255, green: 32/255, blue: 63/255),
            Color(red: 153/255, green: 46/255, blue: 46/255),
            Color(red: 137/255, green: 63/255, blue: 32/255),
            Color(red: 165/255, green: 94/255, blue: 183/255),
            Color(red: 153/255, green: 57/255, blue: 57/255),
            Color(red: 165/255, green: 183/255, blue: 94/255)
        ],
        meshLightPalette: [
            Color(red: 255/255, green: 183/255, blue: 247/255),
            Color(red: 255/255, green: 166/255, blue: 166/255),
            Color(red: 255/255, green: 247/255, blue: 175/255),
            Color(red: 252/255, green: 155/255, blue: 184/255),
            Color(red: 255/255, green: 166/255, blue: 166/255),
            Color(red: 252/255, green: 184/255, blue: 155/255),
            Color(red: 242/255, green: 192/255, blue: 255/255),
            Color(red: 255/255, green: 175/255, blue: 175/255),
            Color(red: 242/255, green: 255/255, blue: 192/255)
        ],
        accentColor: Color(red: 255/255, green: 107/255, blue: 107/255),
        glowColor: Color(red: 255/255, green: 107/255, blue: 107/255)
    )

    /// Emerald Theme
    static let emeraldCyber = AppTheme(
        id: "emeraldCyber",
        name: "Emerald",
        icon: "leaf.fill",
        heroDarkGradient: [Color(red: 0/255, green: 125/255, blue: 52/255), Color(red: 0/255, green: 195/255, blue: 90/255)],
        heroLightGradient: [Color(red: 0/255, green: 140/255, blue: 60/255), Color(red: 0/255, green: 215/255, blue: 100/255)],
        meshDarkPalette: [
            Color(red: 44/255, green: 161/255, blue: 6/255),
            Color(red: 0/255, green: 147/255, blue: 95/255),
            Color(red: 0/255, green: 68/255, blue: 154/255),
            Color(red: 0/255, green: 132/255, blue: 46/255),
            Color(red: 0/255, green: 147/255, blue: 95/255),
            Color(red: 0/255, green: 132/255, blue: 126/255),
            Color(red: 109/255, green: 176/255, blue: 28/255),
            Color(red: 0/255, green: 147/255, blue: 95/255),
            Color(red: 28/255, green: 49/255, blue: 176/255)
        ],
        meshLightPalette: [
            Color(red: 162/255, green: 255/255, blue: 132/255),
            Color(red: 102/255, green: 255/255, blue: 201/255),
            Color(red: 117/255, green: 178/255, blue: 255/255),
            Color(red: 82/255, green: 242/255, blue: 138/255),
            Color(red: 102/255, green: 255/255, blue: 201/255),
            Color(red: 82/255, green: 242/255, blue: 235/255),
            Color(red: 206/255, green: 255/255, blue: 147/255),
            Color(red: 117/255, green: 255/255, blue: 207/255),
            Color(red: 147/255, green: 163/255, blue: 255/255)
        ],
        accentColor: Color(red: 0/255, green: 245/255, blue: 160/255),
        glowColor: Color(red: 0/255, green: 245/255, blue: 160/255)
    )

    /// Sakura Theme
    static let sakuraDream = AppTheme(
        id: "sakuraDream",
        name: "Sakura",
        icon: "heart.fill",
        heroDarkGradient: [Color(red: 255/255, green: 158/255, blue: 174/255), Color(red: 178/255, green: 110/255, blue: 121/255)],
        heroLightGradient: [Color(red: 255/255, green: 189/255, blue: 208/255), Color(red: 255/255, green: 158/255, blue: 174/255)],
        meshDarkPalette: [
            Color(red: 164/255, green: 106/255, blue: 168/255),
            Color(red: 153/255, green: 83/255, blue: 94/255),
            Color(red: 160/255, green: 143/255, blue: 94/255),
            Color(red: 137/255, green: 68/255, blue: 100/255),
            Color(red: 153/255, green: 83/255, blue: 94/255),
            Color(red: 137/255, green: 77/255, blue: 68/255),
            Color(red: 162/255, green: 124/255, blue: 183/255),
            Color(red: 153/255, green: 90/255, blue: 100/255),
            Color(red: 181/255, green: 183/255, blue: 124/255)
        ],
        meshLightPalette: [
            Color(red: 251/255, green: 208/255, blue: 255/255),
            Color(red: 255/255, green: 196/255, blue: 206/255),
            Color(red: 255/255, green: 241/255, blue: 202/255),
            Color(red: 252/255, green: 189/255, blue: 218/255),
            Color(red: 255/255, green: 196/255, blue: 206/255),
            Color(red: 252/255, green: 197/255, blue: 189/255),
            Color(red: 240/255, green: 214/255, blue: 255/255),
            Color(red: 255/255, green: 202/255, blue: 211/255),
            Color(red: 253/255, green: 255/255, blue: 214/255)
        ],
        accentColor: Color(red: 255/255, green: 158/255, blue: 174/255),
        glowColor: Color(red: 255/255, green: 158/255, blue: 174/255)
    )

    /// Gold Theme
    static let goldPrestige = AppTheme(
        id: "goldPrestige",
        name: "Gold",
        icon: "crown.fill",
        heroDarkGradient: [Color(red: 255/255, green: 215/255, blue: 0/255), Color(red: 178/255, green: 150/255, blue: 0/255)],
        heroLightGradient: [Color(red: 255/255, green: 255/255, blue: 0/255), Color(red: 255/255, green: 215/255, blue: 0/255)],
        meshDarkPalette: [
            Color(red: 168/255, green: 6/255, blue: 15/255),
            Color(red: 153/255, green: 129/255, blue: 0/255),
            Color(red: 41/255, green: 160/255, blue: 0/255),
            Color(red: 137/255, green: 74/255, blue: 0/255),
            Color(red: 153/255, green: 129/255, blue: 0/255),
            Color(red: 117/255, green: 137/255, blue: 0/255),
            Color(red: 183/255, green: 29/255, blue: 84/255),
            Color(red: 153/255, green: 129/255, blue: 0/255),
            Color(red: 29/255, green: 183/255, blue: 36/255)
        ],
        meshLightPalette: [
            Color(red: 255/255, green: 132/255, blue: 139/255),
            Color(red: 255/255, green: 231/255, blue: 102/255),
            Color(red: 152/255, green: 255/255, blue: 117/255),
            Color(red: 252/255, green: 176/255, blue: 85/255),
            Color(red: 255/255, green: 231/255, blue: 102/255),
            Color(red: 228/255, green: 252/255, blue: 85/255),
            Color(red: 255/255, green: 147/255, blue: 186/255),
            Color(red: 255/255, green: 233/255, blue: 117/255),
            Color(red: 147/255, green: 255/255, blue: 152/255)
        ],
        accentColor: Color(red: 255/255, green: 215/255, blue: 0/255),
        glowColor: Color(red: 255/255, green: 215/255, blue: 0/255)
    )

    /// Crimson Theme
    static let crimsonEmber = AppTheme(
        id: "crimsonEmber",
        name: "Crimson",
        icon: "flame.fill",
        heroDarkGradient: [Color(red: 255/255, green: 51/255, blue: 102/255), Color(red: 178/255, green: 35/255, blue: 71/255)],
        heroLightGradient: [Color(red: 255/255, green: 61/255, blue: 122/255), Color(red: 255/255, green: 51/255, blue: 102/255)],
        meshDarkPalette: [
            Color(red: 148/255, green: 39/255, blue: 168/255),
            Color(red: 153/255, green: 6/255, blue: 42/255),
            Color(red: 160/255, green: 112/255, blue: 21/255),
            Color(red: 137/255, green: 0/255, blue: 75/255),
            Color(red: 153/255, green: 6/255, blue: 42/255),
            Color(red: 137/255, green: 6/255, blue: 0/255),
            Color(red: 128/255, green: 60/255, blue: 183/255),
            Color(red: 153/255, green: 20/255, blue: 53/255),
            Color(red: 183/255, green: 177/255, blue: 60/255)
        ],
        meshLightPalette: [
            Color(red: 240/255, green: 157/255, blue: 255/255),
            Color(red: 255/255, green: 132/255, blue: 163/255),
            Color(red: 255/255, green: 216/255, blue: 144/255),
            Color(red: 252/255, green: 119/255, blue: 192/255),
            Color(red: 255/255, green: 132/255, blue: 163/255),
            Color(red: 252/255, green: 125/255, blue: 119/255),
            Color(red: 216/255, green: 169/255, blue: 255/255),
            Color(red: 255/255, green: 144/255, blue: 172/255),
            Color(red: 255/255, green: 250/255, blue: 169/255)
        ],
        accentColor: Color(red: 255/255, green: 51/255, blue: 102/255),
        glowColor: Color(red: 255/255, green: 51/255, blue: 102/255)
    )

    /// Horizon Theme
    static let neonHorizon = AppTheme(
        id: "neonHorizon",
        name: "Horizon",
        icon: "sparkles",
        heroDarkGradient: [Color(red: 155/255, green: 93/255, blue: 229/255), Color(red: 108/255, green: 65/255, blue: 160/255)],
        heroLightGradient: [Color(red: 186/255, green: 111/255, blue: 255/255), Color(red: 155/255, green: 93/255, blue: 229/255)],
        meshDarkPalette: [
            Color(red: 64/255, green: 103/255, blue: 151/255),
            Color(red: 84/255, green: 39/255, blue: 137/255),
            Color(red: 144/255, green: 51/255, blue: 111/255),
            Color(red: 41/255, green: 26/255, blue: 123/255),
            Color(red: 84/255, green: 39/255, blue: 137/255),
            Color(red: 99/255, green: 26/255, blue: 123/255),
            Color(red: 82/255, green: 143/255, blue: 164/255),
            Color(red: 89/255, green: 49/255, blue: 137/255),
            Color(red: 164/255, green: 82/255, blue: 110/255)
        ],
        meshLightPalette: [
            Color(red: 182/255, green: 214/255, blue: 255/255),
            Color(red: 203/255, green: 162/255, blue: 251/255),
            Color(red: 255/255, green: 173/255, blue: 225/255),
            Color(red: 151/255, green: 137/255, blue: 226/255),
            Color(red: 203/255, green: 162/255, blue: 251/255),
            Color(red: 205/255, green: 137/255, blue: 226/255),
            Color(red: 191/255, green: 238/255, blue: 255/255),
            Color(red: 207/255, green: 171/255, blue: 251/255),
            Color(red: 255/255, green: 191/255, blue: 213/255)
        ],
        accentColor: Color(red: 155/255, green: 93/255, blue: 229/255),
        glowColor: Color(red: 155/255, green: 93/255, blue: 229/255)
    )

    /// Quantum Theme
    static let quantumVelvet = AppTheme(
        id: "quantumVelvet",
        name: "Quantum",
        icon: "moon.stars.fill",
        heroDarkGradient: [Color(red: 112/255, green: 41/255, blue: 230/255), Color(red: 78/255, green: 28/255, blue: 161/255)],
        heroLightGradient: [Color(red: 134/255, green: 49/255, blue: 255/255), Color(red: 112/255, green: 41/255, blue: 230/255)],
        meshDarkPalette: [
            Color(red: 32/255, green: 94/255, blue: 151/255),
            Color(red: 53/255, green: 1/255, blue: 138/255),
            Color(red: 144/255, green: 16/255, blue: 109/255),
            Color(red: 9/255, green: 0/255, blue: 124/255),
            Color(red: 53/255, green: 1/255, blue: 138/255),
            Color(red: 83/255, green: 0/255, blue: 124/255),
            Color(red: 51/255, green: 145/255, blue: 165/255),
            Color(red: 61/255, green: 15/255, blue: 138/255),
            Color(red: 165/255, green: 51/255, blue: 99/255)
        ],
        meshLightPalette: [
            Color(red: 154/255, green: 207/255, blue: 255/255),
            Color(red: 175/255, green: 128/255, blue: 253/255),
            Color(red: 255/255, green: 141/255, blue: 223/255),
            Color(red: 113/255, green: 104/255, blue: 227/255),
            Color(red: 175/255, green: 128/255, blue: 253/255),
            Color(red: 187/255, green: 104/255, blue: 227/255),
            Color(red: 166/255, green: 239/255, blue: 255/255),
            Color(red: 182/255, green: 140/255, blue: 253/255),
            Color(red: 255/255, green: 166/255, blue: 204/255)
        ],
        accentColor: Color(red: 112/255, green: 41/255, blue: 230/255),
        glowColor: Color(red: 112/255, green: 41/255, blue: 230/255)
    )

    /// Galactic Theme
    static let galacticPlasma = AppTheme(
        id: "galacticPlasma",
        name: "Galactic",
        icon: "sparkle",
        heroDarkGradient: [Color(red: 10/255, green: 230/255, blue: 255/255), Color(red: 7/255, green: 161/255, blue: 178/255)],
        heroLightGradient: [Color(red: 12/255, green: 255/255, blue: 255/255), Color(red: 10/255, green: 230/255, blue: 255/255)],
        meshDarkPalette: [
            Color(red: 13/255, green: 168/255, blue: 44/255),
            Color(red: 0/255, green: 137/255, blue: 153/255),
            Color(red: 0/255, green: 0/255, blue: 160/255),
            Color(red: 0/255, green: 137/255, blue: 110/255),
            Color(red: 0/255, green: 137/255, blue: 153/255),
            Color(red: 0/255, green: 82/255, blue: 137/255),
            Color(red: 49/255, green: 183/255, blue: 35/255),
            Color(red: 0/255, green: 137/255, blue: 153/255),
            Color(red: 80/255, green: 35/255, blue: 183/255)
        ],
        meshLightPalette: [
            Color(red: 137/255, green: 255/255, blue: 161/255),
            Color(red: 108/255, green: 240/255, blue: 255/255),
            Color(red: 122/255, green: 122/255, blue: 255/255),
            Color(red: 92/255, green: 252/255, blue: 220/255),
            Color(red: 108/255, green: 240/255, blue: 255/255),
            Color(red: 92/255, green: 188/255, blue: 252/255),
            Color(red: 162/255, green: 255/255, blue: 152/255),
            Color(red: 122/255, green: 241/255, blue: 255/255),
            Color(red: 183/255, green: 152/255, blue: 255/255)
        ],
        accentColor: Color(red: 10/255, green: 230/255, blue: 255/255),
        glowColor: Color(red: 10/255, green: 230/255, blue: 255/255)
    )

    /// Titanium Theme
    static let liquidTitanium = AppTheme(
        id: "liquidTitanium",
        name: "Titanium",
        icon: "hexagon.fill",
        heroDarkGradient: [Color(red: 180/255, green: 190/255, blue: 210/255), Color(red: 125/255, green: 133/255, blue: 147/255)],
        heroLightGradient: [Color(red: 216/255, green: 228/255, blue: 252/255), Color(red: 180/255, green: 190/255, blue: 210/255)],
        meshDarkPalette: [
            Color(red: 119/255, green: 138/255, blue: 134/255),
            Color(red: 104/255, green: 111/255, blue: 125/255),
            Color(red: 123/255, green: 111/255, blue: 132/255),
            Color(red: 92/255, green: 105/255, blue: 113/255),
            Color(red: 104/255, green: 111/255, blue: 125/255),
            Color(red: 92/255, green: 92/255, blue: 113/255),
            Color(red: 133/255, green: 151/255, blue: 141/255),
            Color(red: 106/255, green: 113/255, blue: 125/255),
            Color(red: 148/255, green: 133/255, blue: 151/255)
        ],
        meshLightPalette: [
            Color(red: 236/255, green: 254/255, blue: 250/255),
            Color(red: 211/255, green: 217/255, blue: 231/255),
            Color(red: 234/255, green: 223/255, blue: 242/255),
            Color(red: 188/255, green: 200/255, blue: 207/255),
            Color(red: 211/255, green: 217/255, blue: 231/255),
            Color(red: 188/255, green: 188/255, blue: 207/255),
            Color(red: 239/255, green: 255/255, blue: 246/255),
            Color(red: 213/255, green: 219/255, blue: 231/255),
            Color(red: 252/255, green: 239/255, blue: 255/255)
        ],
        accentColor: Color(red: 180/255, green: 190/255, blue: 210/255),
        glowColor: Color(red: 180/255, green: 190/255, blue: 210/255)
    )

    /// Abyssal Theme
    static let abyssalGlow = AppTheme(
        id: "abyssalGlow",
        name: "Abyssal",
        icon: "water.waves",
        heroDarkGradient: [Color(red: 20/255, green: 255/255, blue: 120/255), Color(red: 14/255, green: 178/255, blue: 84/255)],
        heroLightGradient: [Color(red: 24/255, green: 255/255, blue: 144/255), Color(red: 20/255, green: 255/255, blue: 120/255)],
        meshDarkPalette: [
            Color(red: 90/255, green: 168/255, blue: 19/255),
            Color(red: 0/255, green: 153/255, blue: 65/255),
            Color(red: 0/255, green: 108/255, blue: 160/255),
            Color(red: 0/255, green: 137/255, blue: 17/255),
            Color(red: 0/255, green: 153/255, blue: 65/255),
            Color(red: 0/255, green: 137/255, blue: 99/255),
            Color(red: 151/255, green: 183/255, blue: 41/255),
            Color(red: 0/255, green: 153/255, blue: 65/255),
            Color(red: 41/255, green: 94/255, blue: 183/255)
        ],
        meshLightPalette: [
            Color(red: 195/255, green: 255/255, blue: 142/255),
            Color(red: 113/255, green: 255/255, blue: 174/255),
            Color(red: 128/255, green: 213/255, blue: 255/255),
            Color(red: 98/255, green: 252/255, blue: 118/255),
            Color(red: 113/255, green: 255/255, blue: 174/255),
            Color(red: 98/255, green: 252/255, blue: 210/255),
            Color(red: 232/255, green: 255/255, blue: 156/255),
            Color(red: 128/255, green: 255/255, blue: 182/255),
            Color(red: 156/255, green: 193/255, blue: 255/255)
        ],
        accentColor: Color(red: 20/255, green: 255/255, blue: 120/255),
        glowColor: Color(red: 20/255, green: 255/255, blue: 120/255)
    )


    /// All themes in display order
    static let all: [AppTheme] = [
        .buxDefault, .midnightOcean, .sunsetVibes, .emeraldCyber,
        .sakuraDream, .goldPrestige, .crimsonEmber, .neonHorizon,
        .quantumVelvet, .galacticPlasma, .liquidTitanium, .abyssalGlow
    ]
}

// MARK: - ThemeManager

public final class ThemeManager: ObservableObject {
    @Published var current: AppTheme = .buxDefault
    @Published private(set) var workspaceThemeOverrideActive: Bool = false
    var onThemeChanged: ((AppTheme) -> Void)?

    public init() {
        let store = SettingsStore.shared
        if store.brandThemesEnabled {
            current = store.resolvedBrandTheme()
        } else {
            current = AppTheme.standardNeutral(accent: store.resolvedSystemAccent())
        }

        #if canImport(UIKit)
        if let searchIcon = UIImage(systemName: "magnifyingglass")?.withRenderingMode(.alwaysTemplate) {
            UISearchBar.appearance().setImage(searchIcon, for: .search, state: .normal)
        }
        if let clearIcon = UIImage(systemName: "xmark.circle.fill")?.withRenderingMode(.alwaysTemplate) {
            UISearchBar.appearance().setImage(clearIcon, for: .clear, state: .normal)
        }
        #endif
    }

    /// Select a theme with a smooth animated transition
    @MainActor
    func select(_ theme: AppTheme) {
        SettingsStore.shared.persistThemeSelection(theme, themeManager: self)
    }

    func applyTheme(_ theme: AppTheme) {
        setCurrentThemeWithoutPersistence(theme)
        onThemeChanged?(theme)
    }

    /// Virtual-desktop theme — does not persist to Appearance settings or SwiftData.
    @MainActor
    func applyTransientTheme(_ theme: AppTheme) {
        workspaceThemeOverrideActive = true
        setCurrentThemeWithoutPersistence(theme)
    }

    @MainActor
    func restoreGlobalAppearance() {
        workspaceThemeOverrideActive = false
        let store = SettingsStore.shared
        if store.brandThemesEnabled {
            setCurrentThemeWithoutPersistence(store.resolvedBrandTheme())
        } else {
            setCurrentThemeWithoutPersistence(AppTheme.standardNeutral(accent: store.resolvedSystemAccent()))
        }
    }

    @MainActor
    func updateThemeForActiveWorkspace() {
        let store = SettingsStore.shared
        guard store.sideHustleMatrixEnabled,
              let activeId = HustleManager.shared.selectedHustleId,
              let hustle = HustleManager.shared.hustles.first(where: { $0.id == activeId }),
              let themeId = hustle.themeName else {
            restoreGlobalAppearance()
            return
        }
        let theme = AppTheme.all.first(where: { $0.id == themeId })
            ?? AppTheme.all.first(where: { $0.name == themeId })
        guard let theme else {
            restoreGlobalAppearance()
            return
        }
        applyTransientTheme(theme)
    }

    private func setCurrentThemeWithoutPersistence(_ theme: AppTheme) {
        if SettingsStore.shared.reducedMotion {
            current = theme
        } else {
            withAnimation(BuxMotion.themeCrossfade) {
                current = theme
            }
        }
    }

    // MARK: - Unified surfaces (M3 material roles)

    func screenBackground(for colorScheme: ColorScheme) -> Color {
        materialScheme(for: colorScheme).surfaceContainerLow
    }

    func cardFill(for colorScheme: ColorScheme) -> Color {
        materialScheme(for: colorScheme).surface
    }

    /// Text fields, chips, and inline inputs — M3 surface-container-highest.
    func inputFieldFill(for colorScheme: ColorScheme) -> Color {
        materialScheme(for: colorScheme).surfaceContainerHighest
    }

    /// Segmented bar / sticky panel track — M3 surface-container.
    func panelBarFill(for colorScheme: ColorScheme) -> Color {
        materialScheme(for: colorScheme).surfaceContainer
    }

    /// Nested / emphasis blocks — M3 surface-container-highest.
    func themedCardFill(for colorScheme: ColorScheme) -> Color {
        materialScheme(for: colorScheme).surfaceContainerHighest
    }
    
    /// Readable accent for text, icons, toggles, and links — same hue family as `accentColor`, deeper when needed.
    /// Display chrome (swatches, glows, gradients, filled buttons) keeps `current.accentColor`.
    func readableAccentColor(for colorScheme: ColorScheme) -> Color {
        contrastAccentColor(for: colorScheme)
    }

    /// Returns a deeper, high-contrast version of the accent color for bright/neon themes.
    /// This ensures critical interactive icons, toolbars, outlines, and buttons remain highly visible.
    func contrastAccentColor(for colorScheme: ColorScheme) -> Color {
        let store = SettingsStore.shared
        guard store.brandThemesEnabled || workspaceThemeOverrideActive else {
            return store.resolvedSystemAccentColor(for: colorScheme)
        }

        let accent = current.accentColor
        let surface = materialScheme(for: colorScheme).surface

        if let tuned = BuxReadableAccent.tunedOverride(themeId: current.id, colorScheme: colorScheme) {
            return tuned
        }

        if BuxReadableAccent.meetsContrast(accent, on: surface) {
            return accent
        }

        return BuxReadableAccent.adjustedAccent(
            accent,
            colorScheme: colorScheme,
            surface: surface
        )
    }

    /// M3 outline-variant — decorative card boundary.
    func themedCardStroke(for colorScheme: ColorScheme) -> Color {
        materialScheme(for: colorScheme).outlineVariant
    }

    /// Neutral card hairline — same M3 outline-variant.
    func subtleCardStroke(for colorScheme: ColorScheme) -> Color {
        materialScheme(for: colorScheme, branded: false).outlineVariant
    }

    func cardOutlineStroke(for colorScheme: ColorScheme, branded: Bool) -> Color {
        materialScheme(for: colorScheme, branded: branded).outlineVariant
    }

    /// Elevation-aware chrome — M3 Outlined (card) vs Elevated (hero).
    func cardChrome(for elevation: BuxElevation, colorScheme: ColorScheme, branded: Bool) -> BuxCardChromeMetrics {
        let outline = materialScheme(for: colorScheme, branded: branded).outlineVariant

        switch elevation {
        case .flat:
            return BuxCardChromeMetrics()
        case .card:
            return BuxCardChromeMetrics(
                stroke: outline,
                strokeWidth: 0.5,
                shadowColor: .clear,
                shadowRadius: 0,
                shadowY: 0
            )
        case .hero:
            let shadow = heroCardShadow(for: colorScheme)
            return BuxCardChromeMetrics(
                stroke: outline,
                strokeWidth: 0.5,
                shadowColor: shadow.color,
                shadowRadius: shadow.radius,
                shadowY: shadow.y
            )
        }
    }

    func pillInactiveLabelColor(for colorScheme: ColorScheme) -> Color {
        labelTertiary(for: colorScheme)
    }

    func labelTertiary(for colorScheme: ColorScheme) -> Color {
        materialScheme(for: colorScheme).onSurfaceVariant.opacity(0.88)
    }

    func chevronMuted(for colorScheme: ColorScheme) -> Color {
        materialScheme(for: colorScheme).onSurfaceVariant.opacity(0.72)
    }

    /// Dismiss / icon chip on custom sheets (not card faces).
    func chipMutedFill(for colorScheme: ColorScheme) -> Color {
        materialScheme(for: colorScheme).surfaceContainerHighest
    }

    func sectionHeaderColor(for colorScheme: ColorScheme) -> Color {
        materialScheme(for: colorScheme).onSurfaceVariant
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

// MARK: - Readable accent tuning (text / tint only — display accent unchanged)

private enum BuxReadableAccent {
    private static let targetContrast: CGFloat = 4.5

    static func tunedOverride(themeId: String, colorScheme: ColorScheme) -> Color? {
        switch (themeId, colorScheme) {
        case ("abyssalGlow", .light):
            return Color(red: 0/255, green: 140/255, blue: 60/255)
        case ("abyssalGlow", .dark):
            return Color(red: 36/255, green: 210/255, blue: 118/255)
        case ("galacticPlasma", .light):
            return Color(red: 0/255, green: 120/255, blue: 170/255)
        case ("galacticPlasma", .dark):
            return Color(red: 72/255, green: 210/255, blue: 228/255)
        case ("sakuraDream", .light):
            return Color(red: 215/255, green: 75/255, blue: 105/255)
        case ("sakuraDream", .dark):
            return Color(red: 255/255, green: 148/255, blue: 168/255)
        case ("goldPrestige", .light):
            return Color(red: 185/255, green: 130/255, blue: 0/255)
        case ("goldPrestige", .dark):
            return Color(red: 255/255, green: 198/255, blue: 48/255)
        case ("emeraldCyber", .light):
            return Color(red: 0/255, green: 135/255, blue: 70/255)
        case ("emeraldCyber", .dark):
            return Color(red: 48/255, green: 220/255, blue: 148/255)
        case ("liquidTitanium", .light):
            return Color(red: 74/255, green: 95/255, blue: 128/255)
        case ("liquidTitanium", .dark):
            return Color(red: 168/255, green: 182/255, blue: 210/255)
        default:
            return nil
        }
    }

    static func meetsContrast(_ accent: Color, on surface: Color) -> Bool {
        contrastRatio(accent, surface) >= targetContrast
    }

    static func adjustedAccent(
        _ accent: Color,
        colorScheme: ColorScheme,
        surface: Color
    ) -> Color {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        guard rgbaComponents(accent, hue: &hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) else {
            return accent
        }

        let steps = 14
        for step in 1...steps {
            let progress = CGFloat(step) / CGFloat(steps)
            let candidate: Color
            if colorScheme == .light {
                let newBrightness = max(0.20, brightness * (1 - progress * 0.55))
                let newSaturation = min(1, max(saturation, 0.42 + progress * 0.18))
                candidate = Color(hue: Double(hue), saturation: Double(newSaturation), brightness: Double(newBrightness), opacity: Double(alpha))
            } else {
                let newBrightness = min(0.94, brightness + progress * (0.94 - brightness))
                let newSaturation = min(1, max(saturation, 0.35))
                candidate = Color(hue: Double(hue), saturation: Double(newSaturation), brightness: Double(newBrightness), opacity: Double(alpha))
            }
            if meetsContrast(candidate, on: surface) {
                return candidate
            }
        }

        if colorScheme == .light {
            return Color(hue: Double(hue), saturation: Double(min(1, max(saturation, 0.5))), brightness: 0.28, opacity: Double(alpha))
        }
        return Color(hue: Double(hue), saturation: Double(min(1, max(saturation, 0.45))), brightness: 0.88, opacity: Double(alpha))
    }

    private static func contrastRatio(_ foreground: Color, _ background: Color) -> CGFloat {
        let fg = relativeLuminance(foreground)
        let bg = relativeLuminance(background)
        let lighter = max(fg, bg)
        let darker = min(fg, bg)
        return (lighter + 0.05) / (darker + 0.05)
    }

    private static func relativeLuminance(_ color: Color) -> CGFloat {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        guard rgbComponents(color, red: &r, green: &g, blue: &b, alpha: &a) else { return 0 }

        func channel(_ value: CGFloat) -> CGFloat {
            if value <= 0.03928 { return value / 12.92 }
            return pow((value + 0.055) / 1.055, 2.4)
        }

        return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b)
    }

    private static func rgbComponents(
        _ color: Color,
        red: inout CGFloat,
        green: inout CGFloat,
        blue: inout CGFloat,
        alpha: inout CGFloat
    ) -> Bool {
        #if canImport(UIKit)
        let ui = UIColor(color)
        return ui.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        #else
        return false
        #endif
    }

    private static func rgbaComponents(
        _ color: Color,
        hue: inout CGFloat,
        saturation: inout CGFloat,
        brightness: inout CGFloat,
        alpha: inout CGFloat
    ) -> Bool {
        #if canImport(UIKit)
        let ui = UIColor(color)
        return ui.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        #else
        return false
        #endif
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
