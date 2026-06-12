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
    var rasterizesCharts: Bool = true
    var isVisible: Bool = true
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var appSettingsManager: AppSettingsManager

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                BuxCatalogText.text("Monthly summary")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(themeManager.labelPrimary(for: colorScheme))

                BuxCatalogText.text("This month")
                    .font(.caption.bold())
                    .foregroundColor(.gray)

                Text(
                    AppSettingsManager.format(
                        amount: Decimal(display.totalSpent),
                        currency: appSettingsManager.selectedCurrency
                    )
                )
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                    .transaction { $0.animation = nil }
            }
            .heroCardReveal(isVisible: isVisible, delay: 0)

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    BuxCatalogText.text("Top categories")
                        .font(.caption.bold())
                        .foregroundColor(.gray)
                    CategoryBreakdownChart(
                        breakdown: display.categoryBreakdown,
                        customCategories: customCategories,
                        progress: chartProgress,
                        rasterizesChart: rasterizesCharts
                    )
                        .frame(height: 72)
                }

                VStack(alignment: .leading, spacing: 6) {
                    BuxCatalogText.text("Top merchants")
                        .font(.caption.bold())
                        .foregroundColor(.gray)
                    MerchantBreakdownChart(
                        breakdown: display.merchantBreakdown,
                        maxItems: 3,
                        progress: chartProgress,
                        rasterizesChart: rasterizesCharts
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
            .heroCardReveal(isVisible: isVisible, delay: 0.06)

            VStack(alignment: .leading, spacing: 6) {
                BuxCatalogText.text("Trend")
                    .font(.caption.bold())
                    .foregroundColor(.gray)
                MonthlyTrendChart(
                    points: display.trendPoints,
                    prediction: display.prediction,
                    progress: chartProgress,
                    rasterizesChart: rasterizesCharts
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
            .heroCardReveal(isVisible: isVisible, delay: 0.14)
        }
        .expenseCardChrome(tier: chromeTier)
        .frame(
            maxWidth: .infinity,
            minHeight: BuxLayout.expenseHeroSummaryHeight,
            alignment: .topLeading
        )
    }
}
