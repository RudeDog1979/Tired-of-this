//
//  EmotionalListCardChrome.swift
//  BuxMuse
//
//  Lightweight list-row emotion styling — M3 flat tint wash, Equatable.
//

import SwiftUI

/// Scroll-optimized emotion chrome for expense list cards.
struct EmotionalListCardChrome: View, Equatable {
    let cornerRadius: CGFloat
    let isDark: Bool
    let base: Color
    let fallbackStroke: Color
    let emotionId: String
    let symbol: String

    var body: some View {
        let scheme: ColorScheme = isDark ? .dark : .light
        let tint = EmotionalTagAppearance.accent(for: emotionId, colorScheme: scheme) ?? .gray
        let stroke = EmotionalTagAppearance.cardStroke(for: emotionId, colorScheme: scheme, fallback: fallbackStroke)
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        shape
            .fill(base)
            .overlay {
                shape.fill(tint.opacity(isDark ? 0.14 : 0.10))
            }
            .overlay(alignment: .bottomTrailing) {
                Image(systemName: symbol)
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundColor(tint.opacity(isDark ? 0.12 : 0.09))
                    .padding(8)
            }
            .clipShape(shape)
            .overlay(shape.stroke(stroke, lineWidth: 0.5))
    }
}

struct PlainExpenseListCardChrome: View, Equatable {
    let cornerRadius: CGFloat
    let base: Color
    let stroke: Color
    var themeWash: Color? = nil

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        shape
            .fill(base)
            .overlay(shape.stroke(stroke, lineWidth: 0.5))
    }
}

/// No-mood list rows — M3 flat accent wash.
struct ThemedPlainListCardChrome: View, Equatable {
    let cornerRadius: CGFloat
    let isDark: Bool
    let base: Color
    let stroke: Color
    let accent: Color
    let meshWash: Color

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        shape
            .fill(base)
            .overlay {
                shape.fill(accent.opacity(isDark ? 0.12 : 0.08))
            }
            .clipShape(shape)
            .overlay(shape.stroke(stroke, lineWidth: 0.5))
    }
}

// MARK: - List row chrome (M3 surfaces — Expenses, Studio, Home)

struct BuxThemedListRowChromeModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.expensesEnhancedTint) private var expensesEnhancedTint
    @Environment(\.studioEnhancedTint) private var studioEnhancedTint
    @Environment(\.dashboardEnhancedTint) private var dashboardEnhancedTint
    @EnvironmentObject private var themeManager: ThemeManager
    @ObservedObject private var settings = SettingsStore.shared

    let cornerRadius: CGFloat
    var emotionId: String?
    var emotionSymbol: String?

    private var usesThemedListChrome: Bool {
        settings.brandThemesEnabled || expensesEnhancedTint || studioEnhancedTint || dashboardEnhancedTint
    }

    private var hasActiveEmotion: Bool {
        guard let emotionId, let emotionSymbol else { return false }
        return !emotionId.isEmpty && !emotionSymbol.isEmpty
    }

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let base = themeManager.cardFill(for: colorScheme)
        let fallbackStroke = themeManager.subtleCardStroke(for: colorScheme)
        let isDark = colorScheme == .dark

        if hasActiveEmotion, let emotionId, let emotionSymbol {
            content
                .background {
                    EmotionalListCardChrome(
                        cornerRadius: cornerRadius,
                        isDark: isDark,
                        base: base,
                        fallbackStroke: fallbackStroke,
                        emotionId: emotionId,
                        symbol: emotionSymbol
                    )
                    .equatable()
                }
                .clipShape(shape)
        } else if usesThemedListChrome {
            content
                .buxMaterialCardChrome(.outlined, cornerRadius: cornerRadius)
        } else {
            content
                .background {
                    PlainExpenseListCardChrome(
                        cornerRadius: cornerRadius,
                        base: base,
                        stroke: fallbackStroke
                    )
                    .equatable()
                }
                .clipShape(shape)
        }
    }
}

/// Expense rows — forwards to shared list chrome.
struct ExpenseListCardChromeModifier: ViewModifier {
    let cornerRadius: CGFloat
    var emotionId: String?
    var emotionSymbol: String?

    func body(content: Content) -> some View {
        content.modifier(
            BuxThemedListRowChromeModifier(
                cornerRadius: cornerRadius,
                emotionId: emotionId,
                emotionSymbol: emotionSymbol
            )
        )
    }
}
