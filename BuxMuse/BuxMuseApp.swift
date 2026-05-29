//
//  BuxMuseApp.swift
//  BuxMuse
//

import SwiftUI

@main
struct BuxMuseApp: App {
    @StateObject private var container = AppContainer()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(container)
                .environmentObject(SettingsStore.shared)
                .environmentObject(container.brain)
                .environmentObject(container.persistence)
                .environmentObject(container.themeManager)
                .environment(\.themeManager, container.themeManager)
                .environmentObject(container.appSettingsManager)
                .environmentObject(container.navigationCoordinator)
                .environmentObject(container.financialBridge)
                .environmentObject(container.goalsEngine)
                .environmentObject(container.goalsViewModel)
                .environmentObject(container.goalsSheetCoordinator)
                .environmentObject(container.insightsEngine)
                .environmentObject(container.insightsViewModel)
                .environmentObject(container.studioStore)
                .environmentObject(container.studioBrain)
                .environmentObject(container.appDataManager)
                .task {
                    _ = await ExpenseRenewalReminderScheduler.requestAuthorizationIfNeeded()
                    container.scheduleEngagementRefresh()
                    container.scheduleTipsRefresh()
                }
                .onOpenURL { url in
                    guard StudioTimerDeepLink.matches(url) else { return }
                    container.navigationCoordinator.openStudioLogTime()
                }
        }
    }
}
