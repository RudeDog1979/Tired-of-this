//
//  BarterInsightsEngine.swift
//  BuxMuse
//
//  Local barter / trade activity summaries for Insights.
//

import Foundation

enum BarterInsightsEngine {
    static func generateInsights(transactions: [Transaction]) -> [FinancialInsight] {
        guard SettingsStore.shared.barterLoggerEnabled else { return [] }

        let barterTxs = transactions.filter { $0.isBarterExchange }
        guard !barterTxs.isEmpty else { return [] }

        let count = barterTxs.count
        let totalValue = barterTxs.compactMap { $0.barterEstimatedValue }.reduce(Decimal(0), +)
        let valueLabel = totalValue > 0
            ? InsightMoneyFormat.format(totalValue)
            : "Add estimated values when logging trades"

        return [
            FinancialInsight(
                title: "Barter & Trade Activity",
                value: "\(count) trade\(count == 1 ? "" : "s")",
                description: "Non-cash exchanges logged in BuxMuse.",
                fullExplanation: "You have logged \(count) barter or trade exchange\(count == 1 ? "" : "s") with an estimated combined value of \(valueLabel). These are tracked separately from cash expenses for your records.",
                severity: .low,
                category: .pattern,
                systemIcon: "arrow.left.arrow.right.circle.fill",
                accentColorName: "orange",
                suggestedActions: ["Review barter entries in Expenses", "Add estimated values for tax records"],
                impactMonthly: totalValue,
                impactYearly: totalValue * 12,
                dataBehind: "Barter transactions where isBarterExchange is true."
            )
        ]
    }
}
