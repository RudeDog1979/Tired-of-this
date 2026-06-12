//
//  BuxSystemAccent.swift
//  BuxMuse Design System
//
//  Apple-style accent palette for neutral (Brand Themes off) mode.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

enum BuxSystemAccent: String, CaseIterable, Identifiable {
    case systemBlue
    case green
    case orange
    case pink
    case purple
    case red
    case teal
    case indigo
    case mint
    case cyan
    case yellow

    var id: String { rawValue }

    /// English catalog key (`Blue`, `Green`, …).
    var displayNameKey: String {
        switch self {
        case .systemBlue: return "Blue"
        case .green: return "Green"
        case .orange: return "Orange"
        case .pink: return "Pink"
        case .purple: return "Purple"
        case .red: return "Red"
        case .teal: return "Teal"
        case .indigo: return "Indigo"
        case .mint: return "Mint"
        case .cyan: return "Cyan"
        case .yellow: return "Yellow"
        }
    }

    func localizedDisplayName(locale: Locale) -> String {
        BuxCatalogLabel.string(displayNameKey, locale: locale)
    }

    static func resolve(id: String) -> BuxSystemAccent {
        BuxSystemAccent(rawValue: id) ?? .systemBlue
    }

    /// Semantic system colors — iOS adjusts light vs dark automatically.
    func color(for colorScheme: ColorScheme) -> Color {
        Color(uiColor: uiColor)
    }

    /// Dynamic UIColor for legacy `AppTheme.accentColor` call sites.
    var uiColor: UIColor {
        switch self {
        case .systemBlue: return .systemBlue
        case .green: return .systemGreen
        case .orange: return .systemOrange
        case .pink: return .systemPink
        case .purple: return .systemPurple
        case .red: return .systemRed
        case .teal: return .systemTeal
        case .indigo: return .systemIndigo
        case .mint: return .systemMint
        case .cyan: return .systemCyan
        case .yellow: return .systemYellow
        }
    }
}
