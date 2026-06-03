//
//  FeatureInsightsEngines.swift
//  BuxMuse
//
//  Workspace, cash/digital, and scope-creep insights for the intelligence layer.
//

import Foundation

enum WorkspaceInsightsEngine {
    static func generateInsights(transactions: [Transaction], locale: Locale) -> [FinancialInsight] {
        guard SettingsStore.shared.sideHustleMatrixEnabled else { return [] }

        let monthStart = Calendar.current.dateInterval(of: .month, for: Date())?.start ?? Date()
        let monthTxs = transactions.filter { $0.date >= monthStart && $0.amount.value < 0 }
        guard !monthTxs.isEmpty else { return [] }

        let unassigned = monthTxs.filter { $0.hustleId == nil }
        let unassignedTotal = unassigned.reduce(Decimal(0)) { $0 + abs($1.amount.value) }
        let monthTotal = monthTxs.reduce(Decimal(0)) { $0 + abs($1.amount.value) }
        guard monthTotal > 0 else { return [] }

        let share = unassignedTotal / monthTotal
        guard share >= 0.15, unassigned.count >= 2 else { return [] }

        let pct = Int(NSDecimalNumber(decimal: share * 100).doubleValue)
        return [
            FinancialInsight(
                title: BuxLocalizedString.string("Unassigned workspace spend", locale: locale),
                value: BuxLocalizedString.format("%lld%% untagged", locale: locale, pct),
                description: BuxLocalizedString.format(
                    "%lld expenses this month have no workspace.",
                    locale: locale,
                    unassigned.count
                ),
                fullExplanation: BuxLocalizedString.format(
                    "%@ of this month's spending isn't tied to a workspace. Tag expenses to see per-gig profit and tax-ready splits.",
                    locale: locale,
                    InsightMoneyFormat.format(unassignedTotal)
                ),
                severity: share >= 0.35 ? .medium : .low,
                category: .pattern,
                systemIcon: "briefcase.circle",
                accentColorName: "purple",
                suggestedActions: [
                    BuxLocalizedString.string("Assign a workspace when logging", locale: locale),
                    BuxLocalizedString.string("Open Workspaces in Studio settings", locale: locale),
                ],
                impactMonthly: unassignedTotal,
                impactYearly: unassignedTotal * 12,
                dataBehind: BuxLocalizedString.string(
                    "Expenses with hustleId nil in the active month.",
                    locale: locale
                )
            )
        ]
    }
}

enum CashDigitalInsightsEngine {
    static func generateInsights(transactions: [Transaction], locale: Locale) -> [FinancialInsight] {
        guard SettingsStore.shared.studioEnabled,
              SettingsStore.shared.dualCashDrawerEnabled else { return [] }

        let monthStart = Calendar.current.dateInterval(of: .month, for: Date())?.start ?? Date()
        let monthTxs = transactions.filter { $0.date >= monthStart && $0.amount.value < 0 }
        guard monthTxs.count >= 3 else { return [] }

        var cashTotal = Decimal(0)
        var digitalTotal = Decimal(0)
        for tx in monthTxs {
            let amount = abs(tx.amount.value)
            if tx.paymentMethod?.hasPrefix("Cash (") == true {
                cashTotal += amount
            } else {
                digitalTotal += amount
            }
        }
        let total = cashTotal + digitalTotal
        guard total > 0 else { return [] }

        let cashShare = cashTotal / total
        let pct = Int(NSDecimalNumber(decimal: cashShare * 100).doubleValue)
        let localBal = Decimal(SettingsStore.shared.cashLocalBalanceValue)
        let secondaryBal = Decimal(SettingsStore.shared.cashSecondaryBalanceValue)

        return [
            FinancialInsight(
                title: BuxLocalizedString.string("Cash vs digital split", locale: locale),
                value: BuxLocalizedString.format("%lld%% cash", locale: locale, pct),
                description: BuxLocalizedString.format(
                    "Drawer: %1$@ %2$@ · %3$@ %4$@",
                    locale: locale,
                    SettingsStore.shared.primaryLocalCurrency,
                    InsightMoneyFormat.format(localBal),
                    SettingsStore.shared.secondaryTradingCurrency,
                    InsightMoneyFormat.format(secondaryBal)
                ),
                fullExplanation: BuxLocalizedString.format(
                    "About %@ went through physical cash this month vs %@ digital. Reconcile your drawer if the split feels off.",
                    locale: locale,
                    InsightMoneyFormat.format(cashTotal),
                    InsightMoneyFormat.format(digitalTotal)
                ),
                severity: cashShare < 0.05 && (localBal + secondaryBal) > 100 ? .medium : .low,
                category: .pattern,
                systemIcon: "banknote.fill",
                accentColorName: "green",
                suggestedActions: [
                    BuxLocalizedString.string("Log cash expenses from Add Expense", locale: locale),
                    BuxLocalizedString.string("Update drawer balances in Studio", locale: locale),
                ],
                impactMonthly: cashTotal,
                impactYearly: cashTotal * 12,
                dataBehind: BuxLocalizedString.string(
                    "Payment method tags starting with Cash (.",
                    locale: locale
                )
            )
        ]
    }
}

enum ScopeCreepInsightsEngine {
    static func generateInsights(projects: [StudioProject], locale: Locale) -> [FinancialInsight] {
        guard SettingsStore.shared.studioEnabled,
              SettingsStore.shared.studioMode == .pro,
              SettingsStore.shared.antiScopeCreepEnabled else { return [] }

        let scoped = HustleWorkspaceFilter.filter(projects) { $0.hustleId }
        var alerts: [FinancialInsight] = []

        for project in scoped {
            let budgetHours = project.budgetedHours
            guard budgetHours > 0 else { continue }
            let tracked = project.timeEntries.reduce(0.0) { $0 + $1.duration / 3600.0 }
            let usedRatio = tracked / budgetHours
            guard usedRatio >= 0.9 else { continue }

            let remaining = max(0, budgetHours - tracked)
            let description = remaining <= 0
                ? BuxLocalizedString.format(
                    "Over budget by %@h",
                    locale: locale,
                    String(format: "%.1f", tracked - budgetHours)
                )
                : BuxLocalizedString.format(
                    "%@h left in scope",
                    locale: locale,
                    String(format: "%.1f", remaining)
                )
            alerts.append(
                FinancialInsight(
                    title: BuxLocalizedString.string("Scope budget tight", locale: locale),
                    value: project.name,
                    description: description,
                    fullExplanation: BuxLocalizedString.format(
                        "Project \"%@\" has used %@ of %@ budgeted hours. Watch for scope creep before taking extra revisions.",
                        locale: locale,
                        project.name,
                        String(format: "%.1f", tracked),
                        String(format: "%.1f", budgetHours)
                    ),
                    severity: usedRatio >= 1.0 ? .high : .medium,
                    category: .pattern,
                    systemIcon: "scope",
                    accentColorName: "red",
                    suggestedActions: [
                        BuxLocalizedString.string("Review project scope in Studio", locale: locale),
                        BuxLocalizedString.string("Send a change-order note to client", locale: locale),
                    ],
                    dataBehind: BuxLocalizedString.string(
                        "StudioProject budgetedHours vs timeEntries.",
                        locale: locale
                    )
                )
            )
        }
        return Array(alerts.prefix(3))
    }
}
