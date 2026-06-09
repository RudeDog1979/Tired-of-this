//
//  BuxPadWindowEnvironment.swift
//  BuxMuse — Shared environment injection for auxiliary iPad windows.
//

import SwiftUI

struct BuxPadWindowEnvironment: ViewModifier {
    @ObservedObject var container: AppContainer
    let padBrain: BuxPadNavigationBrain

    func body(content: Content) -> some View {
        content.buxAppContainerEnvironment(container, padBrain: padBrain)
    }
}

extension View {
    /// Shared observable services for the main window, auxiliary windows, and split columns.
    func buxAppContainerEnvironment(_ container: AppContainer, padBrain: BuxPadNavigationBrain) -> some View {
        environmentObject(container)
            .environmentObject(SettingsStore.shared)
            .environmentObject(container.brain)
            .environmentObject(container.persistence)
            .environmentObject(container.themeManager)
            .environment(\.themeManager, container.themeManager)
            .environmentObject(container.appSettingsManager)
            .environmentObject(container.navigationCoordinator)
            .environmentObject(padBrain)
            .environmentObject(container.financialBridge)
            .environmentObject(container.goalsEngine)
            .environmentObject(container.goalsViewModel)
            .environmentObject(container.goalsSheetCoordinator)
            .environmentObject(container.insightsEngine)
            .environmentObject(container.insightsViewModel)
            .environmentObject(container.studioStore)
            .environmentObject(container.studioBrain)
            .environmentObject(container.simpleStudioStore)
            .environmentObject(container.simpleStudioBrain)
            .environmentObject(container.taxEnvelopeBrain)
            .environmentObject(container.appDataManager)
            .environmentObject(container.padSceneBrainRegistry)
            .buxInterfaceLocale()
    }

    /// `NavigationSplitView` columns do not inherit `environmentObject` reliably in auxiliary scenes.
    func buxPadSplitColumnEnvironment(_ container: AppContainer, padBrain: BuxPadNavigationBrain) -> some View {
        buxAppContainerEnvironment(container, padBrain: padBrain)
    }

    func buxPadWindowEnvironment(container: AppContainer, padBrain: BuxPadNavigationBrain) -> some View {
        modifier(BuxPadWindowEnvironment(container: container, padBrain: padBrain))
    }
}
