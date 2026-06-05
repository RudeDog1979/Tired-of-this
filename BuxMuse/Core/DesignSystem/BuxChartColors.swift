//
//  BuxChartColors.swift
//  BuxMuse Design System
//
//  Semantic chart palette — independent of brand theme accent.
//

import SwiftUI

enum BuxChartColors {
    // MARK: - Trend lines

    static func spendTrend(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 72/255, green: 172/255, blue: 255/255)
            : Color(red: 58/255, green: 108/255, blue: 212/255)
    }

    static func inflowTrend(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 72/255, green: 210/255, blue: 160/255)
            : Color(red: 36/255, green: 158/255, blue: 108/255)
    }

    // MARK: - Comparison deltas (aligned with Expenses hero badge)

    static let comparisonUp = Color.orange
    static let comparisonDown = Color(red: 46/255, green: 204/255, blue: 113/255)

    // MARK: - Categories

    static func color(for category: TransactionCategory) -> Color {
        if let named = ExpenseCategoryCatalog.systemDefinitions.first(where: { $0.0 == category })?.color,
           let resolved = namedColor(named) {
            return resolved
        }
        return categoryPalette[0]
    }

    static func color(
        forCategoryName name: String,
        customCategories: [ExpenseCategoryRecord] = [],
        fallbackIndex: Int = 0
    ) -> Color {
        let catalogColor = ExpenseCategoryCatalog.catalogColorName(
            forDisplayName: name,
            customCategories: customCategories
        )
        if let resolved = namedColor(catalogColor) {
            return resolved
        }
        if let match = ExpenseCategoryCatalog.category(forDisplayName: name) {
            return color(for: match)
        }
        return categoryPalette[abs(fallbackIndex) % categoryPalette.count]
    }

    static let categoryPalette: [Color] = [
        Color(red: 88/255, green: 168/255, blue: 255/255),
        Color(red: 255/255, green: 149/255, blue: 87/255),
        Color(red: 52/255, green: 199/255, blue: 89/255),
        Color(red: 175/255, green: 122/255, blue: 255/255),
        Color(red: 255/255, green: 105/255, blue: 130/255),
        Color(red: 90/255, green: 200/255, blue: 190/255),
        Color(red: 255/255, green: 204/255, blue: 88/255),
        Color(red: 160/255, green: 124/255, blue: 96/255)
    ]

    // MARK: - Merchants

    static func merchantColor(fallbackIndex: Int) -> Color {
        merchantPalette[abs(fallbackIndex) % merchantPalette.count]
    }

    static let merchantPalette: [Color] = [
        Color(red: 255/255, green: 159/255, blue: 64/255),
        Color(red: 255/255, green: 128/255, blue: 104/255),
        Color(red: 255/255, green: 183/255, blue: 77/255),
        Color(red: 242/255, green: 139/255, blue: 130/255),
        Color(red: 255/255, green: 149/255, blue: 120/255)
    ]

    // MARK: - Named category colors (ExpenseCategoryRecord / catalog)

    static func namedColor(_ name: String) -> Color? {
        switch name.lowercased() {
        case "red": return Color(red: 255/255, green: 92/255, blue: 92/255)
        case "green": return Color(red: 52/255, green: 199/255, blue: 89/255)
        case "orange": return Color(red: 255/255, green: 149/255, blue: 0/255)
        case "blue": return Color(red: 58/255, green: 108/255, blue: 212/255)
        case "purple": return Color(red: 175/255, green: 82/255, blue: 222/255)
        case "brown": return Color(red: 162/255, green: 124/255, blue: 96/255)
        case "mint": return Color(red: 0/255, green: 199/255, blue: 190/255)
        case "gray", "grey": return Color(red: 142/255, green: 142/255, blue: 147/255)
        case "pink": return Color(red: 255/255, green: 105/255, blue: 130/255)
        case "teal": return Color(red: 48/255, green: 176/255, blue: 199/255)
        case "cyan": return Color(red: 50/255, green: 173/255, blue: 230/255)
        case "yellow": return Color(red: 255/255, green: 204/255, blue: 0/255)
        default: return nil
        }
    }

    // MARK: - Trend gradients

    static func spendTrendGradient(for colorScheme: ColorScheme) -> LinearGradient {
        let base = spendTrend(for: colorScheme)
        let topOpacity = colorScheme == .dark ? 0.36 : 0.30
        return LinearGradient(
            colors: [base.opacity(topOpacity), base.opacity(0.08), base.opacity(0)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    static func spendTrendLineGradient(for colorScheme: ColorScheme) -> LinearGradient {
        let base = spendTrend(for: colorScheme)
        return LinearGradient(
            colors: [base.opacity(0.72), base, base.opacity(0.88)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    static func spendTrendGlow(for colorScheme: ColorScheme) -> Color {
        spendTrend(for: colorScheme).opacity(colorScheme == .dark ? 0.22 : 0.14)
    }

    // MARK: - Category / merchant gradients

    static func categoryGradient(for category: TransactionCategory) -> LinearGradient {
        let tint = color(for: category)
        return LinearGradient(
            colors: [tint, tint.opacity(0.58)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    static func categoryGradient(
        forCategoryName name: String,
        customCategories: [ExpenseCategoryRecord] = [],
        fallbackIndex: Int = 0
    ) -> LinearGradient {
        let tint = color(forCategoryName: name, customCategories: customCategories, fallbackIndex: fallbackIndex)
        return LinearGradient(
            colors: [tint, tint.opacity(0.58)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    static func merchantGradient(fallbackIndex: Int) -> LinearGradient {
        let tint = merchantColor(fallbackIndex: fallbackIndex)
        return LinearGradient(
            colors: [tint.opacity(0.95), tint.opacity(0.62)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    static func donutSegmentGradient(
        forCategoryName name: String,
        customCategories: [ExpenseCategoryRecord] = [],
        fallbackIndex: Int
    ) -> AngularGradient {
        let tint = color(forCategoryName: name, customCategories: customCategories, fallbackIndex: fallbackIndex)
        return AngularGradient(
            colors: [tint.opacity(0.72), tint, tint.opacity(0.82)],
            center: .center
        )
    }

    static func donutSegmentStroke(
        forCategoryName name: String,
        customCategories: [ExpenseCategoryRecord] = [],
        fallbackIndex: Int
    ) -> Color {
        color(forCategoryName: name, customCategories: customCategories, fallbackIndex: fallbackIndex).opacity(0.35)
    }

    // MARK: - Heat zones (spending analysis)

    enum HeatZoneLevel: Sendable {
        case high
        case warning
        case safe
    }

    static let heatZoneHigh = Color(red: 255/255, green: 138/255, blue: 61/255)
    static let heatZoneWarning = Color(red: 255/255, green: 204/255, blue: 72/255)
    static let heatZoneSafe = Color(red: 62/255, green: 207/255, blue: 126/255)

    static func heatZoneColor(_ level: HeatZoneLevel) -> Color {
        switch level {
        case .high: heatZoneHigh
        case .warning: heatZoneWarning
        case .safe: heatZoneSafe
        }
    }

    static func heatZoneGradient(_ level: HeatZoneLevel) -> LinearGradient {
        let tint = heatZoneColor(level)
        return LinearGradient(
            colors: [tint.opacity(0.92), tint.opacity(0.65)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}
