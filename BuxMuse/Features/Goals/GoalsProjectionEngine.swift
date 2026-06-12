//
//  GoalsProjectionEngine.swift
//  BuxMuse
//  Features/Goals/
//
//  Deterministic simulation model for expected, best, and worst-case goal completion dates.
//

import Foundation

public final class GoalsProjectionEngine {
    
    public init() {}
    
    /// Computes the expected completion dates and recommended contribution metrics.
    public func project(
        goal: Goal,
        transactions: [Transaction],
        activeSubscriptions: [SubscriptionInfo]
    ) -> GoalProjection {
        let remaining = max(0, goal.targetAmount - goal.currentAmount)
        if remaining == 0 {
            return GoalProjection(
                expectedCompletionDate: goal.createdAt,
                bestCaseDate: goal.createdAt,
                worstCaseDate: goal.createdAt,
                recommendedContribution: 0,
                contributionSchedule: "Monthly"
            )
        }
        
        let now = Date()
        
        // 1. Analyze historical contributions to this goal
        let directContributions = goal.contributions.sorted(by: { $0.date < $1.date })
        var avgMonthlyDirectContribution: Decimal = 0
        if !directContributions.isEmpty {
            if directContributions.count == 1 {
                avgMonthlyDirectContribution = directContributions[0].amount
            } else {
                let firstDate = directContributions.first!.date
                let lastDate = directContributions.last!.date
                let days = max(1.0, lastDate.timeIntervalSince(firstDate) / 86400.0)
                let months = Decimal(days / 30.0)
                let totalDirect = directContributions.reduce(Decimal(0)) { $0 + $1.amount }
                avgMonthlyDirectContribution = months > 0.1 ? (totalDirect / months) : totalDirect
            }
        }
        
        // 2. Analyze global transactions to determine net income/savings (Free Cash Flow)
        let calendar = Calendar.current
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: now) ?? now
        let recentTxs = transactions.filter { $0.date >= thirtyDaysAgo }
        
        let monthlyIncome = recentTxs.filter { $0.category == .income }.reduce(Decimal(0)) { $0 + $1.amount.value }
        let monthlyExpenses = recentTxs.filter { $0.category != .income }.reduce(Decimal(0)) { $0 + abs($1.amount.value) }
        
        let netSavingsRate = max(0, monthlyIncome - monthlyExpenses)
        
        // 3. Compute baseline monthly contribution
        // A portion of direct contributions and general cash flow
        var estimatedMonthlyContribution: Decimal = 0
        if avgMonthlyDirectContribution > 0 {
            estimatedMonthlyContribution = avgMonthlyDirectContribution
        } else if netSavingsRate > 0 {
            estimatedMonthlyContribution = netSavingsRate * 0.3 // Allocate 30% of FCF to this goal
        }
        
        // Fallback to avoid infinite division
        if estimatedMonthlyContribution <= 0 {
            estimatedMonthlyContribution = max(100, goal.targetAmount * 0.05)
        }
        
        // 4. Deadline-driven recommended contribution
        var recommendedAmount = estimatedMonthlyContribution
        var schedule = "Monthly"
        
        if let deadline = goal.deadline {
            let daysToDeadline = deadline.timeIntervalSince(now) / 86400.0
            let monthsToDeadline = max(1, Int(round(daysToDeadline / 30.43)))
            recommendedAmount = remaining / Decimal(monthsToDeadline)
            
            // Adjust schedule based on deadline proximity
            if monthsToDeadline < 2 {
                schedule = "Weekly"
                let secondsToDeadline = deadline.timeIntervalSince(now)
                let weeksToDeadline = max(1.0, secondsToDeadline / (7.0 * 86400.0))
                recommendedAmount = remaining / Decimal(weeksToDeadline)
            } else {
                schedule = "Monthly"
            }
        } else {
            // No deadline, recommend a savings level to finish in 12 months
            recommendedAmount = remaining / 12
        }
        
        // Clean up recommended amount decimals
        recommendedAmount = NSDecimalNumber(decimal: recommendedAmount).rounding(accordingToBehavior: nil).decimalValue
        
        // 5. Expected Completion Date
        let monthsToCompleteExpected = NSDecimalNumber(decimal: remaining / estimatedMonthlyContribution).doubleValue
        let secondsExpected = monthsToCompleteExpected * 30.0 * 86400.0
        let expectedDate = now.addingTimeInterval(secondsExpected)
        
        // 6. Best Case Date (Accelerated savings, no subscription burn/price hikes, 1.4x contribution)
        let monthsToCompleteBest = NSDecimalNumber(decimal: remaining / (estimatedMonthlyContribution * 1.4)).doubleValue
        let secondsBest = monthsToCompleteBest * 30.0 * 86400.0
        let bestDate = now.addingTimeInterval(secondsBest)
        
        // 7. Worst Case Date (Slower savings due to spikes/volatility, 0.7x contribution)
        let monthsToCompleteWorst = NSDecimalNumber(decimal: remaining / (estimatedMonthlyContribution * 0.7)).doubleValue
        let secondsWorst = monthsToCompleteWorst * 30.0 * 86400.0
        let worstDate = now.addingTimeInterval(secondsWorst)
        
        return GoalProjection(
            expectedCompletionDate: expectedDate,
            bestCaseDate: bestDate,
            worstCaseDate: worstDate,
            recommendedContribution: recommendedAmount,
            contributionSchedule: schedule
        )
    }
}
