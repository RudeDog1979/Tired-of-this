//
//  DebtIntelligenceEngine.swift
//  BuxMuse
//
//  Fully on-device debt insights — payoff, risk, and payment momentum.
//

import Foundation

struct DebtInsight: Identifiable, Equatable {
    enum Tone: Equatable {
        case positive
        case neutral
        case warning
    }

    let id: String
    let title: String
    let message: String
    let tone: Tone
    let systemImage: String
    let debtId: UUID?
}

enum DebtIntelligenceEngine {
    static func portfolioInsights(debts: [Debt], locale: Locale = BuxInterfaceLocale.currentInterfaceLocale) -> [DebtInsight] {
        let active = debts.filter { !$0.isArchived }
        guard !active.isEmpty else { return [] }

        var insights: [DebtInsight] = []
        let totalOwed = active.reduce(Decimal(0)) { $0 + $1.currentBalance }

        if active.count > 1 {
            let highest = active.max(by: { $0.currentBalance < $1.currentBalance })
            if let highest, highest.currentBalance > 0 {
                insights.append(
                    DebtInsight(
                        id: "portfolio.focus",
                        title: BuxCatalogLabel.string("Focus payment", locale: locale),
                        message: BuxLocalizedString.format(
                            "%@ carries the largest balance — extra payments there reduce total interest fastest.",
                            locale: locale,
                            highest.name
                        ),
                        tone: .neutral,
                        systemImage: "scope",
                        debtId: highest.id
                    )
                )
            }
        }

        let dueSoon = active.compactMap { debt -> (Debt, Int)? in
            guard let days = debt.daysUntilDue else { return nil }
            return (debt, days)
        }.filter { $0.1 >= 0 && $0.1 <= 7 }

        for (debt, days) in dueSoon.prefix(2) {
            let message = days == 0
                ? BuxLocalizedString.format("%@ payment is due today.", locale: locale, debt.name)
                : BuxLocalizedString.format("%@ payment is due in %lld days.", locale: locale, debt.name, Int64(days))
            insights.append(
                DebtInsight(
                    id: "portfolio.due.\(debt.id.uuidString)",
                    title: BuxCatalogLabel.string("Due soon", locale: locale),
                    message: message,
                    tone: days <= 2 ? .warning : .neutral,
                    systemImage: "calendar.badge.clock",
                    debtId: debt.id
                )
            )
        }

        let noPaymentThisMonth = active.filter { $0.paidThisMonth == 0 && $0.currentBalance > 0 }
        if !noPaymentThisMonth.isEmpty, noPaymentThisMonth.count <= 3 {
            for debt in noPaymentThisMonth {
                insights.append(
                    DebtInsight(
                        id: "portfolio.nopay.\(debt.id.uuidString)",
                        title: BuxCatalogLabel.string("No payment yet", locale: locale),
                        message: BuxLocalizedString.format(
                            "You haven't logged a payment for %@ this month.",
                            locale: locale,
                            debt.name
                        ),
                        tone: .warning,
                        systemImage: "exclamationmark.circle",
                        debtId: debt.id
                    )
                )
            }
        }

        if totalOwed > 0 {
            insights.append(
                DebtInsight(
                    id: "portfolio.total",
                    title: BuxCatalogLabel.string("Debt snapshot", locale: locale),
                    message: BuxLocalizedString.format(
                        "You're tracking %lld active balances on this device.",
                        locale: locale,
                        Int64(active.count)
                    ),
                    tone: .neutral,
                    systemImage: "chart.pie.fill",
                    debtId: nil
                )
            )
        }

        return insights.prefix(6).map { $0 }
    }

    static func debtInsights(for debt: Debt, locale: Locale = BuxInterfaceLocale.currentInterfaceLocale) -> [DebtInsight] {
        guard !debt.isArchived else { return [] }
        var insights: [DebtInsight] = []

        if let fraction = debt.paidDownFraction, fraction >= 0.5 {
            let percent = Int(fraction * 100)
            insights.append(
                DebtInsight(
                    id: "debt.progress.\(debt.id.uuidString)",
                    title: BuxCatalogLabel.string("Great progress", locale: locale),
                    message: BuxLocalizedString.format(
                        "You've paid down %lld%% of the original balance.",
                        locale: locale,
                        Int64(percent)
                    ),
                    tone: .positive,
                    systemImage: "arrow.down.right.circle.fill",
                    debtId: debt.id
                )
            )
        }

        if let apr = debt.aprPercent, apr >= 20 {
            insights.append(
                DebtInsight(
                    id: "debt.apr.\(debt.id.uuidString)",
                    title: BuxCatalogLabel.string("High interest", locale: locale),
                    message: BuxLocalizedString.format(
                        "At %@%% APR, paying more than the minimum saves real money over time.",
                        locale: locale,
                        NSDecimalNumber(decimal: apr).stringValue
                    ),
                    tone: .warning,
                    systemImage: "flame.fill",
                    debtId: debt.id
                )
            )
        }

        if let payoff = debt.estimatedPayoffMonth {
            let formatter = DateFormatter()
            formatter.locale = locale
            formatter.dateFormat = "MMMM yyyy"
            insights.append(
                DebtInsight(
                    id: "debt.payoff.\(debt.id.uuidString)",
                    title: BuxCatalogLabel.string("Payoff path", locale: locale),
                    message: BuxLocalizedString.format(
                        "At your minimum payment, this could be paid off around %@.",
                        locale: locale,
                        formatter.string(from: payoff)
                    ),
                    tone: .neutral,
                    systemImage: "map.fill",
                    debtId: debt.id
                )
            )
        }

        if debt.lenderSource == .informalLender || debt.lenderSource == .friendOrFamily {
            insights.append(
                DebtInsight(
                    id: "debt.informal.\(debt.id.uuidString)",
                    title: BuxCatalogLabel.string("Informal loan", locale: locale),
                    message: BuxCatalogLabel.string(
                        "Log every payment so you always know what's left — even without a bank statement.",
                        locale: locale
                    ),
                    tone: .neutral,
                    systemImage: "heart.text.square.fill",
                    debtId: debt.id
                )
            )
        }

        if debt.currentBalance > 0, debt.currentBalance <= (debt.minimumPayment ?? 0) * 2 {
            insights.append(
                DebtInsight(
                    id: "debt.almost.\(debt.id.uuidString)",
                    title: BuxCatalogLabel.string("Almost there", locale: locale),
                    message: BuxCatalogLabel.string(
                        "You're close to clearing this balance. One more push could finish it.",
                        locale: locale
                    ),
                    tone: .positive,
                    systemImage: "checkmark.seal.fill",
                    debtId: debt.id
                )
            )
        }

        return insights.prefix(5).map { $0 }
    }
}
