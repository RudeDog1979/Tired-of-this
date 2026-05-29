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

    static func color(forCategoryName name: String, fallbackIndex: Int = 0) -> Color {
        if let match = TransactionCategory.allCases.first(where: { $0.displayName == name }) {
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
}
