//
//  GoalsHealthEngine.swift
//  BuxMuse
//  Features/Goals/
//
//  Aggregates active risks, deposit frequencies, and cash flows to return a goal health index.
//

import Foundation

public final class GoalsHealthEngine {
    
    public init() {}
    
    /// Evaluates the general wellness and progress metric of a saving goal.
    public func evaluateHealth(
        goal: Goal,
        risks: [GoalRisk],
        momentumScore: Double
    ) -> GoalHealth {
        var score = 100
        
        // 1. Deduct points for active risks
        var highRiskCount = 0
        var mediumRiskCount = 0
        
        for risk in risks {
            if risk.severity == "high" {
                score -= 20
                highRiskCount += 1
            } else if risk.severity == "medium" {
                score -= 10
                mediumRiskCount += 1
            } else {
                score -= 5
            }
        }
        
        // 2. Adjust based on momentum
        // momentumScore is -1.0 to 1.0. We scale it by 15 points.
        let momentumAdjustment = Int(momentumScore * 15.0)
        score += momentumAdjustment
        
        // Clamp score between 0 and 100
        score = max(0, min(100, score))
        
        // 3. Determine Stability & Volatility
        let stability: String
        if highRiskCount >= 2 {
            stability = "low"
        } else if highRiskCount == 1 || mediumRiskCount >= 2 {
            stability = "medium"
        } else {
            stability = "high"
        }
        
        // 4. Forecast Confidence Level
        // Confidence drops if there are many risks or very erratic momentum
        var confidence = 0.90
        confidence -= Double(risks.count) * 0.05
        confidence += (momentumScore > 0 ? 0.05 : -0.10)
        confidence = max(0.20, min(0.98, confidence))
        
        // Formulate a robust risk factors text list
        let riskFactors = risks.map { $0.description }
        
        return GoalHealth(
            score: score,
            riskFactors: riskFactors,
            momentum: momentumScore,
            stability: stability,
            confidenceLevel: confidence
        )
    }
}
