//
//  GoalsRiskEngine.swift
//  BuxMuse
//  Features/Goals/
//
//  Analyzes spending volatility, subscription overheads, and contribution patterns to flag risks.
//

import Foundation

public final class GoalsRiskEngine {

    public init() {}

    /// Analyzes the goal against transactions and subscription data to generate risk items.
    public func analyzeRisks(
        goal: Goal,
        transactions: [Transaction],
        activeSubscriptions: [SubscriptionInfo],
        overspendAlerts: [OverspendAlert],
        locale: Locale = BuxInterfaceLocale.currentInterfaceLocale
    ) -> [GoalRisk] {
        var risks: [GoalRisk] = []
        let now = Date()

        if let deadline = goal.deadline {
            let projectionEngine = GoalsProjectionEngine()
            let projection = projectionEngine.project(
                goal: goal,
                transactions: transactions,
                activeSubscriptions: activeSubscriptions
            )

            if projection.expectedCompletionDate > deadline {
                let monthsOver = Calendar.current.dateComponents([.month], from: deadline, to: projection.expectedCompletionDate).month ?? 0
                let description: String
                if monthsOver > 0 {
                    description = BuxLocalizedString.format(
                        "Expected completion date is behind your set deadline by %lld month(s).",
                        locale: locale,
                        monthsOver
                    )
                } else {
                    description = BuxLocalizedString.string(
                        "Expected completion date is slightly behind your set deadline.",
                        locale: locale
                    )
                }
                risks.append(GoalRisk(
                    type: .fallingBehind,
                    description: description,
                    severity: "high",
                    suggestedFix: BuxLocalizedString.format(
                        "Increase monthly savings to %@ or extend the goal's deadline.",
                        locale: locale,
                        "\(projection.recommendedContribution)"
                    )
                ))
            }
        }

        if !goal.contributions.isEmpty {
            let sortedContributions = goal.contributions.sorted(by: { $0.date > $1.date })
            if let lastContribution = sortedContributions.first?.date {
                let daysSinceLast = now.timeIntervalSince(lastContribution) / 86400.0
                if daysSinceLast > 35 {
                    risks.append(GoalRisk(
                        type: .missedContribution,
                        description: BuxLocalizedString.format(
                            "It has been %lld days since your last goal contribution.",
                            locale: locale,
                            Int(daysSinceLast)
                        ),
                        severity: "medium",
                        suggestedFix: BuxLocalizedString.string(
                            "Set up an automatic recurring weekly or monthly transfer to stay on track.",
                            locale: locale
                        )
                    ))
                }
            }
        } else {
            let daysSinceCreated = now.timeIntervalSince(goal.createdAt) / 86400.0
            if daysSinceCreated > 14 && goal.currentAmount == 0 {
                risks.append(GoalRisk(
                    type: .missedContribution,
                    description: BuxLocalizedString.format(
                        "No contributions have been made to this goal since its creation %lld days ago.",
                        locale: locale,
                        Int(daysSinceCreated)
                    ),
                    severity: "high",
                    suggestedFix: BuxLocalizedString.string(
                        "Kickstart your goal by adding an initial contribution of any amount today.",
                        locale: locale
                    )
                ))
            }
        }

        if !overspendAlerts.isEmpty {
            let totalOverspendPercent = overspendAlerts.reduce(0.0) { $0 + $1.overspendPercentage }
            if totalOverspendPercent > 30.0 {
                let categoryName = overspendAlerts.first?.category.localizedDisplayName(locale: locale)
                    ?? TransactionCategory.other.localizedDisplayName(locale: locale)
                risks.append(GoalRisk(
                    type: .overspendThreat,
                    description: BuxLocalizedString.format(
                        "Heavy overspending in categories like %@ is draining cash reserves.",
                        locale: locale,
                        categoryName
                    ),
                    severity: "high",
                    suggestedFix: BuxLocalizedString.string(
                        "Pause non-essential shopping and implement category spending caps immediately.",
                        locale: locale
                    )
                ))
            }
        }

        let monthlySubscriptionCost = activeSubscriptions.reduce(Decimal(0)) { $0 + abs($1.cost.value) }
        if monthlySubscriptionCost > 150 {
            risks.append(GoalRisk(
                type: .subscriptionThreat,
                description: BuxLocalizedString.format(
                    "Monthly subscription burn rate is %@, reducing your available goal funding.",
                    locale: locale,
                    "\(monthlySubscriptionCost)"
                ),
                severity: "medium",
                suggestedFix: BuxLocalizedString.string(
                    "Review subscription hub and consider downgrading or pausing lesser-used services.",
                    locale: locale
                )
            ))
        }

        let recentOtherExpenses = transactions.filter {
            $0.date >= Calendar.current.date(byAdding: .day, value: -30, to: now) ?? now &&
            ($0.category == .other || $0.category == .transport) &&
            $0.amount.value < -200
        }
        if !recentOtherExpenses.isEmpty {
            risks.append(GoalRisk(
                type: .irregularExpenseThreat,
                description: BuxLocalizedString.string(
                    "Large, non-recurring expenses registered recently have temporarily impacted liquid savings.",
                    locale: locale
                ),
                severity: "medium",
                suggestedFix: BuxLocalizedString.string(
                    "Create a dedicated buffer fund for unexpected car, travel, or device repairs.",
                    locale: locale
                )
            ))
        }

        if let highSpike = overspendAlerts.first(where: { $0.overspendPercentage > 50.0 }) {
            let cat = highSpike.category.localizedDisplayName(locale: locale)
            risks.append(GoalRisk(
                type: .categorySpikeThreat,
                description: BuxLocalizedString.format(
                    "Spike detected: %@ spending is %lld%% above baseline.",
                    locale: locale,
                    cat,
                    Int(highSpike.overspendPercentage)
                ),
                severity: "high",
                suggestedFix: BuxLocalizedString.format(
                    "Trim %@ expenditures by deferring purchases to next month.",
                    locale: locale,
                    cat
                )
            ))
        }

        let calendar = Calendar.current
        let currentMonthTxs = transactions.filter {
            $0.date >= (calendar.date(byAdding: .day, value: -30, to: now) ?? now)
        }
        let prevMonthTxs = transactions.filter {
            $0.date >= (calendar.date(byAdding: .day, value: -60, to: now) ?? now) &&
            $0.date < (calendar.date(byAdding: .day, value: -30, to: now) ?? now)
        }

        let currentIncome = currentMonthTxs.filter { $0.category == .income }.reduce(Decimal(0)) { $0 + $1.amount.value }
        let prevIncome = prevMonthTxs.filter { $0.category == .income }.reduce(Decimal(0)) { $0 + $1.amount.value }

        if prevIncome > 0 && currentIncome < prevIncome * 0.8 {
            let dropPercent = Int(NSDecimalNumber(decimal: ((prevIncome - currentIncome) / prevIncome) * 100).intValue)
            risks.append(GoalRisk(
                type: .incomeVolatilityThreat,
                description: BuxLocalizedString.format(
                    "Income flow has decreased by %lld%% compared to last month.",
                    locale: locale,
                    dropPercent
                ),
                severity: "high",
                suggestedFix: BuxLocalizedString.string(
                    "Lower contribution amounts this period to protect your fundamental checking account cash flow.",
                    locale: locale
                )
            ))
        }

        return risks
    }
}
