//
//  CategoryInsightsEngine.swift
//  BuxMuse
//  Features/Insights/
//
//  Category Insights Engine analyzing category budgets, volatility, and overspends.
//

import Foundation

public final class CategoryInsightsEngine {
    public init() {}

    public func generateInsights(transactions: [Transaction], locale: Locale) -> [FinancialInsight] {
        var insights: [FinancialInsight] = []
        guard !transactions.isEmpty else { return [] }

        let expenses = transactions.filter { $0.category != .income }
        let categories = Set(expenses.map { $0.category })

        let calendar = Calendar.current
        let now = Date()
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: now) ?? now
        let ninetyDaysAgo = calendar.date(byAdding: .day, value: -90, to: now) ?? now

        for cat in categories {
            let catName = cat.localizedDisplayName(locale: locale)
            let recentTxs = expenses.filter { $0.category == cat && $0.date >= thirtyDaysAgo }
            let historicalTxs = expenses.filter { $0.category == cat && $0.date >= ninetyDaysAgo && $0.date < thirtyDaysAgo }

            let recentTotal = recentTxs.reduce(Decimal(0)) { $0 + abs($1.amount.value) }
            let historicalMonths = max(1.0, 2.0)
            let avgHistoricalTotal = historicalTxs.reduce(Decimal(0)) { $0 + abs($1.amount.value) } / Decimal(historicalMonths)

            if recentTotal > avgHistoricalTotal * 1.35 && avgHistoricalTotal > 0 {
                let pct = InsightMoneyFormat.percentChange(from: recentTotal / avgHistoricalTotal)
                insights.append(FinancialInsight(
                    title: "\(cat.displayName) Overspend",
                    value: "Overspend Spike",
                    description: BuxLocalizedString.format(
                        "You spent more on %@ this month.",
                        locale: locale,
                        catName
                    ),
                    fullExplanation: BuxLocalizedString.format(
                        "Your %@ spending reached %@ this month, which is %@%% higher than your baseline average of %@.",
                        locale: locale,
                        catName,
                        InsightMoneyFormat.format(recentTotal),
                        pct,
                        InsightMoneyFormat.format(avgHistoricalTotal)
                    ),
                    severity: .high,
                    category: .category,
                    systemIcon: "exclamationmark.square.fill",
                    accentColorName: "red",
                    suggestedActions: [
                        BuxLocalizedString.format(
                            "Review recent transaction line items inside %@.",
                            locale: locale,
                            catName
                        ),
                        BuxLocalizedString.string(
                            "Set up a warning alert baseline budget limit for this category.",
                            locale: locale
                        ),
                    ],
                    impactMonthly: recentTotal - avgHistoricalTotal,
                    dataBehind: BuxLocalizedString.format(
                        "Category: %@. Current: %@. Baseline: %@.",
                        locale: locale,
                        catName,
                        InsightMoneyFormat.format(recentTotal),
                        InsightMoneyFormat.format(avgHistoricalTotal)
                    )
                ))
            }

            if recentTotal < avgHistoricalTotal * 0.65 && avgHistoricalTotal > 50 {
                let surplus = avgHistoricalTotal - recentTotal
                insights.append(FinancialInsight(
                    title: "\(cat.displayName) Optimization",
                    value: "Savings Gained",
                    description: BuxLocalizedString.format(
                        "Excellent job limiting your %@ budget.",
                        locale: locale,
                        catName
                    ),
                    fullExplanation: BuxLocalizedString.format(
                        "Your %@ spending fell to %@ this month compared to %@ historically, leaving you with an extra surplus of %@.",
                        locale: locale,
                        catName,
                        InsightMoneyFormat.format(recentTotal),
                        InsightMoneyFormat.format(avgHistoricalTotal),
                        InsightMoneyFormat.format(surplus)
                    ),
                    severity: .low,
                    category: .category,
                    systemIcon: "sparkles",
                    accentColorName: "green",
                    suggestedActions: [
                        BuxLocalizedString.format(
                            "Redirect this surplus of %@ immediately into savings goals.",
                            locale: locale,
                            InsightMoneyFormat.format(surplus)
                        ),
                        BuxLocalizedString.string(
                            "Lock in this lower baseline budget target for next month.",
                            locale: locale
                        ),
                    ],
                    impactMonthly: surplus,
                    dataBehind: BuxLocalizedString.format(
                        "Category: %@. Saved: %@.",
                        locale: locale,
                        catName,
                        InsightMoneyFormat.format(surplus)
                    )
                ))
            }
        }

        return insights
    }
}
