//
//  GoalsMomentumEngine.swift
//  BuxMuse
//  Features/Goals/
//
//  Tracks deposit frequencies and contribution velocity to calculate a momentum index.
//

import Foundation

public struct GoalMomentumResult {
    public let score: Double // -1.0 to 1.0
    public let statusDescription: String // "Accelerating", "Slowing Down", "Stalled", "Consistent Momentum"
    public let microActions: [String]
    public let habitActions: [String]
}

public final class GoalsMomentumEngine {
    
    public init() {}
    
    /// Computes momentum and generates customized action cards.
    public func computeMomentum(goal: Goal) -> GoalMomentumResult {
        let contributions = goal.contributions.sorted(by: { $0.date > $1.date })
        let now = Date()
        
        // 1. If no contributions, user is stalled
        guard !contributions.isEmpty else {
            let daysSinceCreated = now.timeIntervalSince(goal.createdAt) / 86400.0
            let score = daysSinceCreated > 14 ? -0.5 : 0.0
            return GoalMomentumResult(
                score: score,
                statusDescription: daysSinceCreated > 14 ? "Stalled" : "Awaiting Kickstart",
                microActions: [
                    "Deposit £10 today to initialize momentum.",
                    "Set a calendar reminder for weekly goal updates."
                ],
                habitActions: [
                    "Form a weekly check-in habit to review cash flow.",
                    "Match non-essential treats (like coffee) with a goal contribution."
                ]
            )
        }
        
        // 2. Classify contributions into recent (last 30 days) and previous (30-60 days ago)
        let thirtyDaysAgo = now.addingTimeInterval(-30.0 * 86400.0)
        let sixtyDaysAgo = now.addingTimeInterval(-60.0 * 86400.0)
        
        let recentContributions = contributions.filter { $0.date >= thirtyDaysAgo }
        let prevContributions = contributions.filter { $0.date >= sixtyDaysAgo && $0.date < thirtyDaysAgo }
        
        let recentSum = recentContributions.reduce(Decimal(0)) { $0 + $1.amount }
        let prevSum = prevContributions.reduce(Decimal(0)) { $0 + $1.amount }
        
        let recentSumDouble = NSDecimalNumber(decimal: recentSum).doubleValue
        let prevSumDouble = NSDecimalNumber(decimal: prevSum).doubleValue
        
        var score: Double = 0.0
        var status = "Consistent Momentum"
        var micro: [String] = []
        var habit: [String] = []
        
        if recentSumDouble == 0 && prevSumDouble == 0 {
            // Stalled for more than 60 days
            score = -0.8
            status = "Stalled"
            micro = [
                "Make a small £5 micro-contribution to break the dry spell.",
                "Review your budget to see where cash has been leak-drained."
            ]
            habit = [
                "Automate a micro-savings deposit of £1 per day.",
                "Link savings goals to positive daily habits."
            ]
        } else if recentSumDouble > 0 && prevSumDouble == 0 {
            // User just accelerated or started recently
            score = 0.6
            status = "Accelerating"
            micro = [
                "Double down! Try to add another £20 while in this active streak.",
                "Share your savings milestone with a trusted partner."
            ]
            habit = [
                "Keep this active momentum high by saving at the beginning of the week.",
                "Build a 3-week streak of consecutive contributions."
            ]
        } else if recentSumDouble == 0 && prevSumDouble > 0 {
            // Slipped/slowing down
            score = -0.4
            status = "Slowing Down"
            micro = [
                "Re-engage today by allocating just £10 to this goal.",
                "Audit recent purchases to identify saving leakages."
            ]
            habit = [
                "Reschedule savings day to align precisely with your payday.",
                "Avoid the 'all-or-nothing' mindset: small regular steps outperform large rare steps."
            ]
        } else {
            // Both are positive
            let ratio = recentSumDouble / prevSumDouble
            if ratio > 1.15 {
                score = min(1.0, 0.5 + (ratio - 1.0))
                status = "Accelerating"
                micro = [
                    "Excellent progress! Consider locking in a portion of this month's extra savings.",
                    "Review if your target date can be pulled forward."
                ]
                habit = [
                    "Increase your auto-saving amount by 5% to harness your momentum.",
                    "Reward yourself with a small, free celebration for accelerated pacing."
                ]
            } else if ratio < 0.85 {
                score = max(-0.6, -0.2 - (1.0 - ratio))
                status = "Slowing Down"
                micro = [
                    "Adjust your milestone targets slightly to feel less pressure.",
                    "Audit subscriptions to redirect a quick £15 today."
                ]
                habit = [
                    "Try 'zero-spend days' once a week to free up cash.",
                    "Keep contributions recurring to remove friction."
                ]
            } else {
                score = 0.4
                status = "Consistent Momentum"
                micro = [
                    "Maintain this excellent, stable velocity with your regular deposit.",
                    "Confirm your current cash reserves are healthy."
                ]
                habit = [
                    "Establish a permanent auto-contribution so you don't even have to think about it.",
                    "Maintain the 'pay yourself first' golden rule."
                ]
            }
        }
        
        return GoalMomentumResult(
            score: score,
            statusDescription: status,
            microActions: micro,
            habitActions: habit
        )
    }
}
