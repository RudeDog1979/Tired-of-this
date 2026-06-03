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
        locale: Locale,
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
                    title: BuxLocalizedString.string("Goal Ahead of Schedule", locale: locale),
                    value: BuxLocalizedString.string("Ahead Pace", locale: locale),
                    description: BuxLocalizedString.format(
                        "You're on track to achieve '%@'.",
                        locale: locale,
                        goal.name
                    ),
                    fullExplanation: BuxLocalizedString.format(
                        "With a strong health score of %lld%% and consistent contributions, you are trending ahead of your original pacing schedules for '%@'.",
                        locale: locale,
                        detail.health.score,
                        goal.name
                    ),
                    severity: .low,
                    category: .goal,
                    systemIcon: "clock.badge.checkmark.fill",
                    accentColorName: "green",
                    suggestedActions: [
                        BuxLocalizedString.string(
                            "Keep your deposit cadence locked in to finish early.",
                            locale: locale
                        ),
                        BuxLocalizedString.string(
                            "Direct extra surplus to accelerate other goals.",
                            locale: locale
                        ),
                    ],
                    impactMonthly: 0,
                    affectedGoalId: goal.id,
                    affectedGoalName: goal.name,
                    dataBehind: BuxLocalizedString.format(
                        "Goal: %@. Health: %lld%%.",
                        locale: locale,
                        goal.name,
                        detail.health.score
                    )
                ))
            }
            
            // 2. Behind Schedule / Risk
            if detail.health.score < 55 {
                insights.append(FinancialInsight(
                    title: BuxLocalizedString.string("Goal Timeline At Risk", locale: locale),
                    value: BuxLocalizedString.string("Behind Pace", locale: locale),
                    description: BuxLocalizedString.format(
                        "Timeline risk detected for '%@'.",
                        locale: locale,
                        goal.name
                    ),
                    fullExplanation: BuxLocalizedString.format(
                        "A low health score of %lld%% indicates high timeline delay risk. Contributions are falling behind standard forecast timelines.",
                        locale: locale,
                        detail.health.score
                    ),
                    severity: .high,
                    category: .goal,
                    systemIcon: "exclamationmark.shield.fill",
                    accentColorName: "red",
                    suggestedActions: [
                        BuxLocalizedString.string(
                            "Consider minor target date adjustments to reduce baseline pressure.",
                            locale: locale
                        ),
                        BuxLocalizedString.format(
                            "Re-route %@ from active media subscription overspends to boost momentum.",
                            locale: locale,
                            redirectAmount
                        ),
                    ],
                    impactMonthly: detail.projection.recommendedContribution * 0.2,
                    affectedGoalId: goal.id,
                    affectedGoalName: goal.name,
                    dataBehind: BuxLocalizedString.format(
                        "Goal: %@. Health: %lld%%.",
                        locale: locale,
                        goal.name,
                        detail.health.score
                    )
                ))
            }
        }
        
        return insights
    }
}
