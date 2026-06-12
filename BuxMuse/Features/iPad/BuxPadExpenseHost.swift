//
//  BuxPadExpenseHost.swift
//  BuxMuse — iPad Expenses: detail left, list right (native split).
//

import SwiftUI

struct BuxPadExpenseHost: View {
    @Environment(\.buxLayoutMode) private var layoutMode
    @EnvironmentObject private var container: AppContainer
    @EnvironmentObject private var padNavigationBrain: BuxPadNavigationBrain

    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        padSplitExpense
            .buxPadDebouncedBrainResize(columnVisibility: columnVisibility)
    }

    private var padSplitExpense: some View {
        ZStack {
            BuxLandingTintBackground()
                .ignoresSafeArea()

            NavigationSplitView(columnVisibility: $columnVisibility) {
                BuxPadExpenseDetailPane()
                    .buxPadSplitColumnEnvironment(container, padBrain: padNavigationBrain)
                    .buxPadSplitSidebarColumnWidth(layoutMode: layoutMode)
            } detail: {
                ExpenseTabView()
                    .buxPadSplitColumnEnvironment(container, padBrain: padNavigationBrain)
                    .environment(\.buxPadExpenseUsesSplitLayout, true)
                    .buxPadStudioDropDestination(destination: .invoices)
                    .buxPadStudioSplitDetailChrome()
            }
            .navigationSplitViewStyle(.balanced)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    BuxPadOpenExpenseWindowButton()
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .ignoresSafeArea(edges: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
