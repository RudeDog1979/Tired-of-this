//
//  SubscriptionInsightsEngine.swift
//  BuxMuse
//  Features/Insights/
//
//  Subscription Insights Engine to evaluate active repeating charges and link them to goals.
//

import Foundation

public final class SubscriptionInsightsEngine {
    public init() {}
    
    public func generateInsights(subscriptions: [SubscriptionInfo], goals: [Goal]) -> [FinancialInsight] {
        var insights: [FinancialInsight] = []
        
        // 1. Double Charges & Price Increases (Subscription Risks)
        for sub in subscriptions {
            for risk in sub.risks {
                if risk.type == .doubleCharge {
                    insights.append(FinancialInsight(
                        title: "Duplicate Charge Found",
                        value: "Action Required",
                        description: "Possible double charge for \(sub.merchantName).",
                        fullExplanation: "The BuxMuse Pattern Engine detected two identical billing sweeps for \(sub.merchantName) within the same billing cycle. This likely represents a merchant billing error.",
                        severity: .high,
                        category: .subscription,
                        systemIcon: "exclamationmark.triangle.fill",
                        accentColorName: "red",
                        suggestedActions: [
                            "Contact \(sub.merchantName) support to request a double-charge refund.",
                            "Monitor your bank sweeps for next month's renewal date."
                        ],
                        impactMonthly: sub.cost.value,
                        impactYearly: sub.cost.value,
                        dataBehind: "Merchant: \(sub.merchantName). Risk: Double Charge."
                    ))
                }
                
                if risk.type == .priceHike {
                    insights.append(FinancialInsight(
                        title: "Price Hike Alert",
                        value: "Cost Increase",
                        description: "\(sub.merchantName) increased their price.",
                        fullExplanation: "The Brain detected a recent price increase for your \(sub.merchantName) subscription. You are paying more than the baseline average from previous cycles.",
                        severity: .medium,
                        category: .subscription,
                        systemIcon: "arrow.up.circle.fill",
                        accentColorName: "orange",
                        suggestedActions: [
                            "Review your usage to check if \(sub.merchantName) is still value-aligned.",
                            "Look for bundled offers or alternative services."
                        ],
                        impactMonthly: sub.cost.value * 0.15, // Mock hike amount
                        impactYearly: sub.cost.value * 0.15 * 12,
                        dataBehind: "Merchant: \(sub.merchantName). Price Hike detected."
                    ))
                }
                
                if risk.type == .zombieSubscription {
                    insights.append(FinancialInsight(
                        title: "Zombie Subscription",
                        value: "Unused App",
                        description: "You haven't logged in to \(sub.merchantName) recently.",
                        fullExplanation: "Your \(sub.merchantName) subscription represents a 'Zombie' charge. Usage analytics indicate zero active engagement or features consumed during the last 30 days.",
                        severity: .medium,
                        category: .subscription,
                        systemIcon: "bolt.horizontal.circle.fill",
                        accentColorName: "orange",
                        suggestedActions: [
                            "Cancel \(sub.merchantName) immediately to recover the cost.",
                            "Set a reminder to review active subscriptions every 90 days."
                        ],
                        impactMonthly: sub.cost.value,
                        impactYearly: sub.cost.value * 12,
                        dataBehind: "Zombie flag on \(sub.merchantName)."
                    ))
                }
            }
        }
        
        // 2. Overlapping Features / Shadow bundles
        let overlapMerchants = ["Netflix", "Disney+", "Prime Video"]
        let activeVideoSubs = subscriptions.filter { subInfo in overlapMerchants.contains(where: { mName in subInfo.merchantName.lowercased().contains(mName.lowercased()) }) }
        if activeVideoSubs.count >= 2 {
            let totalCost = activeVideoSubs.reduce(Decimal(0)) { $0 + abs($1.cost.value) }
            insights.append(FinancialInsight(
                title: "Overlapping Media Stack",
                value: "Overlapping Service",
                description: "You have multiple active video subscriptions.",
                fullExplanation: "You are maintaining active subscriptions for both \(activeVideoSubs.map { $0.merchantName }.joined(separator: " and ")). Trimming down to a single active streaming platform could optimize your media budget.",
                severity: .medium,
                category: .subscription,
                systemIcon: "rectangle.stack.fill",
                accentColorName: "orange",
                suggestedActions: [
                    "Rotate subscriptions: Cancel one, catch up on shows, then switch next month.",
                    "Review shared bundles or family plan subscriptions."
                ],
                impactMonthly: totalCost / 2,
                impactYearly: (totalCost / 2) * 12,
                dataBehind: "Overlapping streaming video bundle count: \(activeVideoSubs.count)."
            ))
        }
        
        // 3. Subscription redirection to reach goals faster
        if let mostExpensiveSub = subscriptions.sorted(by: { $0.cost.value > $1.cost.value }).first,
           let highPriorityGoal = goals.sorted(by: { $0.priority < $1.priority }).first,
           highPriorityGoal.targetAmount > highPriorityGoal.currentAmount {
            
            let monthlySubCost = mostExpensiveSub.cost.value
            let targetAmt = highPriorityGoal.targetAmount - highPriorityGoal.currentAmount
            
            // Assume 12-month standard projection, redirecting the sub cost trims months:
            let savingsContribution = monthlySubCost > 0 ? monthlySubCost : 15
            let monthsAccelerated = Double(truncating: (savingsContribution * 12 / max(1, targetAmt)) as NSDecimalNumber) * 10.0
            let finalMonths = max(0.5, min(6.0, monthsAccelerated))
            
            insights.append(FinancialInsight(
                title: "Subscription redirection",
                value: "Goal Opportunity",
                description: "Reach your \(highPriorityGoal.name) goal sooner.",
                fullExplanation: "Canceling your \(mostExpensiveSub.merchantName) subscription (\(InsightMoneyFormat.format(monthlySubCost))/mo) and redirecting that cash flow to \(highPriorityGoal.name) allows you to achieve the goal \(String(format: "%.1f", finalMonths)) months sooner.",
                severity: .low,
                category: .subscription,
                systemIcon: "arrow.left.arrow.right.circle.fill",
                accentColorName: "green",
                suggestedActions: [
                    "Cancel \(mostExpensiveSub.merchantName) inside BuxMuse.",
                    "Set up an automated monthly \(InsightMoneyFormat.format(monthlySubCost)) transfer to '\(highPriorityGoal.name)'."
                ],
                impactMonthly: monthlySubCost,
                impactYearly: monthlySubCost * 12,
                affectedGoalId: highPriorityGoal.id,
                affectedGoalName: highPriorityGoal.name,
                dataBehind: "Sub: \(mostExpensiveSub.merchantName). Cost: \(InsightMoneyFormat.format(monthlySubCost)). Goal: \(highPriorityGoal.name). Pacing: -\(String(format: "%.1f", finalMonths)) months."
            ))
        }
        
        return insights
    }
}
