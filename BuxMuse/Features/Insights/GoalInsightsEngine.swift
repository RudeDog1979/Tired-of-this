//
//  GoalInsightsEngine.swift
//  BuxMuse
//  Features/Insights/
//
//  Goal Insights Engine analyzing savings target timelines and milestones.
//

import Foundation

public final class GoalInsightsEngine {
    public init() {}
    
    public func generateInsights(
        goals: [Goal],
        goalsViewModel: GoalsViewModel,
        currencyCode: String = AppSettingsManager.preferredCurrencyCode
    ) -> [FinancialInsight] {
        var insights: [FinancialInsight] = []
        let redirectAmount = AppSettingsManager.format(
            amount: Decimal(15),
            currency: AppSettingsManager.currencySetting(for: currencyCode)
        )
        
        for goal in goals {
            let detail = goalsViewModel.buildDetailState(for: goal)
            
            // 1. Ahead of Schedule
            if detail.health.score >= 85 && detail.timelineAI.delayRisk == "Low" {
                insights.append(FinancialInsight(
                    title: "Goal Ahead of Schedule",
                    value: "Ahead Pace",
                    description: "You're on track to achieve '\(goal.name)'.",
                    fullExplanation: "With a strong health score of \(detail.health.score)% and consistent contributions, you are trending ahead of your original pacing schedules for '\(goal.name)'.",
                    severity: .low,
                    category: .goal,
                    systemIcon: "clock.badge.checkmark.fill",
                    accentColorName: "green",
                    suggestedActions: [
                        "Keep your deposit cadence locked in to finish early.",
                        "Direct extra surplus to accelerate other goals."
                    ],
                    impactMonthly: 0,
                    affectedGoalId: goal.id,
                    affectedGoalName: goal.name,
                    dataBehind: "Goal: \(goal.name). Health: \(detail.health.score)%."
                ))
            }
            
            // 2. Behind Schedule / Risk
            if detail.health.score < 55 {
                insights.append(FinancialInsight(
                    title: "Goal Timeline At Risk",
                    value: "Behind Pace",
                    description: "Timeline risk detected for '\(goal.name)'.",
                    fullExplanation: "A low health score of \(detail.health.score)% indicates high timeline delay risk. Contributions are falling behind standard forecast timelines.",
                    severity: .high,
                    category: .goal,
                    systemIcon: "exclamationmark.shield.fill",
                    accentColorName: "red",
                    suggestedActions: [
                        "Consider minor target date adjustments to reduce baseline pressure.",
                        "Re-route \(redirectAmount) from active media subscription overspends to boost momentum."
                    ],
                    impactMonthly: detail.projection.recommendedContribution * 0.2,
                    affectedGoalId: goal.id,
                    affectedGoalName: goal.name,
                    dataBehind: "Goal: \(goal.name). Health: \(detail.health.score)%."
                ))
            }
        }
        
        return insights
    }
}
