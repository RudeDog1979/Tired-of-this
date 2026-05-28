//
//  ExpensesSummaryCard.swift
//  BuxMuse
//

import SwiftUI

struct ExpensesSummaryCard: View {
    let display: ExpensesSummaryDisplay
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var themeManager: ThemeManager

    @State private var isVisible = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Monthly Summary")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                .heroSummaryReveal(isVisible: isVisible, delay: 0)

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Top Categories")
                        .font(.caption.bold())
                        .foregroundColor(.gray)
                    CategoryBreakdownChart(breakdown: display.categoryBreakdown)
                        .frame(height: 72)
                }
                .heroSummaryReveal(isVisible: isVisible, delay: 0.06)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Top Merchants")
                        .font(.caption.bold())
                        .foregroundColor(.gray)
                    MerchantBreakdownChart(breakdown: display.merchantBreakdown)
                        .frame(height: 72)
                }
                .heroSummaryReveal(isVisible: isVisible, delay: 0.1)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Trend")
                    .font(.caption.bold())
                    .foregroundColor(.gray)
                MonthlyTrendChart(points: display.trendPoints, prediction: display.prediction)
                    .frame(height: 72)
            }
            .heroSummaryReveal(isVisible: isVisible, delay: 0.14)
        }
        .expenseHeroCardChrome(themeManager: themeManager, colorScheme: colorScheme)
        .frame(
            maxWidth: .infinity,
            minHeight: BuxLayout.expenseHeroSummaryHeight,
            alignment: .topLeading
        )
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.84)) {
                isVisible = true
            }
        }
    }
}

private struct HeroSummaryRevealModifier: ViewModifier {
    let isVisible: Bool
    let delay: Double

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 10)
            .animation(.spring(response: 0.5, dampingFraction: 0.84).delay(delay), value: isVisible)
    }
}

private extension View {
    func heroSummaryReveal(isVisible: Bool, delay: Double) -> some View {
        modifier(HeroSummaryRevealModifier(isVisible: isVisible, delay: delay))
    }
}
