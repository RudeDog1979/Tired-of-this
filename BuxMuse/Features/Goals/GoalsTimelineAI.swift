//
//  GoalsTimelineAI.swift
//  BuxMuse
//  Features/Goals/
//
//  Predicts exact dates, scenario pathways, and 'what-if' budget redirections.
//

import Foundation

public struct GoalTimelineScenario: Codable, Equatable, Identifiable {
    public let id: String
    public let name: String
    public let projectedDate: Date
    public let delayRisk: String
    public let description: String
}

public struct GoalsTimelineAIResult {
    public let expectedCompletionDate: Date
    public let delayRisk: String
    public let accelerationPotentialMonths: Double
    public let scenarios: [GoalTimelineScenario]
    public let actionableInsight: String
}

public final class GoalsTimelineAI {

    public init() {}

    public func analyzeTimeline(
        goal: Goal,
        projection: GoalProjection,
        risks: [GoalRisk],
        opportunities: [GoalOpportunity],
        locale: Locale = BuxInterfaceLocale.currentInterfaceLocale
    ) -> GoalsTimelineAIResult {
        let remaining = max(0, goal.targetAmount - goal.currentAmount)
        let now = Date()

        let delayRisk: String
        let highRisks = risks.filter { $0.severity == "high" }
        if !highRisks.isEmpty {
            delayRisk = BuxLocalizedString.string("High", locale: locale)
        } else if risks.count >= 2 {
            delayRisk = BuxLocalizedString.string("Medium", locale: locale)
        } else {
            delayRisk = BuxLocalizedString.string("Low", locale: locale)
        }

        let monthsToExpected = max(0.5, projection.expectedCompletionDate.timeIntervalSinceNow / (30.0 * 86400.0))

        let moderateSavingsRate = projection.recommendedContribution * 1.25
        let moderateMonths = remaining > 0 ? NSDecimalNumber(decimal: remaining / moderateSavingsRate).doubleValue : 0.0
        let moderateDate = now.addingTimeInterval(moderateMonths * 30.0 * 86400.0)

        let aggressiveSavingsRate = projection.recommendedContribution * 1.6
        let aggressiveMonths = remaining > 0 ? NSDecimalNumber(decimal: remaining / aggressiveSavingsRate).doubleValue : 0.0
        let aggressiveDate = now.addingTimeInterval(aggressiveMonths * 30.0 * 86400.0)

        let scenarios = [
            GoalTimelineScenario(
                id: "baseline",
                name: BuxLocalizedString.string("Current Pace", locale: locale),
                projectedDate: projection.expectedCompletionDate,
                delayRisk: delayRisk,
                description: BuxLocalizedString.string("Maintain your standard deposit speed.", locale: locale)
            ),
            GoalTimelineScenario(
                id: "moderate",
                name: BuxLocalizedString.string("Moderate Trim", locale: locale),
                projectedDate: moderateDate,
                delayRisk: BuxLocalizedString.string("Low", locale: locale),
                description: BuxLocalizedString.string("Reduce groceries and restaurants by 10%.", locale: locale)
            ),
            GoalTimelineScenario(
                id: "aggressive",
                name: BuxLocalizedString.string("Aggressive Focus", locale: locale),
                projectedDate: aggressiveDate,
                delayRisk: BuxLocalizedString.string("Low", locale: locale),
                description: BuxLocalizedString.string("Cancel unused memberships & pause non-essential shopping.", locale: locale)
            ),
        ]

        let accelerationPotential = max(0.0, monthsToExpected - aggressiveMonths)

        var actionableInsight = BuxLocalizedString.string(
            "Reach your goal faster by setting up a small recurring weekly contribution.",
            locale: locale
        )
        if let topOpportunity = opportunities.first {
            actionableInsight = BuxLocalizedString.format(
                "If you %@ %@",
                locale: locale,
                topOpportunity.description.lowercased(),
                topOpportunity.benefit.lowercased()
            )
        }

        return GoalsTimelineAIResult(
            expectedCompletionDate: projection.expectedCompletionDate,
            delayRisk: delayRisk,
            accelerationPotentialMonths: accelerationPotential,
            scenarios: scenarios,
            actionableInsight: actionableInsight
        )
    }
}
