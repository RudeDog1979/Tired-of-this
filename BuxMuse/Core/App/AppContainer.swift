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
    public let studioStore: StudioStore
    public let studioBrain: StudioBrain
    public let appDataManager: AppDataManager

    init() {
        persistence = PersistenceController.shared
        studioStore = StudioStore.shared
        themeManager = ThemeManager()
        appSettingsManager = AppSettingsManager()
        navigationCoordinator = NavigationCoordinator()

        let settingsStore = SettingsStore.shared
        settingsStore.applyBrandThemesAppearance(to: themeManager)
        StudioTimerController.shared.attach(store: studioStore)
        StudioTimerDisplayMonitor.shared.start()
        StudioTimerController.shared.refreshLiveActivity()
        studioBrain = StudioBrain(
            store: studioStore,
            settings: settingsStore,
            appSettings: appSettingsManager
        )
        appDataManager = AppDataManager(
            studioStore: studioStore,
            taxManager: TaxManager.shared,
            appSettings: appSettingsManager
        )

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
        migrateLegacyFreelanceLocale()
        studioBrain.refreshAll()
        scheduleEngagementRefresh()
        scheduleTaxCatalogRefresh()
    }

    func scheduleEngagementRefresh() {
        Task { @MainActor in
            await brain.refreshEngagement(
                countryCode: appSettingsManager.selectedCountry.id,
                settings: SettingsStore.shared,
                appSettings: appSettingsManager,
                studioAlerts: studioBrain.hubDisplay.alerts,
                studioInvoices: studioStore.invoices,
                taxDeadlineDays: studioBrain.hubDisplay.taxSummary.taxDeadlineDays
            )
        }
    }

    func scheduleTaxCatalogRefresh(force: Bool = false) {
        Task { @MainActor in
            await TaxManager.shared.ensureCatalogLoaded(force: force)
        }
    }

    /// Checks whether today's 6am tip window has opened and fetches if needed.
    func scheduleTipsRefresh(force: Bool = false) {
        Task { @MainActor in
            await brain.refreshTips(
                countryCode: appSettingsManager.selectedCountry.id,
                force: force
            )
        }
    }

    private func wirePersistenceSideEffects() {
        brain.$dashboardSnapshot
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.scheduleEngagementRefresh()
            }
            .store(in: &cancellables)

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

        appSettingsManager.$selectedCountry
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.brain.persistPreferences(
                    navigation: self.navigationCoordinator,
                    appSettings: self.appSettingsManager
                )
                self.scheduleEngagementRefresh()
                self.scheduleTipsRefresh()
            }
            .store(in: &cancellables)

        studioBrain.$hubDisplay
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.scheduleEngagementRefresh()
            }
            .store(in: &cancellables)

        studioStore.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.scheduleEngagementRefresh()
            }
            .store(in: &cancellables)

        SettingsStore.shared.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.brain.refreshExpenses()
                self.scheduleEngagementRefresh()
            }
            .store(in: &cancellables)
    }

    private func migrateLegacyFreelanceLocale() {
        let migrationKey = "studio_locale_migrated_v1"
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }

        let legacyProfile = studioStore.profile
        if let country = CountryCatalog.country(for: legacyProfile.countryCode),
           country.id != appSettingsManager.selectedCountry.id {
            appSettingsManager.updateCountry(country, suggestCurrency: false)
        }
        if let currency = AppSettingsManager.availableCurrencies.first(where: { $0.id == legacyProfile.currencyCode }),
           currency.id != appSettingsManager.selectedCurrency.id {
            appSettingsManager.applyCurrency(currency, persist: true)
        }
        if legacyProfile.vatRegistered && !studioStore.taxProfile.vatRegistered {
            var taxProfile = studioStore.taxProfile
            taxProfile.vatRegistered = true
            studioStore.updateTaxProfile(taxProfile)
        }

        UserDefaults.standard.set(true, forKey: migrationKey)
    }

}
