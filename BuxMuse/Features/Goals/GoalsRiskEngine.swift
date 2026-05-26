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
        overspendAlerts: [OverspendAlert]
    ) -> [GoalRisk] {
        var risks: [GoalRisk] = []
        let now = Date()
        
        // 1. Check if expected completion falls after deadline (Falling Behind)
        if let deadline = goal.deadline {
            let projectionEngine = GoalsProjectionEngine()
            let projection = projectionEngine.project(goal: goal, transactions: transactions, activeSubscriptions: activeSubscriptions)
            
            if projection.expectedCompletionDate > deadline {
                let monthsOver = Calendar.current.dateComponents([.month], from: deadline, to: projection.expectedCompletionDate).month ?? 0
                let overStr = monthsOver > 0 ? "by \(monthsOver) month(s)" : "slightly"
                
                risks.append(GoalRisk(
                    type: .fallingBehind,
                    description: "Expected completion date is behind your set deadline \(overStr).",
                    severity: "high",
                    suggestedFix: "Increase monthly savings to \(projection.recommendedContribution) or extend the goal's deadline."
                ))
            }
        }
        
        // 2. Check for recent missed contributions (Missed Contribution)
        if !goal.contributions.isEmpty {
            let sortedContributions = goal.contributions.sorted(by: { $0.date > $1.date })
            if let lastContribution = sortedContributions.first?.date {
                let daysSinceLast = now.timeIntervalSince(lastContribution) / 86400.0
                if daysSinceLast > 35 {
                    risks.append(GoalRisk(
                        type: .missedContribution,
                        description: "It has been \(Int(daysSinceLast)) days since your last goal contribution.",
                        severity: "medium",
                        suggestedFix: "Set up an automatic recurring weekly or monthly transfer to stay on track."
                    ))
                }
            }
        } else {
            // No contributions ever made yet
            let daysSinceCreated = now.timeIntervalSince(goal.createdAt) / 86400.0
            if daysSinceCreated > 14 && goal.currentAmount == 0 {
                risks.append(GoalRisk(
                    type: .missedContribution,
                    description: "No contributions have been made to this goal since its creation \(Int(daysSinceCreated)) days ago.",
                    severity: "high",
                    suggestedFix: "Kickstart your goal by adding an initial contribution of any amount today."
                ))
            }
        }
        
        // 3. Overspend Threat: Check if active overspend alerts are high
        if !overspendAlerts.isEmpty {
            let totalOverspendPercent = overspendAlerts.reduce(0.0) { $0 + $1.overspendPercentage }
            if totalOverspendPercent > 30.0 {
                risks.append(GoalRisk(
                    type: .overspendThreat,
                    description: "Heavy overspending in categories like \(overspendAlerts.first?.category.displayName ?? "other") is draining cash reserves.",
                    severity: "high",
                    suggestedFix: "Pause non-essential shopping and implement category spending caps immediately."
                ))
            }
        }
        
        // 4. Subscription Renewal Threat: Subscription overhead is high
        let monthlySubscriptionCost = activeSubscriptions.reduce(Decimal(0)) { $0 + abs($1.cost.value) }
        if monthlySubscriptionCost > 150 {
            risks.append(GoalRisk(
                type: .subscriptionThreat,
                description: "Monthly subscription burn rate is £\(monthlySubscriptionCost), reducing your available goal funding.",
                severity: "medium",
                suggestedFix: "Review subscription hub and consider downgrading or pausing lesser-used services."
            ))
        }
        
        // 5. Irregular Expenses Threat
        let recentOtherExpenses = transactions.filter {
            $0.date >= Calendar.current.date(byAdding: .day, value: -30, to: now) ?? now &&
            ($0.category == .other || $0.category == .transport) &&
            $0.amount.value < -200
        }
        if !recentOtherExpenses.isEmpty {
            risks.append(GoalRisk(
                type: .irregularExpenseThreat,
                description: "Large, non-recurring expenses registered recently have temporarily impacted liquid savings.",
                severity: "medium",
                suggestedFix: "Create a dedicated buffer fund for unexpected car, travel, or device repairs."
            ))
        }
        
        // 6. Category Spike Threat
        if let highSpike = overspendAlerts.first(where: { $0.overspendPercentage > 50.0 }) {
            risks.append(GoalRisk(
                type: .categorySpikeThreat,
                description: "Spike detected: \(highSpike.category.displayName) spending is \(Int(highSpike.overspendPercentage))% above baseline.",
                severity: "high",
                suggestedFix: "Trim \(highSpike.category.displayName) expenditures by deferring purchases to next month."
            ))
        }
        
        // 7. Income Volatility Threat
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
                description: "Income flow has decreased by \(dropPercent)% compared to last month.",
                severity: "high",
                suggestedFix: "Lower contribution amounts this period to protect your fundamental checking account cash flow."
            ))
        }
        
        return risks
    }
}
