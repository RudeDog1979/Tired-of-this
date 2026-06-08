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

    /// Extra list top inset so large title + search drawer sit above scroll content (Studio invoices).
    static let invoicesNavChromeScrollInset: CGFloat = 16

    /// Nudge Studio branded `.largeTitle` down vs system default (tune here only).
    static let studioRootTabNavTitleTopInset: CGFloat = 16

    /// Simple Studio iOS 26 — nudge scroll content below custom title + subtitle (tune here only).
    static let simpleStudioRootTabScrollTopInset: CGFloat = 28

    /// Home dashboard — no visible nav bar; reserve large-title band so greeting aligns with Expenses (tune here only).
    static let dashboardRootTabScrollTopInset: CGFloat = 52

    static let sheetBottomClearance: CGFloat = BuxTokens.sheetBottomClearance

    static func horizontalMargin(for width: CGFloat) -> CGFloat {
        BuxTokens.horizontalMargin(for: width)
    }
}

struct BuxContainerWidthKey: PreferenceKey {
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
            .buxRootScrollEdgeChrome()
    }

    /// Same horizontal inset as Expenses list — use on Dashboard `ScrollView` and Expenses `List`.
    func buxScrollContentMargins() -> some View {
        buxListContentMargins()
    }

    /// Root tab scroll chrome — Studio, Home, Settings-style screens.
    func buxRootTabScrollChrome() -> some View {
        buxScrollContentMargins()
            .buxReportsContainerWidth()
            .buxRootScrollEdgeChrome()
    }

    /// Detail hubs & pushed drill-ins — content scrolls under inline nav bar.
    func buxDetailScrollChrome() -> some View {
        buxReportsContainerWidth()
            .buxSoftScrollChrome(edges: .top)
    }

    /// Adaptive horizontal margins — prefer on all root screens.
    func buxAdaptiveMargins() -> some View {
        buxScreenContentMargins()
    }

    func buxCardOutline(themeManager: ThemeManager, colorScheme: ColorScheme, cornerRadius: CGFloat) -> some View {
        overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(themeManager.themedCardStroke(for: colorScheme), lineWidth: 1)
        )
    }

    /// Hero elevation — soft Apple Music shadow. Use on large static cards only.
    func buxHeroElevation(themeManager: ThemeManager, colorScheme: ColorScheme, cornerRadius: CGFloat = BuxTokens.Radius.hero) -> some View {
        buxSurface(elevation: .hero, themeManager: themeManager, colorScheme: colorScheme, cornerRadius: cornerRadius)
    }

    func buxReportsContainerWidth() -> some View {
        background {
            GeometryReader { geo in
                Color.clear.preference(key: BuxContainerWidthKey.self, value: geo.size.width)
            }
        }
    }
}
