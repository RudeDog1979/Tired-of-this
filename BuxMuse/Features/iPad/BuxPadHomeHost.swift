//
//  BuxPadHomeHost.swift
//  BuxMuse — iPad Home tab host (readable column + metrics).
//

import SwiftUI

struct BuxPadHomeHost: View {
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @EnvironmentObject private var navigationCoordinator: NavigationCoordinator
    @EnvironmentObject private var brain: BuxMuseBrain
    @EnvironmentObject private var expenseTabStore: ExpenseTabStore

    var transactionNamespace: Namespace.ID

    @State private var didPrimeHome = false

    var body: some View {
        DashboardView(transactionNamespace: transactionNamespace)
            .environment(\.buxPadFlatDashboardChrome, true)
            .buxPadDashboardUIScreenMitigation()
            .buxPadPublishesSceneScale()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    BuxPadExternalDisplayMenu()
                }
            }
            .onAppear {
                primeHomeDashboardIfNeeded()
            }
            .onChange(of: navigationCoordinator.selectedTab) { _, tab in
                guard tab == .home else { return }
                primeHomeDashboardIfNeeded(force: true)
            }
    }

    private func primeHomeDashboardIfNeeded(force: Bool = false) {
        if !force && didPrimeHome { return }
        didPrimeHome = true

        if !navigationCoordinator.isScreenLoaded {
            navigationCoordinator.isScreenLoaded = true
        }
        expenseTabStore.reloadFromLedger(currency: appSettingsManager.selectedCurrency)
        brain.scheduleSnapshotRefresh()
    }
}
