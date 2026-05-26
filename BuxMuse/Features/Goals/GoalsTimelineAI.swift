//
//  GoalsTimelineAI.swift
//  BuxMuse
//  Features/Goals/
//
//  Predicts exact dates, scenario pathways, and 'what-if' budget redirections.
//

import Foundation

public struct GoalTimelineScenario: Codable, Equatable, Identifiable {
    public let id: String // "baseline", "moderate", "aggressive"
    public let name: String
    public let projectedDate: Date
    public let delayRisk: String // "Low", "Medium", "High"
    public let description: String
}

public struct GoalsTimelineAIResult {
    public let expectedCompletionDate: Date
    public let delayRisk: String
    public let accelerationPotentialMonths: Double
    public let scenarios: [GoalTimelineScenario]
    public let actionableInsight: String // e.g. "If you cancel Netflix, you will reach your goal 1.4 months earlier."
}

public final class GoalsTimelineAI {
    
    public init() {}
    
    /// Projects exact scenario pathways and what-if acceleration benefits.
    public func analyzeTimeline(
        goal: Goal,
        projection: GoalProjection,
        risks: [GoalRisk],
        opportunities: [GoalOpportunity]
    ) -> GoalsTimelineAIResult {
        let remaining = max(0, goal.targetAmount - goal.currentAmount)
        let now = Date()
        
        // 1. Determine overall Delay Risk
        let delayRisk: String
        let highRisks = risks.filter { $0.severity == "high" }
        if !highRisks.isEmpty {
            delayRisk = "High"
        } else if risks.count >= 2 {
            delayRisk = "Medium"
        } else {
            delayRisk = "Low"
        }
        
        // 2. Build Alternative Scenarios
        let monthsToExpected = max(0.5, projection.expectedCompletionDate.timeIntervalSinceNow / (30.0 * 86400.0))
        
        // Moderate scenario: add standard savings increase or 1.2x pacing
        let moderateSavingsRate = projection.recommendedContribution * 1.25
        let moderateMonths = remaining > 0 ? NSDecimalNumber(decimal: remaining / moderateSavingsRate).doubleValue : 0.0
        let moderateDate = now.addingTimeInterval(moderateMonths * 30.0 * 86400.0)
        
        // Aggressive scenario: cancel top opportunities, 1.5x pacing
        let aggressiveSavingsRate = projection.recommendedContribution * 1.6
        let aggressiveMonths = remaining > 0 ? NSDecimalNumber(decimal: remaining / aggressiveSavingsRate).doubleValue : 0.0
        let aggressiveDate = now.addingTimeInterval(aggressiveMonths * 30.0 * 86400.0)
        
        let scenarios = [
            GoalTimelineScenario(
                id: "baseline",
                name: "Current Pace",
                projectedDate: projection.expectedCompletionDate,
                delayRisk: delayRisk,
                description: "Maintain your standard deposit speed."
            ),
            GoalTimelineScenario(
                id: "moderate",
                name: "Moderate Trim",
                projectedDate: moderateDate,
                delayRisk: "Low",
                description: "Reduce groceries and restaurants by 10%."
            ),
            GoalTimelineScenario(
                id: "aggressive",
                name: "Aggressive Focus",
                projectedDate: aggressiveDate,
                delayRisk: "Low",
                description: "Cancel unused memberships & pause non-essential shopping."
            )
        ]
        
        // 3. Compute acceleration potential in months
        let accelerationPotential = max(0.0, monthsToExpected - aggressiveMonths)
        
        // 4. Formulate actionable 'what-if' insight
        var actionableInsight = "Reach your goal faster by setting up a small recurring weekly contribution."
        if let topOpportunity = opportunities.first {
            actionableInsight = "If you \(topOpportunity.description.lowercased()) \(topOpportunity.benefit.lowercased())"
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
