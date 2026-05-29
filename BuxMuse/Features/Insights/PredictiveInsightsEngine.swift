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

    public func generateInsights(transactions: [Transaction]) -> [FinancialInsight] {
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
                title: "Predicted Budget Overspend",
                value: "Overspend Forecast",
                description: "You're trending higher than your monthly average.",
                fullExplanation: "Based on your current daily run-rate of \(InsightMoneyFormat.format(dailyRunRate)), BuxMuse predicts you will spend \(InsightMoneyFormat.format(projectedMonthSpend)) this month. This is \(pct)% higher than your standard average (\(InsightMoneyFormat.format(historicalMonthlyAvg))), threatening a potential \(InsightMoneyFormat.format(difference)) overspend.",
                severity: .high,
                category: .predictive,
                systemIcon: "chart.line.uptrend.xyaxis.circle.fill",
                accentColorName: "red",
                suggestedActions: [
                    "Lock in strict budget limits for transport and dining categories immediately.",
                    "Review active subscriptions and opt out of zombie services."
                ],
                impactMonthly: difference,
                dataBehind: "Run-rate: \(InsightMoneyFormat.format(dailyRunRate))/day. Predicted: \(InsightMoneyFormat.format(projectedMonthSpend)). Historical: \(InsightMoneyFormat.format(historicalMonthlyAvg))."
            ))
        } else if historicalMonthlyAvg > 0 {
            insights.append(FinancialInsight(
                title: "Stable Spending Forecast",
                value: "Stable Budget",
                description: "You are within your safe historical limits.",
                fullExplanation: "BuxMuse predicts a stable close to the month, with forecasted spending at \(InsightMoneyFormat.format(projectedMonthSpend)), well within your safe historical boundaries of \(InsightMoneyFormat.format(historicalMonthlyAvg)).",
                severity: .low,
                category: .predictive,
                systemIcon: "checkmark.shield.fill",
                accentColorName: "green",
                suggestedActions: [
                    "Transfer 10% of your remaining free budget to savings goals early.",
                    "Enjoy peace of mind, your baseline budgets are secure."
                ],
                impactMonthly: 0,
                dataBehind: "Predicted: \(InsightMoneyFormat.format(projectedMonthSpend)). Historical Avg: \(InsightMoneyFormat.format(historicalMonthlyAvg))."
            ))
        }

        return insights
    }
}
