//
//  BuxLayout.swift
//  BuxMuse
//
//  HIG-aligned spacing tokens (8pt grid, system layout margins).
//

import SwiftUI

enum BuxLayout {
    static let unit: CGFloat = 8
    static let marginHorizontal: CGFloat = 20
    static let marginHorizontalCompact: CGFloat = 16
    static let compactWidthThreshold: CGFloat = 360
    static let section: CGFloat = 16
    static let tight: CGFloat = 8
    static let loose: CGFloat = 24
    static let cornerHero: CGFloat = 32
    static let cornerCard: CGFloat = 16
    static let cornerGrouped: CGFloat = 10
    static let minTapTarget: CGFloat = 44
    static let pillHeight: CGFloat = 48
    static let pillInnerInset: CGFloat = 4
    static let pillSelectionInset: CGFloat = 4
    static let dashboardSmallCardHeight: CGFloat = 152

    /// Unified hero card height — both carousel pages share this slot (no jump on swipe).
    static let expenseHeroSummaryHeight: CGFloat = 290

    /// Shared corner radius for expense hero carousel cards.
    static let expenseHeroCardCornerRadius: CGFloat = 20

    /// Vertical room below hero cards so list rows don't clip shadows.
    static let expenseHeroShadowBleed: CGFloat = 12

    static func horizontalMargin(for width: CGFloat) -> CGFloat {
        width < compactWidthThreshold ? marginHorizontalCompact : marginHorizontal
    }
}

private struct BuxContainerWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct BuxAdaptiveHorizontalPaddingModifier: ViewModifier {
    @State private var margin: CGFloat = BuxLayout.marginHorizontal

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, margin)
            .onPreferenceChange(BuxContainerWidthKey.self) { width in
                guard width > 0 else { return }
                let next = BuxLayout.horizontalMargin(for: width)
                if abs(next - margin) > 0.5 { margin = next }
            }
    }
}

private struct BuxListContentMarginsModifier: ViewModifier {
    @State private var margin: CGFloat = BuxLayout.marginHorizontal

    func body(content: Content) -> some View {
        content
            .contentMargins(.horizontal, margin, for: .scrollContent)
            .onPreferenceChange(BuxContainerWidthKey.self) { width in
                guard width > 0 else { return }
                let next = BuxLayout.horizontalMargin(for: width)
                if abs(next - margin) > 0.5 { margin = next }
            }
    }
}

extension View {
    func buxScreenContentMargins() -> some View {
        modifier(BuxAdaptiveHorizontalPaddingModifier())
    }

    func buxListContentMargins() -> some View {
        modifier(BuxListContentMarginsModifier())
    }

    /// Same horizontal inset as Expenses list — use on Dashboard `ScrollView` and Expenses `List`.
    func buxScrollContentMargins() -> some View {
        buxListContentMargins()
    }

    func buxCardOutline(themeManager: ThemeManager, colorScheme: ColorScheme, cornerRadius: CGFloat) -> some View {
        overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(themeManager.subtleCardStroke(for: colorScheme), lineWidth: 1)
        )
    }

    func buxReportsContainerWidth() -> some View {
        background {
            GeometryReader { geo in
                Color.clear.preference(key: BuxContainerWidthKey.self, value: geo.size.width)
            }
        }
    }
}
