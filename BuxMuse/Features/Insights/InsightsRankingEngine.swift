//
//  InsightsRankingEngine.swift
//  BuxMuse
//  Features/Insights/
//
//  Insights Ranking Engine evaluating severity, impact, and fatigue rules.
//

import Foundation

public final class InsightsRankingEngine {
    public init() {}
    
    public func rank(insights: [FinancialInsight]) -> [FinancialInsight] {
        return insights.sorted { (lhs, rhs) -> Bool in
            let scoreL = calculateScore(lhs)
            let scoreR = calculateScore(rhs)
            if scoreL != scoreR {
                return scoreL > scoreR
            }
            return lhs.title < rhs.title
        }
    }
    
    private func calculateScore(_ insight: FinancialInsight) -> Double {
        var score: Double = 0
        
        // 1. Severity Score contribution
        switch insight.severity {
        case .high: score += 500
        case .medium: score += 300
        case .low: score += 100
        }
        
        // 2. Financial Impact contribution
        let impactValue = Double(truncating: abs(insight.impactMonthly) as NSDecimalNumber)
        score += impactValue * 1.5
        
        // 3. Category Urgency contribution
        switch insight.category {
        case .predictive: score += 150
        case .subscription: score += 120
        case .spending: score += 80
        case .category: score += 50
        case .merchant: score += 40
        case .goal: score += 30
        case .pattern: score += 10
        }
        
        return score
    }
}
