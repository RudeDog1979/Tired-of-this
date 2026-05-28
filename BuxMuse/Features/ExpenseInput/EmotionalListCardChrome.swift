//
//  EmotionalListCardChrome.swift
//  BuxMuse
//
//  Lightweight list-row emotion styling — single gradient, icon watermark, Equatable.
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
                LinearGradient(
                    colors: [
                        tint.opacity(isDark ? 0.20 : 0.16),
                        tint.opacity(isDark ? 0.06 : 0.04),
                        .clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            .overlay(alignment: .bottomTrailing) {
                Image(systemName: symbol)
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundColor(tint.opacity(isDark ? 0.12 : 0.09))
                    .padding(8)
            }
            .clipShape(shape)
            .overlay(shape.stroke(stroke, lineWidth: 1.5))
    }
}

struct PlainExpenseListCardChrome: View, Equatable {
    let cornerRadius: CGFloat
    let base: Color
    let stroke: Color
    /// Light mesh wash when Expenses tab enhanced tint is active.
    var themeWash: Color? = nil

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        shape
            .fill(base)
            .overlay {
                if let themeWash {
                    shape.fill(themeWash)
                }
            }
            .overlay(shape.stroke(stroke, lineWidth: 1))
    }
}

/// No-mood list rows — theme accent + mesh wash (same layout language as `EmotionalListCardChrome`).
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
                shape.fill(meshWash.opacity(isDark ? 0.88 : 0.52))
            }
            .overlay {
                LinearGradient(
                    colors: [
                        accent.opacity(isDark ? 0.22 : 0.16),
                        accent.opacity(isDark ? 0.08 : 0.05),
                        .clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            .clipShape(shape)
            .overlay(shape.stroke(stroke, lineWidth: 1))
    }
}

// MARK: - List row chrome (solid card on mesh screen — Expenses, Studio, Home)

struct BuxThemedListRowChromeModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.expensesEnhancedTint) private var expensesEnhancedTint
    @Environment(\.studioEnhancedTint) private var studioEnhancedTint
    @Environment(\.dashboardEnhancedTint) private var dashboardEnhancedTint
    @EnvironmentObject private var themeManager: ThemeManager

    let cornerRadius: CGFloat
    var emotionId: String?
    var emotionSymbol: String?

    private var usesThemedListChrome: Bool {
        expensesEnhancedTint || studioEnhancedTint || dashboardEnhancedTint
    }

    private var activeMeshWash: Color {
        if expensesEnhancedTint {
            return DashboardThemeTint.expensesSurfaceWash(themeManager: themeManager, colorScheme: colorScheme)
        }
        if studioEnhancedTint {
            return DashboardThemeTint.studioSurfaceWash(themeManager: themeManager, colorScheme: colorScheme)
        }
        return DashboardThemeTint.dashboardSurfaceWash(themeManager: themeManager, colorScheme: colorScheme)
    }

    private var hasActiveEmotion: Bool {
        guard let emotionId, let emotionSymbol else { return false }
        return !emotionId.isEmpty && !emotionSymbol.isEmpty
    }

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let base = themeManager.cardFill(for: colorScheme)
        let fallbackStroke = themeManager.subtleCardStroke(for: colorScheme)
        let shadow = themeManager.listCardShadow(for: colorScheme)
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
                .shadow(color: shadow.color, radius: shadow.radius, x: 0, y: shadow.y)
        } else if usesThemedListChrome {
            let stroke = DashboardThemeTint.themedCardStroke(
                themeManager: themeManager,
                colorScheme: colorScheme
            )
            content
                .background {
                    ThemedPlainListCardChrome(
                        cornerRadius: cornerRadius,
                        isDark: isDark,
                        base: base,
                        stroke: stroke,
                        accent: themeManager.current.accentColor,
                        meshWash: activeMeshWash
                    )
                    .equatable()
                }
                .clipShape(shape)
                .shadow(color: shadow.color, radius: shadow.radius, x: 0, y: shadow.y)
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
