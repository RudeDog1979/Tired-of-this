//
//  PredictiveInsightsEngine.swift
//  BuxMuse
//  Features/Insights/
//
//  Predictive Insights Engine extrapolating budgets and upcoming risk triggers.
//

import Foundation

public final class PredictiveInsightsEngine {
    public init() {}

    public func generateInsights(transactions: [Transaction], locale: Locale) -> [FinancialInsight] {
        var insights: [FinancialInsight] = []
        guard !transactions.isEmpty else { return [] }
        let expenses = transactions.filter { $0.category != .income }
        let calendar = Calendar.current
        let now = Date()

        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        let daysPassed = max(1, calendar.dateComponents([.day], from: startOfMonth, to: now).day ?? 1)
        let totalDaysInMonth = calendar.range(of: .day, in: .month, for: now)?.count ?? 30

        let monthToDateSpend = expenses.filter { $0.date >= startOfMonth }.reduce(Decimal(0)) { $0 + abs($1.amount.value) }
        let dailyRunRate = monthToDateSpend / Decimal(daysPassed)
        let projectedMonthSpend = dailyRunRate * Decimal(totalDaysInMonth)

        let threeMonthsAgo = calendar.date(byAdding: .month, value: -3, to: startOfMonth) ?? startOfMonth
        let historicalExpenses = expenses.filter { $0.date >= threeMonthsAgo && $0.date < startOfMonth }
        let historicalMonthlyAvg = historicalExpenses.reduce(Decimal(0)) { $0 + abs($1.amount.value) } / 3

        if projectedMonthSpend > historicalMonthlyAvg * 1.15 && historicalMonthlyAvg > 0 {
            let difference = projectedMonthSpend - historicalMonthlyAvg
            let pct = InsightMoneyFormat.percentChange(from: projectedMonthSpend / historicalMonthlyAvg)
            insights.append(FinancialInsight(
                title: BuxLocalizedString.string("Predicted Budget Overspend", locale: locale),
                value: BuxLocalizedString.string("Overspend Forecast", locale: locale),
                description: BuxLocalizedString.string(
                    "You're trending higher than your monthly average.",
                    locale: locale
                ),
                fullExplanation: BuxLocalizedString.format(
                    "Based on your current daily run-rate of %@, BuxMuse predicts you will spend %@ this month. This is %@%% higher than your standard average (%@), threatening a potential %@ overspend.",
                    locale: locale,
                    InsightMoneyFormat.format(dailyRunRate),
                    InsightMoneyFormat.format(projectedMonthSpend),
                    pct,
                    InsightMoneyFormat.format(historicalMonthlyAvg),
                    InsightMoneyFormat.format(difference)
                ),
                severity: .high,
                category: .predictive,
                systemIcon: "chart.line.uptrend.xyaxis.circle.fill",
                accentColorName: "red",
                suggestedActions: [
                    BuxLocalizedString.string(
                        "Lock in strict budget limits for transport and dining categories immediately.",
                        locale: locale
                    ),
                    BuxLocalizedString.string(
                        "Review active subscriptions and opt out of zombie services.",
                        locale: locale
                    ),
                ],
                impactMonthly: difference,
                dataBehind: BuxLocalizedString.format(
                    "Run-rate: %@/day. Predicted: %@. Historical: %@.",
                    locale: locale,
                    InsightMoneyFormat.format(dailyRunRate),
                    InsightMoneyFormat.format(projectedMonthSpend),
                    InsightMoneyFormat.format(historicalMonthlyAvg)
                )
            ))
        } else if historicalMonthlyAvg > 0 {
            insights.append(FinancialInsight(
                title: BuxLocalizedString.string("Stable Spending Forecast", locale: locale),
                value: BuxLocalizedString.string("Stable Budget", locale: locale),
                description: BuxLocalizedString.string(
                    "You are within your safe historical limits.",
                    locale: locale
                ),
                fullExplanation: BuxLocalizedString.format(
                    "BuxMuse predicts a stable close to the month, with forecasted spending at %@, well within your safe historical boundaries of %@.",
                    locale: locale,
                    InsightMoneyFormat.format(projectedMonthSpend),
                    InsightMoneyFormat.format(historicalMonthlyAvg)
                ),
                severity: .low,
                category: .predictive,
                systemIcon: "checkmark.shield.fill",
                accentColorName: "green",
                suggestedActions: [
                    BuxLocalizedString.string(
                        "Transfer 10% of your remaining free budget to savings goals early.",
                        locale: locale
                    ),
                    BuxLocalizedString.string(
                        "Enjoy peace of mind, your baseline budgets are secure.",
                        locale: locale
                    ),
                ],
                impactMonthly: 0,
                dataBehind: BuxLocalizedString.format(
                    "Predicted: %@. Historical Avg: %@.",
                    locale: locale,
                    InsightMoneyFormat.format(projectedMonthSpend),
                    InsightMoneyFormat.format(historicalMonthlyAvg)
                )
            ))
        }

        return insights
    }
}
