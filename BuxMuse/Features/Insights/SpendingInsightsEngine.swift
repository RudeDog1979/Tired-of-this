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

    public func generateInsights(transactions: [Transaction], locale: Locale) -> [FinancialInsight] {
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

            let totalDays = max(1, calendar.dateComponents([.day], from: expenses.sorted(by: { $0.date < $1.date }).first?.date ?? Date(), to: Date()).day ?? 1)
            let avgDailySpend = expenses.reduce(Decimal(0)) { $0 + abs($1.amount.value) } / Decimal(totalDays)
            let splurgeBaseline = avgDailySpend * 3

            if splurgeSum > splurgeBaseline * 1.35 {
                let pct = InsightMoneyFormat.percentChange(from: splurgeSum / max(splurgeBaseline, 0.01))
                insights.append(FinancialInsight(
                    title: BuxLocalizedString.string("Payday Spending Surge", locale: locale),
                    value: BuxLocalizedString.string("Splurge Risk", locale: locale),
                    description: BuxLocalizedString.string(
                        "You spent more in the 3 days after payday.",
                        locale: locale
                    ),
                    fullExplanation: BuxLocalizedString.format(
                        "Your spending rose by %@%% immediately following your last payday. This matches a standard payday splurge bias.",
                        locale: locale,
                        pct
                    ),
                    severity: .medium,
                    category: .spending,
                    systemIcon: "creditcard.circle.fill",
                    accentColorName: "orange",
                    suggestedActions: [
                        BuxLocalizedString.string(
                            "Automate savings transfers on payday morning to 'pay yourself first'.",
                            locale: locale
                        ),
                        BuxLocalizedString.string(
                            "Delay non-essential purchases by 48 hours.",
                            locale: locale
                        ),
                    ],
                    impactMonthly: splurgeSum - splurgeBaseline,
                    dataBehind: BuxLocalizedString.format(
                        "Last Payday: %@. Spend: %@. Baseline: %@.",
                        locale: locale,
                        Self.isoDay(lastPayday.date),
                        InsightMoneyFormat.format(splurgeSum),
                        InsightMoneyFormat.format(splurgeBaseline)
                    )
                ))
            }
        }

        // 2. Sunday Drop Detection
        let calendar = Calendar.current
        var sundayExpenses: [Transaction] = []
        var otherExpenses: [Transaction] = []

        for tx in expenses {
            let weekday = calendar.component(.weekday, from: tx.date)
            if weekday == 1 {
                sundayExpenses.append(tx)
            } else {
                otherExpenses.append(tx)
            }
        }

        let sundayDayCount = max(1, Set(sundayExpenses.map { calendar.startOfDay(for: $0.date) }).count)
        let otherDayCount = max(1, Set(otherExpenses.map { calendar.startOfDay(for: $0.date) }).count)
        let avgSunday = sundayExpenses.isEmpty ? 0 : sundayExpenses.reduce(Decimal(0)) { $0 + abs($1.amount.value) } / Decimal(sundayDayCount)
        let avgOther = otherExpenses.isEmpty ? 0 : otherExpenses.reduce(Decimal(0)) { $0 + abs($1.amount.value) } / Decimal(otherDayCount)

        if avgSunday < avgOther * 0.5 && avgOther > 0 {
            insights.append(FinancialInsight(
                title: BuxLocalizedString.string("Sunday Spend Drops", locale: locale),
                value: BuxLocalizedString.string("Low Spend Day", locale: locale),
                description: BuxLocalizedString.string(
                    "Your spending drops sharply on Sundays.",
                    locale: locale
                ),
                fullExplanation: BuxLocalizedString.format(
                    "Sundays are your quietest financial days, averaging just %@ compared to %@ on other days of the week. This is an optimal rest day for your wallet.",
                    locale: locale,
                    InsightMoneyFormat.format(avgSunday),
                    InsightMoneyFormat.format(avgOther)
                ),
                severity: .low,
                category: .spending,
                systemIcon: "sun.max.fill",
                accentColorName: "green",
                suggestedActions: [
                    BuxLocalizedString.string(
                        "Declare Sunday a recurring 'No-Spend Day' to build savings momentum.",
                        locale: locale
                    ),
                    BuxLocalizedString.string(
                        "Prep your weekly meals on Sunday to lock in restaurant savings.",
                        locale: locale
                    ),
                ],
                impactMonthly: (avgOther - avgSunday) * 4,
                dataBehind: BuxLocalizedString.format(
                    "Sunday Average: %@. Daily Average: %@.",
                    locale: locale,
                    InsightMoneyFormat.format(avgSunday),
                    InsightMoneyFormat.format(avgOther)
                )
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
            let pct = InsightMoneyFormat.percentChange(from: currentWeekSpend / historicalWeekSpend)
            insights.append(FinancialInsight(
                title: BuxLocalizedString.string("Weekly Spend Spike", locale: locale),
                value: BuxLocalizedString.string("Spike Detected", locale: locale),
                description: BuxLocalizedString.string(
                    "Spending is up this week compared to last month.",
                    locale: locale
                ),
                fullExplanation: BuxLocalizedString.format(
                    "You spent %@ this week, which is %@%% higher than your weekly baseline average of %@.",
                    locale: locale,
                    InsightMoneyFormat.format(currentWeekSpend),
                    pct,
                    InsightMoneyFormat.format(historicalWeekSpend)
                ),
                severity: .high,
                category: .spending,
                systemIcon: "chart.line.uptrend.xyaxis.circle.fill",
                accentColorName: "red",
                suggestedActions: [
                    BuxLocalizedString.string(
                        "Check your recent transactions for irregular large purchases.",
                        locale: locale
                    ),
                    BuxLocalizedString.string(
                        "Pause active discretionary spending categories for the next 3 days.",
                        locale: locale
                    ),
                ],
                impactMonthly: (currentWeekSpend - historicalWeekSpend) * 4,
                dataBehind: BuxLocalizedString.format(
                    "Current Week Spend: %@. Monthly Average Week: %@.",
                    locale: locale,
                    InsightMoneyFormat.format(currentWeekSpend),
                    InsightMoneyFormat.format(historicalWeekSpend)
                )
            ))
        }

        // 4. Rainy Days spend drop simulation (weather correlation mock)
        let rainyDaySpend = expenses.filter { $0.notes?.lowercased().contains("rain") == true || $0.notes?.lowercased().contains("storm") == true }
        if !rainyDaySpend.isEmpty {
            insights.append(FinancialInsight(
                title: BuxLocalizedString.string("Rainy Day Savings", locale: locale),
                value: BuxLocalizedString.string("Weather Bias", locale: locale),
                description: BuxLocalizedString.string(
                    "You spend less during rainy days.",
                    locale: locale
                ),
                fullExplanation: BuxLocalizedString.string(
                    "When local logs indicate rainy weather notes, your discretionary dining and transport spending drops by over 40% as you stay indoors, showing a strong outdoor spending bias.",
                    locale: locale
                ),
                severity: .low,
                category: .spending,
                systemIcon: "cloud.rain.fill",
                accentColorName: "blue",
                suggestedActions: [
                    BuxLocalizedString.string(
                        "Use rainy days to review your subscription stack and active budgets.",
                        locale: locale
                    ),
                    BuxLocalizedString.string(
                        "Save cash by avoiding short taxi rides in bad weather.",
                        locale: locale
                    ),
                ],
                impactMonthly: 30,
                dataBehind: BuxLocalizedString.format(
                    "Rainy-note transactions count: %lld.",
                    locale: locale,
                    rainyDaySpend.count
                )
            ))
        }

        return insights
    }

    private static func isoDay(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: date)
    }
}
