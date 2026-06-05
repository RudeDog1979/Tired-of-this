//
//  ExpensesSummaryCard.swift
//  BuxMuse
//

import SwiftUI

struct ExpensesSummaryCard: View {
    let display: ExpensesSummaryDisplay
    var customCategories: [ExpenseCategoryRecord] = []
    var chartProgress: Double = 1
    var chromeTier: BuxCardChromeTier = .hero
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var appSettingsManager: AppSettingsManager

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            BuxCatalogText.text("Monthly Summary")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(themeManager.labelPrimary(for: colorScheme))

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    BuxCatalogText.text("Top Categories")
                        .font(.caption.bold())
                        .foregroundColor(.gray)
                    CategoryBreakdownChart(
                        breakdown: display.categoryBreakdown,
                        customCategories: customCategories,
                        progress: chartProgress
                    )
                        .frame(height: 72)
                }

                VStack(alignment: .leading, spacing: 6) {
                    BuxCatalogText.text("Top Merchants")
                        .font(.caption.bold())
                        .foregroundColor(.gray)
                    MerchantBreakdownChart(
                        breakdown: display.merchantBreakdown,
                        maxItems: 3,
                        progress: chartProgress
                    )
                    .frame(height: MerchantBreakdownChart.compactHeight(itemCount: min(3, display.merchantBreakdown.count)))
                    if display.merchantBreakdown.count > 3 {
                        Text(
                            BuxLocalizedString.format(
                                "+%lld more",
                                locale: appSettingsManager.interfaceLocale,
                                Int64(display.merchantBreakdown.count - 3)
                            )
                        )
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.gray.opacity(0.9))
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                BuxCatalogText.text("Trend")
                    .font(.caption.bold())
                    .foregroundColor(.gray)
                MonthlyTrendChart(
                    points: display.trendPoints,
                    prediction: display.prediction,
                    progress: chartProgress
                )
                .padding(.vertical, 2)
                .background {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    BuxChartColors.spendTrendGlow(for: colorScheme),
                                    BuxChartColors.spendTrend(for: colorScheme).opacity(0.02)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .allowsHitTesting(false)
                }
            }
        }
        .expenseCardChrome(tier: chromeTier)
        .frame(
            maxWidth: .infinity,
            minHeight: BuxLayout.expenseHeroSummaryHeight,
            alignment: .topLeading
        )
    }
}
