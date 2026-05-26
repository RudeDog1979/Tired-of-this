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
    
    public func generateInsights(transactions: [Transaction]) -> [FinancialInsight] {
        var insights: [FinancialInsight] = []
        guard !transactions.isEmpty else { return [] }
        
        let expenses = transactions.filter { $0.category != .income }
        let categories = Set(expenses.map { $0.category })
        
        let calendar = Calendar.current
        let now = Date()
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: now) ?? now
        let ninetyDaysAgo = calendar.date(byAdding: .day, value: -90, to: now) ?? now
        
        for cat in categories {
            let recentTxs = expenses.filter { $0.category == cat && $0.date >= thirtyDaysAgo }
            let historicalTxs = expenses.filter { $0.category == cat && $0.date >= ninetyDaysAgo && $0.date < thirtyDaysAgo }
            
            let recentTotal = recentTxs.reduce(Decimal(0)) { $0 + abs($1.amount.value) }
            let historicalMonths = max(1.0, 2.0)
            let avgHistoricalTotal = historicalTxs.reduce(Decimal(0)) { $0 + abs($1.amount.value) } / Decimal(historicalMonths)
            
            // 1. Category Overspend Alert
            if recentTotal > avgHistoricalTotal * 1.35 && avgHistoricalTotal > 0 {
                insights.append(FinancialInsight(
                    title: "\(cat.displayName) Overspend",
                    value: "Overspend Spike",
                    description: "You spent more on \(cat.displayName) this month.",
                    fullExplanation: "Your \(cat.displayName) spending reached £\(recentTotal) this month, which is \(Int((Double(truncating: (recentTotal / avgHistoricalTotal) as NSDecimalNumber) - 1.0) * 100))% higher than your baseline average of £\(avgHistoricalTotal).",
                    severity: .high,
                    category: .category,
                    systemIcon: "exclamationmark.square.fill",
                    accentColorName: "red",
                    suggestedActions: [
                        "Review recent transaction line items inside \(cat.displayName).",
                        "Set up a warning alert baseline budget limit for this category."
                    ],
                    impactMonthly: recentTotal - avgHistoricalTotal,
                    dataBehind: "Category: \(cat.displayName). Current: £\(recentTotal). Baseline: £\(avgHistoricalTotal)."
                ))
            }
            
            // 2. Category Underspend / Savings Opportunity
            if recentTotal < avgHistoricalTotal * 0.65 && avgHistoricalTotal > 50 {
                insights.append(FinancialInsight(
                    title: "\(cat.displayName) Optimization",
                    value: "Savings Gained",
                    description: "Excellent job limiting your \(cat.displayName) budget.",
                    fullExplanation: "Your \(cat.displayName) spending fell to £\(recentTotal) this month compared to £\(avgHistoricalTotal) historically, leaving you with an extra surplus of £\(avgHistoricalTotal - recentTotal).",
                    severity: .low,
                    category: .category,
                    systemIcon: "sparkles",
                    accentColorName: "green",
                    suggestedActions: [
                        "Redirect this surplus of £\(avgHistoricalTotal - recentTotal) immediately into savings goals.",
                        "Lock in this lower baseline budget target for next month."
                    ],
                    impactMonthly: avgHistoricalTotal - recentTotal,
                    dataBehind: "Category: \(cat.displayName). Saved: £\(avgHistoricalTotal - recentTotal)."
                ))
            }
        }
        
        return insights
    }
}
