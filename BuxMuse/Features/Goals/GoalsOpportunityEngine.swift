//
//  GoalsOpportunityEngine.swift
//  BuxMuse
//  Features/Goals/
//
//  Identifies budget margins, subscription trims, and categories to accelerate goals.
//

import Foundation

public struct GoalOpportunity: Codable, Equatable, Identifiable {
    public let id: UUID
    public let description: String
    public let benefit: String
    public let potentialSavings: Decimal
    
    public init(id: UUID = UUID(), description: String, benefit: String, potentialSavings: Decimal) {
        self.id = id
        self.description = description
        self.benefit = benefit
        self.potentialSavings = potentialSavings
    }
}

public final class GoalsOpportunityEngine {
    
    public init() {}
    
    /// Identifies optimization actions based on active subscriptions and spending.
    public func findOpportunities(
        goal: Goal,
        transactions: [Transaction],
        activeSubscriptions: [SubscriptionInfo],
        savingsOpportunities: [SavingsOpportunity]
    ) -> [GoalOpportunity] {
        var list: [GoalOpportunity] = []
        let remaining = max(0, goal.targetAmount - goal.currentAmount)
        guard remaining > 0 else { return [] }
        
        let projectionEngine = GoalsProjectionEngine()
        let currentProj = projectionEngine.project(goal: goal, transactions: transactions, activeSubscriptions: activeSubscriptions)
        let monthsToExpected = max(1.0, currentProj.expectedCompletionDate.timeIntervalSinceNow / (30.0 * 86400.0))
        
        // 1. Subscription cancellation opportunity
        if let topSub = activeSubscriptions.first {
            let cost = abs(topSub.cost.value)
            
            // Calculate how much earlier they'd finish if they canceled this and redirected the funds
            let newSavingsRate = currentProj.recommendedContribution + cost
            let newMonthsToComplete = NSDecimalNumber(decimal: remaining / newSavingsRate).doubleValue
            let monthDifference = max(0.5, monthsToExpected - newMonthsToComplete)
            
            let formatDiff = String(format: "%.1f", monthDifference)
            list.append(GoalOpportunity(
                description: "Cancel your unused \(topSub.merchantName) subscription.",
                benefit: "Redirect £\(cost)/mo to reach your goal \(formatDiff) months earlier.",
                potentialSavings: cost
            ))
        }
        
        // 2. Category spending reduction opportunity
        if let topCategoryOpportunity = savingsOpportunities.first {
            let savings = topCategoryOpportunity.estimatedMonthlySavings?.value ?? 0
            if savings > 0 {
                let newSavingsRate = currentProj.recommendedContribution + savings
                let newMonthsToComplete = NSDecimalNumber(decimal: remaining / newSavingsRate).doubleValue
                let monthDifference = max(0.5, monthsToExpected - newMonthsToComplete)
                
                let formatDiff = String(format: "%.1f", monthDifference)
                list.append(GoalOpportunity(
                    description: "Trim \(topCategoryOpportunity.category?.displayName.lowercased() ?? "other") expenses by 15%.",
                    benefit: "Redirect £\(savings)/mo to finish \(formatDiff) months earlier.",
                    potentialSavings: savings
                ))
            }
        }
        
        // 3. Unallocated windfalls or refunds
        let calendar = Calendar.current
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let windfalls = transactions.filter {
            $0.date >= thirtyDaysAgo &&
            $0.category == .income &&
            $0.amount.value > 500.0 &&
            !$0.merchantName.lowercased().contains("salary") &&
            !$0.merchantName.lowercased().contains("payroll")
        }
        
        if let largeWindfall = windfalls.first {
            let value = largeWindfall.amount.value
            let remainingAfterWindfall = max(0, remaining - value)
            let newMonthsToComplete = NSDecimalNumber(decimal: remainingAfterWindfall / currentProj.recommendedContribution).doubleValue
            let monthDifference = max(0.5, monthsToExpected - newMonthsToComplete)
            
            let formatDiff = String(format: "%.1f", monthDifference)
            list.append(GoalOpportunity(
                description: "Redirect recent windfall from \(largeWindfall.merchantName) to your goal.",
                benefit: "Reach your goal \(formatDiff) months earlier with a one-time £\(value) deposit.",
                potentialSavings: value
            ))
        }
        
        // Default opportunity if empty
        if list.isEmpty {
            let suggestedSmallSaving = goal.targetAmount * 0.02
            let monthlySavings = suggestedSmallSaving
            let newSavingsRate = currentProj.recommendedContribution + monthlySavings
            let newMonthsToComplete = NSDecimalNumber(decimal: remaining / newSavingsRate).doubleValue
            let monthDifference = max(0.5, monthsToExpected - newMonthsToComplete)
            
            let formatDiff = String(format: "%.1f", monthDifference)
            list.append(GoalOpportunity(
                description: "Save an extra £\(monthlySavings)/mo by packing your own lunch.",
                benefit: "Accelerate your completion timeline by \(formatDiff) months.",
                potentialSavings: monthlySavings
            ))
        }
        
        return list
    }
}
