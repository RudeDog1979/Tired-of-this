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
    
    public func generateInsights(subscriptions: [SubscriptionInfo], goals: [Goal], locale: Locale) -> [FinancialInsight] {
        var insights: [FinancialInsight] = []
        
        // 1. Double Charges & Price Increases (Subscription Risks)
        for sub in subscriptions {
            for risk in sub.risks {
                if risk.type == .doubleCharge {
                    insights.append(FinancialInsight(
                        title: BuxLocalizedString.string("Duplicate Charge Found", locale: locale),
                        value: BuxLocalizedString.string("Action Required", locale: locale),
                        description: BuxLocalizedString.format(
                            "Possible double charge for %@.",
                            locale: locale,
                            sub.merchantName
                        ),
                        fullExplanation: BuxLocalizedString.format(
                            "The BuxMuse Pattern Engine detected two identical billing sweeps for %@ within the same billing cycle. This likely represents a merchant billing error.",
                            locale: locale,
                            sub.merchantName
                        ),
                        severity: .high,
                        category: .subscription,
                        systemIcon: "exclamationmark.triangle.fill",
                        accentColorName: "red",
                        suggestedActions: [
                            BuxLocalizedString.format(
                                "Contact %@ support to request a double-charge refund.",
                                locale: locale,
                                sub.merchantName
                            ),
                            BuxLocalizedString.string(
                                "Monitor your bank sweeps for next month's renewal date.",
                                locale: locale
                            ),
                        ],
                        impactMonthly: sub.cost.value,
                        impactYearly: sub.cost.value,
                        dataBehind: BuxLocalizedString.format(
                            "Merchant: %@. Risk: Double Charge.",
                            locale: locale,
                            sub.merchantName
                        )
                    ))
                }
                
                if risk.type == .priceHike {
                    insights.append(FinancialInsight(
                        title: BuxLocalizedString.string("Price Hike Alert", locale: locale),
                        value: BuxLocalizedString.string("Cost Increase", locale: locale),
                        description: BuxLocalizedString.format(
                            "%@ increased their price.",
                            locale: locale,
                            sub.merchantName
                        ),
                        fullExplanation: BuxLocalizedString.format(
                            "The Brain detected a recent price increase for your %@ subscription. You are paying more than the baseline average from previous cycles.",
                            locale: locale,
                            sub.merchantName
                        ),
                        severity: .medium,
                        category: .subscription,
                        systemIcon: "arrow.up.circle.fill",
                        accentColorName: "orange",
                        suggestedActions: [
                            BuxLocalizedString.format(
                                "Review your usage to check if %@ is still value-aligned.",
                                locale: locale,
                                sub.merchantName
                            ),
                            BuxLocalizedString.string(
                                "Look for bundled offers or alternative services.",
                                locale: locale
                            ),
                        ],
                        impactMonthly: sub.cost.value * 0.15,
                        impactYearly: sub.cost.value * 0.15 * 12,
                        dataBehind: BuxLocalizedString.format(
                            "Merchant: %@. Price Hike detected.",
                            locale: locale,
                            sub.merchantName
                        )
                    ))
                }
                
                if risk.type == .zombieSubscription {
                    insights.append(FinancialInsight(
                        title: BuxLocalizedString.string("Zombie Subscription", locale: locale),
                        value: BuxLocalizedString.string("Unused App", locale: locale),
                        description: BuxLocalizedString.format(
                            "You haven't logged in to %@ recently.",
                            locale: locale,
                            sub.merchantName
                        ),
                        fullExplanation: BuxLocalizedString.format(
                            "Your %@ subscription represents a 'Zombie' charge. Usage analytics indicate zero active engagement or features consumed during the last 30 days.",
                            locale: locale,
                            sub.merchantName
                        ),
                        severity: .medium,
                        category: .subscription,
                        systemIcon: "bolt.horizontal.circle.fill",
                        accentColorName: "orange",
                        suggestedActions: [
                            BuxLocalizedString.format(
                                "Cancel %@ immediately to recover the cost.",
                                locale: locale,
                                sub.merchantName
                            ),
                            BuxLocalizedString.string(
                                "Set a reminder to review active subscriptions every 90 days.",
                                locale: locale
                            ),
                        ],
                        impactMonthly: sub.cost.value,
                        impactYearly: sub.cost.value * 12,
                        dataBehind: BuxLocalizedString.format(
                            "Zombie flag on %@.",
                            locale: locale,
                            sub.merchantName
                        )
                    ))
                }
            }
        }
        
        // 2. Overlapping Features / Shadow bundles
        let overlapMerchants = ["Netflix", "Disney+", "Prime Video"]
        let activeVideoSubs = subscriptions.filter { subInfo in overlapMerchants.contains(where: { mName in subInfo.merchantName.lowercased().contains(mName.lowercased()) }) }
        if activeVideoSubs.count >= 2 {
            let totalCost = activeVideoSubs.reduce(Decimal(0)) { $0 + abs($1.cost.value) }
            let merchantList = activeVideoSubs.map(\.merchantName).joined(separator: " and ")
            insights.append(FinancialInsight(
                title: BuxLocalizedString.string("Overlapping Media Stack", locale: locale),
                value: BuxLocalizedString.string("Overlapping Service", locale: locale),
                description: BuxLocalizedString.string(
                    "You have multiple active video subscriptions.",
                    locale: locale
                ),
                fullExplanation: BuxLocalizedString.format(
                    "You are maintaining active subscriptions for both %@. Trimming down to a single active streaming platform could optimize your media budget.",
                    locale: locale,
                    merchantList
                ),
                severity: .medium,
                category: .subscription,
                systemIcon: "rectangle.stack.fill",
                accentColorName: "orange",
                suggestedActions: [
                    BuxLocalizedString.string(
                        "Rotate subscriptions: Cancel one, catch up on shows, then switch next month.",
                        locale: locale
                    ),
                    BuxLocalizedString.string(
                        "Review shared bundles or family plan subscriptions.",
                        locale: locale
                    ),
                ],
                impactMonthly: totalCost / 2,
                impactYearly: (totalCost / 2) * 12,
                dataBehind: BuxLocalizedString.format(
                    "Overlapping streaming video bundle count: %lld.",
                    locale: locale,
                    activeVideoSubs.count
                )
            ))
        }
        
        // 3. Subscription redirection to reach goals faster
        if let mostExpensiveSub = subscriptions.sorted(by: { $0.cost.value > $1.cost.value }).first,
           let highPriorityGoal = goals.sorted(by: { $0.priority < $1.priority }).first,
           highPriorityGoal.targetAmount > highPriorityGoal.currentAmount {
            
            let monthlySubCost = mostExpensiveSub.cost.value
            let targetAmt = highPriorityGoal.targetAmount - highPriorityGoal.currentAmount
            
            let savingsContribution = monthlySubCost > 0 ? monthlySubCost : 15
            let monthsAccelerated = Double(truncating: (savingsContribution * 12 / max(1, targetAmt)) as NSDecimalNumber) * 10.0
            let finalMonths = max(0.5, min(6.0, monthsAccelerated))
            let monthsLabel = String(format: "%.1f", finalMonths)
            
            insights.append(FinancialInsight(
                title: BuxLocalizedString.string("Subscription redirection", locale: locale),
                value: BuxLocalizedString.string("Goal Opportunity", locale: locale),
                description: BuxLocalizedString.format(
                    "Reach your %@ goal sooner.",
                    locale: locale,
                    highPriorityGoal.name
                ),
                fullExplanation: BuxLocalizedString.format(
                    "Canceling your %@ subscription (%@/mo) and redirecting that cash flow to %@ allows you to achieve the goal %@ months sooner.",
                    locale: locale,
                    mostExpensiveSub.merchantName,
                    InsightMoneyFormat.format(monthlySubCost),
                    highPriorityGoal.name,
                    monthsLabel
                ),
                severity: .low,
                category: .subscription,
                systemIcon: "arrow.left.arrow.right.circle.fill",
                accentColorName: "green",
                suggestedActions: [
                    BuxLocalizedString.format(
                        "Cancel %@ inside BuxMuse.",
                        locale: locale,
                        mostExpensiveSub.merchantName
                    ),
                    BuxLocalizedString.format(
                        "Set up an automated monthly %@ transfer to '%@'.",
                        locale: locale,
                        InsightMoneyFormat.format(monthlySubCost),
                        highPriorityGoal.name
                    ),
                ],
                impactMonthly: monthlySubCost,
                impactYearly: monthlySubCost * 12,
                affectedGoalId: highPriorityGoal.id,
                affectedGoalName: highPriorityGoal.name,
                dataBehind: BuxLocalizedString.format(
                    "Sub: %@. Cost: %@. Goal: %@. Pacing: -%@ months.",
                    locale: locale,
                    mostExpensiveSub.merchantName,
                    InsightMoneyFormat.format(monthlySubCost),
                    highPriorityGoal.name,
                    monthsLabel
                )
            ))
        }
        
        return insights
    }
}
