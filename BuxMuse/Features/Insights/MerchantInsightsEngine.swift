//
//  MerchantInsightsEngine.swift
//  BuxMuse
//  Features/Insights/
//
//  Merchant Insights Engine analyzing vendor price movements and billing cadences.
//

import Foundation

public final class MerchantInsightsEngine {
    public init() {}
    
    public func generateInsights(transactions: [Transaction]) -> [FinancialInsight] {
        var insights: [FinancialInsight] = []
        guard !transactions.isEmpty else { return [] }
        
        let expenses = transactions.filter { $0.category != .income }
        let merchantGroups = Dictionary(grouping: expenses) { $0.merchantName }
        
        for (merchant, txs) in merchantGroups {
            guard txs.count >= 2 else { continue }
            
            let sortedTxs = txs.sorted(by: { $0.date > $1.date })
            let latestAmount = abs(sortedTxs[0].amount.value)
            let previousAmount = abs(sortedTxs[1].amount.value)
            
            // 1. Merchant Price Change Detection
            if latestAmount > previousAmount * 1.10 {
                let increase = latestAmount - previousAmount
                insights.append(FinancialInsight(
                    title: "Merchant Price Spike",
                    value: "Price Hike",
                    description: "You paid more at \(merchant).",
                    fullExplanation: "Your latest charge of £\(latestAmount) at \(merchant) is higher than the previous transaction of £\(previousAmount). This represents a price rise of £\(increase).",
                    severity: .medium,
                    category: .merchant,
                    systemIcon: "tag.fill",
                    accentColorName: "orange",
                    suggestedActions: [
                        "Verify if the price change is due to a plan upgrade or extra tax fees.",
                        "Consider competitive alternatives or bundling options."
                    ],
                    impactMonthly: increase,
                    dataBehind: "Merchant: \(merchant). Current: £\(latestAmount). Previous: £\(previousAmount)."
                ))
            }
            
            // 2. Merchant Refund Flagging
            let refunds = transactions.filter { $0.merchantName == merchant && $0.amount.value > 0 && $0.category != .income }
            if !refunds.isEmpty {
                let refundSum = refunds.reduce(Decimal(0)) { $0 + $1.amount.value }
                insights.append(FinancialInsight(
                    title: "Merchant Refund Cleared",
                    value: "Refund Saved",
                    description: "A refund from \(merchant) has cleared.",
                    fullExplanation: "The BuxMuse Brain successfully reconciled a cleared credit/refund of £\(refundSum) from \(merchant) back into your main wallet.",
                    severity: .low,
                    category: .merchant,
                    systemIcon: "arrow.uturn.backward.circle.fill",
                    accentColorName: "green",
                    suggestedActions: [
                        "Verify that this refund matches your expectations.",
                        "Re-route this refund into your active savings goals."
                    ],
                    impactMonthly: refundSum,
                    dataBehind: "Merchant: \(merchant). Refund: £\(refundSum)."
                ))
            }
        }
        
        return insights
    }
}
