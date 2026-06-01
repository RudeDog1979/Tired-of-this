//
//  PaymentSourceInsightsEngine.swift
//  BuxMuse
//
//  Credit / BNPL / wallet concentration insights from optional payment source tags.
//

import Foundation

enum PaymentSourceInsightsEngine {
    static func generateInsights(transactions: [Transaction]) -> [FinancialInsight] {
        guard SettingsStore.shared.paymentSourceTrackingEnabled else { return [] }

        let spendTxs = transactions.filter { $0.amount.value < 0 && !($0.paymentMethod?.isEmpty ?? true) }
        guard !spendTxs.isEmpty else { return [] }

        var creditTotal = Decimal(0)
        var bnplTotal = Decimal(0)
        var bnplProviders = Set<String>()
        var creditCount = 0
        var totalTagged = Decimal(0)

        for tx in spendTxs {
            guard let method = tx.paymentMethod else { continue }
            let amount = abs(tx.amount.value)
            totalTagged += amount

            if let option = PaymentSourceCatalog.option(matching: method) {
                switch option.kind {
                case .credit, .storeCredit:
                    creditTotal += amount
                    creditCount += 1
                case .bnpl:
                    bnplTotal += amount
                    bnplProviders.insert(option.label)
                default:
                    break
                }
            } else if PaymentSourceCatalog.isCreditLike(method) {
                creditTotal += amount
                creditCount += 1
            }
        }

        guard totalTagged > 0 else { return [] }

        var insights: [FinancialInsight] = []
        let creditShare = creditTotal / totalTagged

        if creditCount >= 3, creditShare >= 0.45 {
            insights.append(
                FinancialInsight(
                    title: "Credit-heavy spending",
                    value: "\(Int(NSDecimalNumber(decimal: creditShare * 100).doubleValue))% on credit",
                    description: "\(creditCount) tagged expenses used credit or store credit this period.",
                    fullExplanation: "About \(InsightMoneyFormat.format(creditTotal)) of your tagged spending went through credit cards or store credit. High credit share can increase interest risk if balances aren't cleared on time.",
                    severity: creditShare >= 0.65 ? .high : .medium,
                    category: .pattern,
                    systemIcon: "creditcard.trianglebadge.exclamationmark",
                    accentColorName: "orange",
                    suggestedActions: ["Review credit-tagged expenses", "Set a weekly pay-down reminder"],
                    impactMonthly: creditTotal,
                    impactYearly: creditTotal * 12,
                    dataBehind: "Expenses with paymentMethod tagged as credit, store credit, or PayPal Credit."
                )
            )
        }

        if !bnplProviders.isEmpty {
            insights.append(
                FinancialInsight(
                    title: "Buy now, pay later active",
                    value: "\(bnplProviders.count) provider\(bnplProviders.count == 1 ? "" : "s")",
                    description: bnplProviders.sorted().joined(separator: ", "),
                    fullExplanation: "You tagged \(InsightMoneyFormat.format(bnplTotal)) through BNPL providers (\(bnplProviders.sorted().joined(separator: ", "))). Spread due dates so installments don't stack up.",
                    severity: bnplProviders.count >= 2 ? .medium : .low,
                    category: .pattern,
                    systemIcon: "clock.badge.exclamationmark.fill",
                    accentColorName: "purple",
                    suggestedActions: ["Check BNPL due dates", "Consolidate small BNPL plans"],
                    impactMonthly: bnplTotal,
                    impactYearly: bnplTotal * 12,
                    dataBehind: "Expenses tagged Klarna, Affirm, Afterpay, or Zip."
                )
            )
        }

        return insights
    }
}
