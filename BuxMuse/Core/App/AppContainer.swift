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
    public let simpleStudioStore: SimpleStudioStore
    public let simpleStudioBrain: SimpleStudioBrain
    public let appDataManager: AppDataManager

    init() {
        persistence = PersistenceController.shared
        studioStore = StudioStore.shared
        simpleStudioStore = SimpleStudioStore.shared
        themeManager = ThemeManager()
        appSettingsManager = AppSettingsManager()
        navigationCoordinator = NavigationCoordinator()

        let settingsStore = SettingsStore.shared
        settingsStore.applyBrandThemesAppearance(to: themeManager)
        StudioTimerController.shared.attach(studioStore: studioStore, simpleStore: simpleStudioStore)
        StudioTimerDisplayMonitor.shared.start()
        StudioTimerController.shared.refreshLiveActivity()
        studioBrain = StudioBrain(
            store: studioStore,
            settings: settingsStore,
            appSettings: appSettingsManager
        )
        simpleStudioBrain = SimpleStudioBrain(
            store: simpleStudioStore,
            settings: settingsStore,
            studioStore: studioStore,
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
            goalsViewModel: goalsViewModel,
            appSettingsManager: appSettingsManager,
            studioStore: studioStore
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
        LocalBackupCoordinator.shared.reschedule(
            persistence: persistence,
            studioStore: studioStore,
            simpleStudioStore: simpleStudioStore
        )
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
                self.goalsEngine.invalidateLocalizedCaches(andRecalculate: self.financialBridge.engine)
                self.goalsViewModel.refreshSelectedDetailIfNeeded()
                self.insightsViewModel.recalculate()
                self.studioBrain.refreshAll()
                self.brain.scheduleSnapshotRefresh()
                if let engine18 = self.financialBridge.engine as? LocalFinancialIntelligenceEngine18 {
                    engine18.refreshSubscriptionAnalysis()
                } else if #available(iOS 26, *), let engine26 = self.financialBridge.engine as? LocalFinancialIntelligenceEngine {
                    engine26.refreshSubscriptionAnalysis()
                }
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
                self?.insightsViewModel.recalculate()
            }
            .store(in: &cancellables)

        SettingsStore.shared.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.brain.refreshExpenses()
                self.scheduleEngagementRefresh()
                LocalBackupCoordinator.shared.reschedule(
                    persistence: self.persistence,
                    studioStore: self.studioStore,
                    simpleStudioStore: self.simpleStudioStore
                )
            }
            .store(in: &cancellables)

        appSettingsManager.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.brain.scheduleSnapshotRefresh()
                self?.insightsViewModel.recalculate()
            }
            .store(in: &cancellables)
    }

    private func migrateLegacyFreelanceLocale() {
        let migrationKey = "studio_locale_migrated_v1"
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }
        // Factory Studio defaults are US/USD — must not override device region on first boot.
        guard studioStore.didLoadPersistedSnapshot else {
            UserDefaults.standard.set(true, forKey: migrationKey)
            return
        }

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

// MARK: - Local backup scheduler

@MainActor
final class LocalBackupCoordinator {
    static let shared = LocalBackupCoordinator()

    private var pendingWork: DispatchWorkItem?

    private init() {}

    func reschedule(
        persistence: PersistenceController,
        studioStore: StudioStore,
        simpleStudioStore: SimpleStudioStore
    ) {
        pendingWork?.cancel()
        let settings = SettingsStore.shared
        guard settings.allowLocalBackups else { return }
        let interval = settings.autoBackupFrequency.backupInterval
        guard interval > 0 else { return }

        let work = DispatchWorkItem { [weak self] in
            Self.writeBackup(
                persistence: persistence,
                studioStore: studioStore,
                simpleStudioStore: simpleStudioStore,
                settings: settings
            )
            self?.reschedule(
                persistence: persistence,
                studioStore: studioStore,
                simpleStudioStore: simpleStudioStore
            )
        }
        pendingWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + interval, execute: work)
    }

    static func writeBackup(
        persistence: PersistenceController,
        studioStore: StudioStore,
        simpleStudioStore: SimpleStudioStore,
        settings: SettingsStore
    ) {
        let expenses = (try? persistence.fetchAllExpenseEntities()) ?? []
        let goals = (try? persistence.fetchAllGoalEntities()) ?? []

        var payload: [String: Any] = [
            "buxmuse_app_version": "1.0.0",
            "export_timestamp": Date().timeIntervalSince1970,
            "expenses_count": expenses.count,
            "goals_count": goals.count
        ]

        if settings.includeAnalyticsInExports {
            payload["performance_metadata"] = [
                "platform": "iOS",
                "backup_kind": "scheduled_local",
                "studio_mode": settings.studioMode.rawValue
            ]
        }

        if settings.includeStudioDataInExports {
            if let data = try? JSONEncoder().encode(studioStore.currentSnapshot()),
               let json = try? JSONSerialization.jsonObject(with: data) {
                payload["freelance"] = json
            }
            if let data = try? JSONEncoder().encode(simpleStudioStore.snapshot),
               let json = try? JSONSerialization.jsonObject(with: data) {
                payload["simple_studio"] = json
            }
        }

        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: .prettyPrinted) else { return }

        let fm = FileManager.default
        let dir = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("BuxMuseBackups", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let url = dir.appendingPathComponent("buxmuse_backup_\(stamp).json")
        try? data.write(to: url, options: [.atomic])
        settings.lastExportDate = Date()
        settings.save()
    }
}

