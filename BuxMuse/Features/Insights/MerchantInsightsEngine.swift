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

    public func generateInsights(transactions: [Transaction], locale: Locale) -> [FinancialInsight] {
        var insights: [FinancialInsight] = []
        guard !transactions.isEmpty else { return [] }

        let expenses = transactions.filter { $0.category != .income }
        let merchantGroups = Dictionary(grouping: expenses) { $0.merchantName }

        for (merchant, txs) in merchantGroups {
            guard txs.count >= 2 else { continue }

            let sortedTxs = txs.sorted(by: { $0.date > $1.date })
            let latestAmount = abs(sortedTxs[0].amount.value)
            let previousAmount = abs(sortedTxs[1].amount.value)

            if latestAmount > previousAmount * 1.10 {
                let increase = latestAmount - previousAmount
                insights.append(FinancialInsight(
                    title: BuxLocalizedString.string("Merchant Price Spike", locale: locale),
                    value: BuxLocalizedString.string("Price Hike", locale: locale),
                    description: BuxLocalizedString.format("You paid more at %@.", locale: locale, merchant),
                    fullExplanation: BuxLocalizedString.format(
                        "Your latest charge of %@ at %@ is higher than the previous transaction of %@. This represents a price rise of %@.",
                        locale: locale,
                        InsightMoneyFormat.format(latestAmount),
                        merchant,
                        InsightMoneyFormat.format(previousAmount),
                        InsightMoneyFormat.format(increase)
                    ),
                    severity: .medium,
                    category: .merchant,
                    systemIcon: "tag.fill",
                    accentColorName: "orange",
                    suggestedActions: [
                        BuxLocalizedString.string(
                            "Verify if the price change is due to a plan upgrade or extra tax fees.",
                            locale: locale
                        ),
                        BuxLocalizedString.string(
                            "Consider competitive alternatives or bundling options.",
                            locale: locale
                        ),
                    ],
                    impactMonthly: increase,
                    dataBehind: BuxLocalizedString.format(
                        "Merchant: %@. Current: %@. Previous: %@.",
                        locale: locale,
                        merchant,
                        InsightMoneyFormat.format(latestAmount),
                        InsightMoneyFormat.format(previousAmount)
                    )
                ))
            }

            let refunds = transactions.filter { $0.merchantName == merchant && $0.amount.value > 0 && $0.category != .income }
            if !refunds.isEmpty {
                let refundSum = refunds.reduce(Decimal(0)) { $0 + $1.amount.value }
                insights.append(FinancialInsight(
                    title: BuxLocalizedString.string("Merchant Refund Cleared", locale: locale),
                    value: BuxLocalizedString.string("Refund Saved", locale: locale),
                    description: BuxLocalizedString.format("A refund from %@ has cleared.", locale: locale, merchant),
                    fullExplanation: BuxLocalizedString.format(
                        "The BuxMuse Brain successfully reconciled a cleared credit/refund of %@ from %@ back into your main wallet.",
                        locale: locale,
                        InsightMoneyFormat.format(refundSum),
                        merchant
                    ),
                    severity: .low,
                    category: .merchant,
                    systemIcon: "arrow.uturn.backward.circle.fill",
                    accentColorName: "green",
                    suggestedActions: [
                        BuxLocalizedString.string(
                            "Verify that this refund matches your expectations.",
                            locale: locale
                        ),
                        BuxLocalizedString.string(
                            "Re-route this refund into your active savings goals.",
                            locale: locale
                        ),
                    ],
                    impactMonthly: refundSum,
                    dataBehind: BuxLocalizedString.format(
                        "Merchant: %@. Refund: %@.",
                        locale: locale,
                        merchant,
                        InsightMoneyFormat.format(refundSum)
                    )
                ))
            }
        }

        return insights
    }
}
