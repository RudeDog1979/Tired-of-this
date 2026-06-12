//
//  BarterInsightsEngine.swift
//  BuxMuse
//
//  Local barter / trade activity summaries for Insights.
//

import Foundation

enum BarterInsightsEngine {
    static func generateInsights(transactions: [Transaction], locale: Locale) -> [FinancialInsight] {
        guard SettingsStore.shared.barterLoggerEnabled else { return [] }

        let barterTxs = transactions.filter { $0.isBarterExchange }
        guard !barterTxs.isEmpty else { return [] }

        let count = barterTxs.count
        let totalValue = barterTxs.compactMap { $0.barterEstimatedValue }.reduce(Decimal(0), +)
        let valueLabel = totalValue > 0
            ? InsightMoneyFormat.format(totalValue)
            : BuxLocalizedString.string(
                "Add estimated values when logging trades",
                locale: locale
            )

        return [
            FinancialInsight(
                title: BuxLocalizedString.string("Barter & Trade Activity", locale: locale),
                value: count == 1
                    ? BuxLocalizedString.format("%lld trade", locale: locale, count)
                    : BuxLocalizedString.format("%lld trades", locale: locale, count),
                description: BuxLocalizedString.string(
                    "Non-cash exchanges logged in BuxMuse.",
                    locale: locale
                ),
                fullExplanation: BuxLocalizedString.format(
                    "You have logged %lld barter or trade exchanges with an estimated combined value of %@. These are tracked separately from cash expenses for your records.",
                    locale: locale,
                    count,
                    valueLabel
                ),
                severity: .low,
                category: .pattern,
                systemIcon: "arrow.left.arrow.right.circle.fill",
                accentColorName: "orange",
                suggestedActions: [
                    BuxLocalizedString.string("Review barter entries in Expenses", locale: locale),
                    BuxLocalizedString.string("Add estimated values for tax records", locale: locale),
                ],
                impactMonthly: totalValue,
                impactYearly: totalValue * 12,
                dataBehind: BuxLocalizedString.string(
                    "Barter transactions where isBarterExchange is true.",
                    locale: locale
                )
            )
        ]
    }
}
