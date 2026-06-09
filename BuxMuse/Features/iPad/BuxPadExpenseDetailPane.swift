//
//  BuxPadExpenseDetailPane.swift
//  BuxMuse — Left column: Expenses title + expense detail (iPad regular split).
//

import SwiftUI

struct BuxPadExpenseDetailPane: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var padNavigationBrain: BuxPadNavigationBrain
    @EnvironmentObject private var brain: BuxMuseBrain
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    var body: some View {
        List {
            Section {
                expenseSidebarHeader
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 12, trailing: 0))
            }

            Section {
                expenseDetailContent
                    .fixedSize(horizontal: false, vertical: true)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 12, trailing: 0))
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .buxPadSidebarToggleTint(themeManager.contrastAccentColor(for: colorScheme))
        .dropDestination(for: String.self) { items, _ in
            guard let payload = items.first,
                  let expenseId = BuxPadExpenseDragPayload.decode(payload) else { return false }
            padNavigationBrain.selectExpense(expenseId)
            return true
        }
    }

    private var expenseSidebarHeader: some View {
        BuxRootTabHeader.rootScrollRow(
            style: .plain(titleKey: "Expenses", showCountrySubtitle: true)
        )
        .padding(.horizontal, BuxPadLayout.detailInsetCompact)
        .buxPadExpenseOpenInNewWindowContextMenu()
    }

    @ViewBuilder
    private var expenseDetailContent: some View {
        if let id = padNavigationBrain.selectedExpenseId,
           let record = brain.expenseRecords.first(where: { $0.id == id }) {
            ExpenseDetailView(
                record: record,
                brain: brain,
                settingsManager: appSettingsManager
            ) { }
            .environmentObject(themeManager)
            .environmentObject(appSettingsManager)
            .environmentObject(padNavigationBrain)
            .environment(\.buxPadExpenseDetailEmbedded, true)
            .environment(\.expensesEnhancedTint, true)
        } else {
            BuxPadDetailEmptyState(
                title: "Expense",
                systemImage: "wallet.pass.fill",
                message: "Select a transaction from the list."
            )
        }
    }
}
