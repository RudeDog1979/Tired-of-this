//
//  FeatureInsightsEngines.swift
//  BuxMuse
//
//  Workspace, cash/digital, and scope-creep insights for the intelligence layer.
//

import Foundation

enum WorkspaceInsightsEngine {
    static func generateInsights(transactions: [Transaction]) -> [FinancialInsight] {
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

        return [
            FinancialInsight(
                title: "Unassigned workspace spend",
                value: "\(Int(NSDecimalNumber(decimal: share * 100).doubleValue))% untagged",
                description: "\(unassigned.count) expenses this month have no workspace.",
                fullExplanation: "\(InsightMoneyFormat.format(unassignedTotal)) of this month's spending isn't tied to a workspace. Tag expenses to see per-gig profit and tax-ready splits.",
                severity: share >= 0.35 ? .medium : .low,
                category: .pattern,
                systemIcon: "briefcase.circle",
                accentColorName: "purple",
                suggestedActions: ["Assign a workspace when logging", "Open Workspaces in Studio settings"],
                impactMonthly: unassignedTotal,
                impactYearly: unassignedTotal * 12,
                dataBehind: "Expenses with hustleId nil in the active month."
            )
        ]
    }
}

enum CashDigitalInsightsEngine {
    static func generateInsights(transactions: [Transaction]) -> [FinancialInsight] {
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
        let localBal = Decimal(SettingsStore.shared.cashLocalBalanceValue)
        let secondaryBal = Decimal(SettingsStore.shared.cashSecondaryBalanceValue)

        return [
            FinancialInsight(
                title: "Cash vs digital split",
                value: "\(Int(NSDecimalNumber(decimal: cashShare * 100).doubleValue))% cash",
                description: "Drawer: \(SettingsStore.shared.primaryLocalCurrency) \(InsightMoneyFormat.format(localBal)) · \(SettingsStore.shared.secondaryTradingCurrency) \(InsightMoneyFormat.format(secondaryBal))",
                fullExplanation: "About \(InsightMoneyFormat.format(cashTotal)) went through physical cash this month vs \(InsightMoneyFormat.format(digitalTotal)) digital. Reconcile your drawer if the split feels off.",
                severity: cashShare < 0.05 && (localBal + secondaryBal) > 100 ? .medium : .low,
                category: .pattern,
                systemIcon: "banknote.fill",
                accentColorName: "green",
                suggestedActions: ["Log cash expenses from Add Expense", "Update drawer balances in Studio"],
                impactMonthly: cashTotal,
                impactYearly: cashTotal * 12,
                dataBehind: "Payment method tags starting with Cash (."
            )
        ]
    }
}

enum ScopeCreepInsightsEngine {
    static func generateInsights(projects: [StudioProject]) -> [FinancialInsight] {
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
            alerts.append(
                FinancialInsight(
                    title: "Scope budget tight",
                    value: project.name,
                    description: remaining <= 0
                        ? "Over budget by \(String(format: "%.1f", tracked - budgetHours))h"
                        : "\(String(format: "%.1f", remaining))h left in scope",
                    fullExplanation: "Project \"\(project.name)\" has used \(String(format: "%.1f", tracked)) of \(String(format: "%.1f", budgetHours)) budgeted hours. Watch for scope creep before taking extra revisions.",
                    severity: usedRatio >= 1.0 ? .high : .medium,
                    category: .pattern,
                    systemIcon: "scope",
                    accentColorName: "red",
                    suggestedActions: ["Review project scope in Studio", "Send a change-order note to client"],
                    dataBehind: "StudioProject budgetedHours vs timeEntries."
                )
            )
        }
        return Array(alerts.prefix(3))
    }
}
