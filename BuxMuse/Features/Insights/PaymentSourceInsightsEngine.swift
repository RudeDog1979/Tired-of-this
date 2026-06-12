//
//  PaymentSourceInsightsEngine.swift
//  BuxMuse
//
//  Credit / BNPL / wallet concentration insights from optional payment source tags.
//

import Foundation

enum PaymentSourceInsightsEngine {
    static func generateInsights(transactions: [Transaction], locale: Locale) -> [FinancialInsight] {
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
            let pct = Int(NSDecimalNumber(decimal: creditShare * 100).doubleValue)
            insights.append(
                FinancialInsight(
                    title: BuxLocalizedString.string("Credit-heavy spending", locale: locale),
                    value: BuxLocalizedString.format("%lld%% on credit", locale: locale, pct),
                    description: BuxLocalizedString.format(
                        "%lld tagged expenses used credit or store credit this period.",
                        locale: locale,
                        creditCount
                    ),
                    fullExplanation: BuxLocalizedString.format(
                        "About %@ of your tagged spending went through credit cards or store credit. High credit share can increase interest risk if balances aren't cleared on time.",
                        locale: locale,
                        InsightMoneyFormat.format(creditTotal)
                    ),
                    severity: creditShare >= 0.65 ? .high : .medium,
                    category: .pattern,
                    systemIcon: "creditcard.trianglebadge.exclamationmark",
                    accentColorName: "orange",
                    suggestedActions: [
                        BuxLocalizedString.string("Review credit-tagged expenses", locale: locale),
                        BuxLocalizedString.string("Set a weekly pay-down reminder", locale: locale),
                    ],
                    impactMonthly: creditTotal,
                    impactYearly: creditTotal * 12,
                    dataBehind: BuxLocalizedString.string(
                        "Expenses with paymentMethod tagged as credit, store credit, or PayPal Credit.",
                        locale: locale
                    )
                )
            )
        }

        if !bnplProviders.isEmpty {
            let providerList = bnplProviders.sorted().joined(separator: ", ")
            insights.append(
                FinancialInsight(
                    title: BuxLocalizedString.string("Buy now, pay later active", locale: locale),
                    value: bnplProviders.count == 1
                        ? BuxLocalizedString.format("%lld provider", locale: locale, bnplProviders.count)
                        : BuxLocalizedString.format("%lld providers", locale: locale, bnplProviders.count),
                    description: providerList,
                    fullExplanation: BuxLocalizedString.format(
                        "You tagged %@ through BNPL providers (%@). Spread due dates so installments don't stack up.",
                        locale: locale,
                        InsightMoneyFormat.format(bnplTotal),
                        providerList
                    ),
                    severity: bnplProviders.count >= 2 ? .medium : .low,
                    category: .pattern,
                    systemIcon: "clock.badge.exclamationmark.fill",
                    accentColorName: "purple",
                    suggestedActions: [
                        BuxLocalizedString.string("Check BNPL due dates", locale: locale),
                        BuxLocalizedString.string("Consolidate small BNPL plans", locale: locale),
                    ],
                    impactMonthly: bnplTotal,
                    impactYearly: bnplTotal * 12,
                    dataBehind: BuxLocalizedString.string(
                        "Expenses tagged Klarna, Affirm, Afterpay, or Zip.",
                        locale: locale
                    )
                )
            )
        }

        return insights
    }
}
