//
//  PatternInsightsEngine.swift
//  BuxMuse
//  Features/Insights/
//
//  Pattern Insights Engine mapping cadence anomalies and behavioral trends.
//

import Foundation

public final class PatternInsightsEngine {
    public init() {}

    public func generateInsights(transactions: [Transaction]) -> [FinancialInsight] {
        var insights: [FinancialInsight] = []
        guard !transactions.isEmpty else { return [] }

        let expenses = transactions.filter { $0.category != .income }
        let calendar = Calendar.current

        var weekendSpend: Decimal = 0
        var weekdaySpend: Decimal = 0
        var weekendDays = 0
        var weekdayDays = 0

        let dateGroups = Dictionary(grouping: expenses) { calendar.startOfDay(for: $0.date) }
        for (date, txs) in dateGroups {
            let weekday = calendar.component(.weekday, from: date)
            let dailyTotal = txs.reduce(Decimal(0)) { $0 + abs($1.amount.value) }
            if weekday == 7 || weekday == 1 {
                weekendSpend += dailyTotal
                weekendDays += 1
            } else {
                weekdaySpend += dailyTotal
                weekdayDays += 1
            }
        }

        let avgWeekend = weekendDays > 0 ? (weekendSpend / Decimal(weekendDays)) : 0
        let avgWeekday = weekdayDays > 0 ? (weekdaySpend / Decimal(weekdayDays)) : 0

        if avgWeekend > avgWeekday * 1.50 && avgWeekday > 0 {
            let pct = InsightMoneyFormat.percentChange(from: avgWeekend / avgWeekday)
            let weekendCap = avgWeekday * 1.2
            insights.append(FinancialInsight(
                title: "Weekend Spending Surge",
                value: "Weekend Bias",
                description: "You spend more on weekends.",
                fullExplanation: "Your weekend spending averages \(InsightMoneyFormat.format(avgWeekend)) per day, which is \(pct)% higher than your weekday average of \(InsightMoneyFormat.format(avgWeekday)).",
                severity: .medium,
                category: .pattern,
                systemIcon: "calendar.badge.exclamationmark",
                accentColorName: "orange",
                suggestedActions: [
                    "Establish a concrete 'Weekend Budget cap' of \(InsightMoneyFormat.format(weekendCap)).",
                    "Plan free or low-cost activities for Saturday afternoons."
                ],
                impactMonthly: (avgWeekend - avgWeekday) * 8,
                dataBehind: "Weekend Average: \(InsightMoneyFormat.format(avgWeekend)). Weekday Average: \(InsightMoneyFormat.format(avgWeekday))."
            ))
        }

        var nighttimeTransportTxs: [Transaction] = []
        for tx in expenses {
            if tx.category == .transport {
                let hour = calendar.component(.hour, from: tx.date)
                if hour >= 20 || hour < 5 {
                    nighttimeTransportTxs.append(tx)
                }
            }
        }

        if nighttimeTransportTxs.count >= 2 {
            let nighttimeSum = nighttimeTransportTxs.reduce(Decimal(0)) { $0 + abs($1.amount.value) }
            insights.append(FinancialInsight(
                title: "Late Night Transport Surge",
                value: "Nighttime Bias",
                description: "Your transport spending spikes after 8pm.",
                fullExplanation: "You spent \(InsightMoneyFormat.format(nighttimeSum)) across \(nighttimeTransportTxs.count) late-night rides this month. Fare spikes and premium options contribute to this nocturnal splurge.",
                severity: .low,
                category: .pattern,
                systemIcon: "moon.stars.fill",
                accentColorName: "blue",
                suggestedActions: [
                    "Check alternative public transit or shared ride routes if safe.",
                    "Review rideshare history for peak surge pricing anomalies."
                ],
                impactMonthly: nighttimeSum * 0.3,
                dataBehind: "Nighttime Transport Spend: \(InsightMoneyFormat.format(nighttimeSum)). Count: \(nighttimeTransportTxs.count)."
            ))
        }

        return insights
    }
}
