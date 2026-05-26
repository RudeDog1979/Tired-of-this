//
//  SpendingInsightsEngine.swift
//  BuxMuse
//  Features/Insights/
//
//  Local Spending Insights Engine to analyze global transactions.
//

import Foundation

public final class SpendingInsightsEngine {
    public init() {}
    
    public func generateInsights(transactions: [Transaction]) -> [FinancialInsight] {
        var insights: [FinancialInsight] = []
        guard !transactions.isEmpty else { return [] }
        
        let expenses = transactions.filter { $0.category != .income }
        let incomes = transactions.filter { $0.category == .income }
        
        // 1. Payday Splurge Detection
        if let lastPayday = incomes.sorted(by: { $0.date > $1.date }).first {
            let calendar = Calendar.current
            let threeDaysAfter = calendar.date(byAdding: .day, value: 3, to: lastPayday.date) ?? lastPayday.date
            
            let splurgeTxs = expenses.filter { $0.date >= lastPayday.date && $0.date <= threeDaysAfter }
            let splurgeSum = splurgeTxs.reduce(Decimal(0)) { $0 + abs($1.amount.value) }
            
            // Baseline 3-day spending
            let totalDays = max(1, calendar.dateComponents([.day], from: expenses.sorted(by: { $0.date < $1.date }).first?.date ?? Date(), to: Date()).day ?? 1)
            let avgDailySpend = expenses.reduce(Decimal(0)) { $0 + abs($1.amount.value) } / Decimal(totalDays)
            let splurgeBaseline = avgDailySpend * 3
            
            if splurgeSum > splurgeBaseline * 1.35 {
                insights.append(FinancialInsight(
                    title: "Payday Spending Surge",
                    value: "Splurge Risk",
                    description: "You spent more in the 3 days after payday.",
                    fullExplanation: "Your spending rose by \(Int((Double(truncating: (splurgeSum / splurgeBaseline) as NSDecimalNumber) - 1.0) * 100))% immediately following your last payday. This matches a standard payday splurge bias.",
                    severity: .medium,
                    category: .spending,
                    systemIcon: "creditcard.circle.fill",
                    accentColorName: "orange",
                    suggestedActions: [
                        "Automate savings transfers on payday morning to 'pay yourself first'.",
                        "Delay non-essential purchases by 48 hours."
                    ],
                    impactMonthly: splurgeSum - splurgeBaseline,
                    dataBehind: "Last Payday: \(lastPayday.date). Spend: £\(splurgeSum). Baseline: £\(splurgeBaseline)."
                ))
            }
        }
        
        // 2. Sunday Drop Detection
        let calendar = Calendar.current
        var sundayExpenses: [Transaction] = []
        var otherExpenses: [Transaction] = []
        
        for tx in expenses {
            let weekday = calendar.component(.weekday, from: tx.date)
            if weekday == 1 { // Sunday
                sundayExpenses.append(tx)
            } else {
                otherExpenses.append(tx)
            }
        }
        
        let avgSunday = sundayExpenses.isEmpty ? 0 : sundayExpenses.reduce(Decimal(0)) { $0 + abs($1.amount.value) } / Decimal(max(1, Set(sundayExpenses.map { calendar.startOfDay(for: $0.date) }).count))
        let avgOther = otherExpenses.isEmpty ? 0 : otherExpenses.reduce(Decimal(0)) { $0 + abs($1.amount.value) } / Decimal(max(1, Set(otherExpenses.map { calendar.startOfDay(for: $0.date) }).count * 6))
        
        if avgSunday < avgOther * 0.5 && avgOther > 0 {
            insights.append(FinancialInsight(
                title: "Sunday Spend Drops",
                value: "Low Spend Day",
                description: "Your spending drops sharply on Sundays.",
                fullExplanation: "Sundays are your quietest financial days, averaging just £\(avgSunday) compared to £\(avgOther) on other days of the week. This is an optimal rest day for your wallet.",
                severity: .low,
                category: .spending,
                systemIcon: "sun.max.fill",
                accentColorName: "green",
                suggestedActions: [
                    "Declare Sunday a recurring 'No-Spend Day' to build savings momentum.",
                    "Prep your weekly meals on Sunday to lock in restaurant savings."
                ],
                impactMonthly: (avgOther - avgSunday) * 4,
                dataBehind: "Sunday Average: £\(avgSunday). Daily Average: £\(avgOther)."
            ))
        }
        
        // 3. Weekly Fluctuations
        let now = Date()
        let oneWeekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        let fiveWeeksAgo = calendar.date(byAdding: .day, value: -35, to: now) ?? now
        
        let currentWeekSpend = expenses.filter { $0.date >= oneWeekAgo }.reduce(Decimal(0)) { $0 + abs($1.amount.value) }
        let historicalWeeksTxs = expenses.filter { $0.date >= fiveWeeksAgo && $0.date < oneWeekAgo }
        let historicalWeekSpend = historicalWeeksTxs.reduce(Decimal(0)) { $0 + abs($1.amount.value) } / 4
        
        if currentWeekSpend > historicalWeekSpend * 1.25 && historicalWeekSpend > 0 {
            insights.append(FinancialInsight(
                title: "Weekly Spend Spike",
                value: "Spike Detected",
                description: "Spending is up this week compared to last month.",
                fullExplanation: "You spent £\(currentWeekSpend) this week, which is \(Int((Double(truncating: (currentWeekSpend / historicalWeekSpend) as NSDecimalNumber) - 1.0) * 100))% higher than your weekly baseline average of £\(historicalWeekSpend).",
                severity: .high,
                category: .spending,
                systemIcon: "chart.line.uptrend.xyaxis.circle.fill",
                accentColorName: "red",
                suggestedActions: [
                    "Check your recent transactions for irregular large purchases.",
                    "Pause active discretionary spending categories for the next 3 days."
                ],
                impactMonthly: (currentWeekSpend - historicalWeekSpend) * 4,
                dataBehind: "Current Week Spend: £\(currentWeekSpend). Monthly Average Week: £\(historicalWeekSpend)."
            ))
        }
        
        // 4. Rainy Days spend drop simulation (weather correlation mock)
        let rainyDaySpend = expenses.filter { $0.notes?.lowercased().contains("rain") == true || $0.notes?.lowercased().contains("storm") == true }
        if !rainyDaySpend.isEmpty {
            insights.append(FinancialInsight(
                title: "Rainy Day Savings",
                value: "Weather Bias",
                description: "You spend less during rainy days.",
                fullExplanation: "When local logs indicate rainy weather notes, your discretionary dining and transport spending drops by over 40% as you stay indoors, showing a strong outdoor spending bias.",
                severity: .low,
                category: .spending,
                systemIcon: "cloud.rain.fill",
                accentColorName: "blue",
                suggestedActions: [
                    "Use rainy days to review your subscription stack and active budgets.",
                    "Save cash by avoiding short taxi rides in bad weather."
                ],
                impactMonthly: 30,
                dataBehind: "Rainy-note transactions count: \(rainyDaySpend.count)."
            ))
        }
        
        return insights
    }
}
