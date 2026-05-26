//
//  AppContainer.swift
//  BuxMuse
//
//  Single composition root for Brain, persistence, theme, and coordinators.
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class AppContainer: ObservableObject {
    private var cancellables = Set<AnyCancellable>()
    public let persistence: PersistenceController
    public let themeManager: ThemeManager
    public let appSettingsManager: AppSettingsManager
    public let navigationCoordinator: NavigationCoordinator
    public let brain: BuxMuseBrain
    public let financialBridge: FinancialEngineBridge
    public let goalsEngine: GoalsEngine
    public let goalsViewModel: GoalsViewModel
    public let goalsSheetCoordinator: GoalsSheetCoordinator
    public let insightsEngine: InsightsEngine
    public let insightsViewModel: InsightsViewModel
    public let freelanceStore: FreelanceStore

    init() {
        persistence = PersistenceController.shared
        freelanceStore = FreelanceStore.shared
        themeManager = ThemeManager()
        appSettingsManager = AppSettingsManager()
        navigationCoordinator = NavigationCoordinator()

        let financialEngine: FinancialIntelligenceEngine
        if #available(iOS 26, *) {
            financialEngine = LocalFinancialIntelligenceEngine()
        } else {
            financialEngine = LocalFinancialIntelligenceEngine18()
        }

        financialBridge = FinancialEngineBridge(engine: financialEngine)
        goalsEngine = GoalsEngine()
        insightsEngine = InsightsEngine()
        goalsViewModel = GoalsViewModel(goalsEngine: goalsEngine, financialEngine: financialBridge.engine)
        insightsViewModel = InsightsViewModel(
            insightsEngine: insightsEngine,
            financialEngine: financialBridge.engine,
            goalsViewModel: goalsViewModel
        )
        goalsSheetCoordinator = GoalsSheetCoordinator()

        brain = BuxMuseBrain(
            persistence: persistence,
            financialBridge: financialBridge,
            goalsEngine: goalsEngine,
            insightsEngine: insightsEngine
        )

        brain.hydrateFromPersistence(
            appSettings: appSettingsManager,
            themeManager: themeManager,
            navigation: navigationCoordinator
        )

        wirePersistenceSideEffects()
    }

    private func wirePersistenceSideEffects() {
        navigationCoordinator.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.brain.persistPreferences(
                    navigation: self.navigationCoordinator,
                    appSettings: self.appSettingsManager
                )
            }
            .store(in: &cancellables)

        themeManager.onThemeChanged = { [weak self] theme in
            self?.brain.persistTheme(theme)
        }

        insightsEngine.$insights
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] insights in
                self?.brain.persistInsightMetadata(insights)
            }
            .store(in: &cancellables)

        appSettingsManager.$selectedCurrency
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.brain.persistPreferences(
                    navigation: self.navigationCoordinator,
                    appSettings: self.appSettingsManager
                )
            }
            .store(in: &cancellables)

        SettingsStore.shared.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.brain.refreshExpenses()
            }
            .store(in: &cancellables)
    }

}
