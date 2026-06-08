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
    private var expenseRefreshWork: DispatchWorkItem?
    private var studioInsightsWork: DispatchWorkItem?
    private var engagementRefreshWork: DispatchWorkItem?
    private var engagementRefreshTask: Task<Void, Never>?
    private static let expenseRefreshCoalesceInterval: TimeInterval = 0.35
    private static let studioInsightsCoalesceInterval: TimeInterval = 0.05
    private static let engagementRefreshCoalesceInterval: TimeInterval = 0.25
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
        wireWorkspaceNexusLifecycle()
        migrateLegacyFreelanceLocale()
        studioBrain.refreshAll()
        scheduleEngagementRefresh()
        scheduleTaxCatalogRefresh()
        LocalBackupCoordinator.shared.reschedule(
            persistence: persistence,
            studioStore: studioStore,
            simpleStudioStore: simpleStudioStore
        )
        Task {
            await BackupNotificationScheduler.reschedule(frequency: settingsStore.autoBackupFrequency)
        }

        themeManager.updateThemeForActiveWorkspace()
    }

    private func wireWorkspaceNexusLifecycle() {
        HustleManager.shared.$selectedHustleId
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.themeManager.updateThemeForActiveWorkspace()
                self?.brain.scheduleSnapshotRefresh()
            }
            .store(in: &cancellables)

        SettingsStore.shared.$sideHustleMatrixEnabled
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.themeManager.updateThemeForActiveWorkspace()
                self?.brain.scheduleSnapshotRefresh()
            }
            .store(in: &cancellables)

        HustleManager.shared.$hustles
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.themeManager.updateThemeForActiveWorkspace()
                self?.brain.scheduleSnapshotRefresh()
            }
            .store(in: &cancellables)
    }

    func scheduleEngagementRefresh() {
        engagementRefreshWork?.cancel()
        engagementRefreshTask?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.engagementRefreshTask = Task { @MainActor in
                await self.brain.refreshEngagement(
                    countryCode: self.appSettingsManager.selectedCountry.id,
                    settings: SettingsStore.shared,
                    appSettings: self.appSettingsManager,
                    studioAlerts: self.studioBrain.hubDisplay.alerts,
                    studioInvoices: self.studioStore.invoices,
                    taxDeadlineDays: self.studioBrain.hubDisplay.taxSummary.taxDeadlineDays
                )
            }
        }
        engagementRefreshWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.engagementRefreshCoalesceInterval, execute: work)
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

    private func scheduleDebouncedExpenseRefresh() {
        expenseRefreshWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.brain.refreshExpenses()
        }
        expenseRefreshWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.expenseRefreshCoalesceInterval, execute: work)
    }

    private func rescheduleLocalBackup() {
        LocalBackupCoordinator.shared.reschedule(
            persistence: persistence,
            studioStore: studioStore,
            simpleStudioStore: simpleStudioStore
        )
    }

    private func scheduleStudioInsightsRefresh() {
        studioInsightsWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.insightsViewModel.recalculate()
        }
        studioInsightsWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.studioInsightsCoalesceInterval, execute: work)
    }

    private func wirePersistenceSideEffects() {
        Publishers.MergeMany(
            navigationCoordinator.$selectedTab.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            navigationCoordinator.$activeCategoryPill.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            navigationCoordinator.$isBalanceVisible.dropFirst().map { _ in () }.eraseToAnyPublisher()
        )
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
                self.brain.scheduleSnapshotRefresh()
                self.insightsViewModel.recalculate()
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

        Publishers.MergeMany(
            studioStore.$invoices.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            studioStore.$projects.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            studioStore.$clients.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            studioStore.$receipts.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            studioStore.$profile.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            studioStore.$taxProfile.dropFirst().map { _ in () }.eraseToAnyPublisher()
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] _ in
            self?.scheduleStudioInsightsRefresh()
        }
        .store(in: &cancellables)

        let settings = SettingsStore.shared
        wireSettingsExpenseRefreshTriggers(settings)
        wireSettingsBackupTriggers(settings)
        wireSettingsEngagementTriggers(settings)

        navigationCoordinator.$selectedTab
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] tab in
                guard tab == .expense else { return }
                self?.expenseRefreshWork?.cancel()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .buxMuseFinancialDataDidChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.scheduleEngagementRefresh()
            }
            .store(in: &cancellables)
    }

    private func wireSettingsExpenseRefreshTriggers(_ settings: SettingsStore) {
        Publishers.MergeMany(
            settings.$budgetingMode.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            settings.$defaultBudgetPeriod.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            settings.$showBudgetWarnings.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            settings.$autoAdjustBudgetsFromHistory.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            settings.$customBudgetProfiles.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            settings.$simpleBudgetLimit.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            settings.$simpleBudgetCycle.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            settings.$simpleBudgetPeriodAnchor.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            settings.$incomeFundingSource.dropFirst().map { _ in () }.eraseToAnyPublisher()
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] _ in
            self?.scheduleDebouncedExpenseRefresh()
        }
        .store(in: &cancellables)

        Publishers.MergeMany(
            settings.$customBudgetLimit.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            settings.$customBudgetPeriod.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            settings.$budgetApproachingThresholdPercent.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            settings.$paymentSourceTrackingEnabled.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            settings.$dualCashDrawerEnabled.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            settings.$primaryLocalCurrency.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            settings.$secondaryTradingCurrency.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            settings.$cashLocalBalanceValue.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            settings.$cashSecondaryBalanceValue.dropFirst().map { _ in () }.eraseToAnyPublisher()
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] _ in
            self?.scheduleDebouncedExpenseRefresh()
        }
        .store(in: &cancellables)
    }

    private func wireSettingsBackupTriggers(_ settings: SettingsStore) {
        Publishers.MergeMany(
            settings.$allowLocalBackups.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            settings.$autoBackupFrequency.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            settings.$customBackupIntervalDays.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            settings.$includeStudioDataInExports.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            settings.$includeAnalyticsInExports.dropFirst().map { _ in () }.eraseToAnyPublisher()
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] _ in
            self?.rescheduleLocalBackup()
        }
        .store(in: &cancellables)
    }

    private func wireSettingsEngagementTriggers(_ settings: SettingsStore) {
        Publishers.MergeMany(
            settings.$notificationsEnabled.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            settings.$budgetAlertsEnabled.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            settings.$billRemindersEnabled.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            settings.$studioInvoiceRemindersEnabled.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            settings.$taxDeadlineRemindersEnabled.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            settings.$dailySummaryEnabled.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            settings.$studioEnabled.dropFirst().map { _ in () }.eraseToAnyPublisher()
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] _ in
            self?.scheduleEngagementRefresh()
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
        let interval: TimeInterval
        if settings.autoBackupFrequency == .custom {
            interval = TimeInterval(settings.customBackupIntervalDays) * 86_400
        } else {
            interval = settings.autoBackupFrequency.backupInterval
        }
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

