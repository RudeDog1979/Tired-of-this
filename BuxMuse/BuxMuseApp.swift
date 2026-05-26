//
//  BuxMuseApp.swift
//  BuxMuse
//

import SwiftUI
import SwiftData

@main
struct BuxMuseApp: App {
    @StateObject private var container = AppContainer()

    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(container.persistence.container)
                .environmentObject(container)
                .environmentObject(container.brain)
                .environmentObject(container.persistence)
                .environmentObject(container.themeManager)
                .environmentObject(container.appSettingsManager)
                .environmentObject(container.navigationCoordinator)
                .environmentObject(container.financialBridge)
                .environmentObject(container.goalsEngine)
                .environmentObject(container.goalsViewModel)
                .environmentObject(container.goalsSheetCoordinator)
                .environmentObject(container.insightsEngine)
                .environmentObject(container.insightsViewModel)
                .task {
                    _ = await ExpenseRenewalReminderScheduler.requestAuthorizationIfNeeded()
                }
        }
    }
}
