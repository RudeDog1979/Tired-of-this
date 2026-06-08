//
//  BuxMuseBrain.swift
//  BuxMuse
//
//  Central orchestrator: persistence ↔ engines ↔ UI snapshots.
//

import Foundation
import Combine

@MainActor
public final class BuxMuseBrain: ObservableObject {
    @Published public private(set) var dashboardSnapshot: DashboardSnapshot = .empty
    @Published public private(set) var subscriptionHubSnapshot: SubscriptionHubSnapshot = .empty
    @Published public private(set) var expenseInteractionSnapshot: ExpenseInteractionDisplay = .empty
    /// Expenses tab list source — always loaded on the main actor (never via background `@Query`).
    @Published private(set) var expenseRecords: [ExpenseRecord] = []
    @Published private(set) var categoryRecords: [ExpenseCategoryRecord] = []
    @Published public private(set) var isHydrated: Bool = false
    @Published var expenseUndoOffer: ExpenseRecord?

    private var expenseUndoTask: Task<Void, Never>?

    @Published public var dailyTipDisplay: DailyTipDisplay = .empty
    @Published public var notificationInboxDisplay: NotificationInboxDisplay = .empty
    @Published public var tipNeedsAttention: Bool = false
    @Published public var tipPulseToken: Int = 0

    let persistence: PersistenceController
    let tipsEngine = BuxTipsEngine()
    let inboxEngine = BuxNotificationInboxEngine()
    var didPulseTipThisSession = false
    public let financialBridge: FinancialEngineBridge
    public let goalsEngine: GoalsEngine
    public let insightsEngine: InsightsEngine
    let merchantBrain: MerchantBrain

    private var saveWorkItem: DispatchWorkItem?
    private var snapshotWorkItem: DispatchWorkItem?
    private var cancellables = Set<AnyCancellable>()
    private var isRefreshingExpenses = false

    public var financialEngine: FinancialIntelligenceEngine { financialBridge.engine }

    public init(
        persistence: PersistenceController,
        financialBridge: FinancialEngineBridge,
        goalsEngine: GoalsEngine,
        insightsEngine: InsightsEngine
    ) {
        self.persistence = persistence
        self.financialBridge = financialBridge
        self.goalsEngine = goalsEngine
        self.insightsEngine = insightsEngine
        self.merchantBrain = MerchantBrain(
            persistence: persistence,
            financialEngine: financialBridge.engine
        )

        NotificationCenter.default.publisher(for: .buxMuseFinancialDataDidChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.scheduleSnapshotRefresh()
                // Expenses persist immediately via saveExpense/update/delete — never debounced here.
            }
            .store(in: &cancellables)

        goalsEngine.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.schedulePersistGoals()
                self?.scheduleSnapshotRefresh()
            }
            .store(in: &cancellables)
            
        HustleManager.shared.$selectedHustleId
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshForActiveWorkspaceChange()
            }
            .store(in: &cancellables)

        SettingsStore.shared.$sideHustleMatrixEnabled
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshExpenses()
                self?.scheduleSnapshotRefresh()
            }
            .store(in: &cancellables)

        SettingsStore.shared.$showUnassignedExpensesInWorkspace
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshExpenses()
                self?.scheduleSnapshotRefresh()
            }
            .store(in: &cancellables)
    }

    // MARK: - Hydration

    func hydrateFromPersistence(appSettings: AppSettingsManager, themeManager: ThemeManager, navigation: NavigationCoordinator) {
        do {
            try persistence.seedExpenseCatalogIfNeeded()
        } catch {
            print("Expense catalog seed failed: \(error)")
        }

        do {
            let transactions = try persistence.fetchAllExpenses()
            loadTransactionsIntoEngine(transactions)

            let goals = try persistence.fetchAllGoals()
            goalsEngine.replaceAllGoals(goals)

            let prefs = try persistence.loadPreferences()
            navigation.restore(
                tab: .home, // Force HOME tab as the landing page every time the app opens
                activeCategory: prefs.activeCategoryPill,
                isBalanceVisible: prefs.isBalanceVisible
            )
            // Fresh SwiftData prefs default to USD — keep AppSettings (device region) instead.
            if prefs.currencyCode == appSettings.selectedCurrency.id,
               let currency = AppSettingsManager.availableCurrencies.first(where: { $0.id == prefs.currencyCode }) {
                appSettings.applyCurrency(currency, persist: false)
            } else if prefs.currencyCode != "USD",
                      let currency = AppSettingsManager.availableCurrencies.first(where: { $0.id == prefs.currencyCode }) {
                appSettings.applyCurrency(currency, persist: false)
            } else {
                try? persistence.savePreferences(
                    selectedTab: .home,
                    currencyCode: appSettings.selectedCurrency.id,
                    isBalanceVisible: prefs.isBalanceVisible,
                    activeCategoryPill: prefs.activeCategoryPill
                )
            }

            SettingsStore.shared.applyBrandThemesAppearance(to: themeManager)

            _ = try? persistence.fetchInsightMetadata()
        } catch {
            print("Brain hydration error: \(error)")
            loadTransactionsIntoEngine([])
        }

        reloadExpenseRecordsFromStore()
        categoryRecords = (try? fetchAllCategoryRecords()) ?? []
        refreshSnapshotsImmediately()
        if !expenseRecords.isEmpty {
            updateExpenseInteractionSnapshot(records: expenseRecords, currency: appSettings.selectedCurrency)
        }
        isHydrated = true
    }

    private func loadTransactionsIntoEngine(_ transactions: [Transaction]) {
        let deduped = Self.deduplicatedTransactions(transactions)
        if let engine18 = financialBridge.engine as? LocalFinancialIntelligenceEngine18 {
            engine18.loadTransactions(deduped)
        }
        if #available(iOS 26, *) {
            if let engine26 = financialBridge.engine as? LocalFinancialIntelligenceEngine {
                engine26.loadTransactions(deduped)
            }
        }
    }

    /// Last row wins when the store contains duplicate expense IDs (avoids launch trap from `uniqueKeysWithValues`).
    private static func deduplicatedTransactions(_ transactions: [Transaction]) -> [Transaction] {
        Dictionary(
            transactions.map { ($0.id, $0) },
            uniquingKeysWith: { _, newer in newer }
        )
        .values
        .sorted { $0.date > $1.date }
    }

    private static func recordsByID(_ records: [ExpenseRecord]) -> [UUID: ExpenseRecord] {
        Dictionary(
            records.map { ($0.id, $0) },
            uniquingKeysWith: { _, newer in newer }
        )
    }

    // MARK: - Expenses (immediate SwiftData — no debounce)

    /// Reload in-memory engine + snapshots from SwiftData only. Does not write to disk.
    public func refreshExpenses() {
        isRefreshingExpenses = true
        defer { isRefreshingExpenses = false }

        do {
            let transactions = try persistence.fetchAllExpenses()
            loadTransactionsIntoEngine(transactions)
            reloadExpenseRecordsFromStore()
            refreshSnapshotsImmediately()
            financialBridge.objectWillChange.send()

            Task { @MainActor in
                expenseInteractionSnapshot = await generateExpenseInteractionDisplay()
            }
        } catch {
            print("refreshExpenses failed: \(error)")
        }
    }

    /// Workspace pill changes only re-filter in-memory data — engine already scopes via `HustleWorkspaceFilter`.
    public func refreshForActiveWorkspaceChange() {
        reloadExpenseRecordsFromStore()
        refreshSnapshotsImmediately()
        financialBridge.objectWillChange.send()
        let globalCurrency = AppSettingsManager.currencySetting(for: AppSettingsManager.preferredCurrencyCode)
        updateExpenseInteractionSnapshot(
            records: expenseRecords,
            currency: WorkspaceCurrencyContext.activeDisplayCurrency(global: globalCurrency)
        )
    }

    private func reloadExpenseRecordsFromStore() {
        let all = (try? persistence.fetchAllExpenseRecords()) ?? []
        expenseRecords = HustleWorkspaceFilter.filter(all) { $0.hustleId }
    }

    @discardableResult
    public func saveExpense(_ transaction: Transaction) throws -> Transaction {
        _ = try saveExpenseRecord(ExpenseRecord.from(
            transaction,
            categoryId: try persistence.categoryId(for: transaction.category),
            merchantId: nil
        ))
        return transaction
    }

    @discardableResult
    public func updateExpense(_ transaction: Transaction) throws -> Transaction {
        try saveExpense(transaction)
    }

    public func deleteExpense(id: UUID) throws {
        ExpenseRenewalReminderScheduler.cancel(for: id)
        try persistence.deleteExpenseRecord(id: id)
        refreshExpenses()
    }

    // MARK: - Expense records (full SwiftData model)

    func fetchAllExpenseRecords() throws -> [ExpenseRecord] {
        try persistence.fetchAllExpenseRecords()
    }

    func fetchExpenseRecord(id: UUID) throws -> ExpenseRecord? {
        try persistence.fetchExpenseRecord(id: id)
    }

    @discardableResult
    func saveExpenseRecord(_ record: ExpenseRecord, merchantSelection: MerchantSelection? = nil) throws -> ExpenseRecord {
        var working = record
        let userDeclaredSubscription = working.isSubscriptionLike || working.isTrial
        let userMarkedRecurring = working.isRecurring && (working.recurrenceConfidence ?? 0) >= 0.85
        let all = (try? persistence.fetchAllExpenseRecords()) ?? []
        let normalizedMerchant = MerchantLogoEngine.normalizeMerchantName(working.merchantName)
        if !userDeclaredSubscription,
           SettingsStore.shared.isSubscriptionCancelled(normalizedMerchant: normalizedMerchant) {
            working.isSubscriptionLike = false
            working.isTrial = false
            working.nextExpectedDate = nil
            working.subscriptionStartDate = nil
            working.trialEndDate = nil
            working.renewalReminderDays = nil
        }
        let subs = financialEngine.activeSubscriptions()
        let categoryRecords = (try? fetchAllCategoryRecords()) ?? []
        let categoriesById = Dictionary(uniqueKeysWithValues: categoryRecords.map { ($0.id, $0) })
        let analysis = ExpenseIntelligenceEngine.analyze(
            record: working,
            allRecords: all,
            activeSubscriptions: subs,
            categoriesById: categoriesById,
            locale: BuxInterfaceLocale.currentInterfaceLocale
        )
        if !userMarkedRecurring {
            working.isRecurring = analysis.isRecurring
            working.recurrenceType = analysis.recurrenceType
            working.recurrenceConfidence = analysis.recurrenceConfidence
        }
        if !userDeclaredSubscription {
            if SettingsStore.shared.isSubscriptionCancelled(normalizedMerchant: normalizedMerchant) {
                working.isSubscriptionLike = false
                working.isTrial = false
            } else {
                working.isSubscriptionLike = analysis.isSubscriptionLike
            }
        }
        if working.nextExpectedDate == nil {
            working.nextExpectedDate = analysis.nextExpectedDate
        }
        if userDeclaredSubscription, working.isSubscriptionLike {
            working.categoryRaw = TransactionCategory.subscriptions.rawValue
            working.categoryId = try? persistence.categoryId(for: .subscriptions)
        }
        working.heatZoneBucket = analysis.heatZoneBucket

        let isNewRecord = (try? persistence.fetchExpenseRecord(id: working.id)) == nil
        WorkspaceAutoRouter.applyCreateOnlyRouting(to: &working, isNewRecord: isNewRecord)

        let saved = try persistence.upsertExpenseRecord(working, merchantSelection: merchantSelection)
        refreshExpenses()
        Task { @MainActor in
            await ExpenseRenewalReminderScheduler.schedule(for: saved)
        }
        return saved
    }

    @discardableResult
    func saveBridgeRecords(_ records: [ExpenseRecord], merchantSelection: MerchantSelection? = nil) throws -> [ExpenseRecord] {
        var saved: [ExpenseRecord] = []
        for (index, record) in records.enumerated() {
            let selection = index == 0 ? merchantSelection : nil
            saved.append(try saveExpenseRecord(record, merchantSelection: selection))
        }
        return saved
    }

    func updateExpenseNotes(id: UUID, notes: String?) throws {
        try persistence.updateExpenseNotes(id: id, notes: notes)
        refreshExpenses()
    }

    public func changeExpenseCategory(id: UUID, category: TransactionCategory, categoryId: UUID? = nil) throws {
        try persistence.updateExpenseCategory(id: id, category: category, categoryId: categoryId)
        refreshExpenses()
    }

    public func cancelSubscription(merchantName: String) throws {
        let normalized = MerchantLogoEngine.normalizeMerchantName(merchantName)
        SettingsStore.shared.registerCancelledSubscription(normalizedMerchant: normalized)

        let records = (try? persistence.fetchAllExpenseRecords()) ?? []
        for var record in records where MerchantLogoEngine.normalizeMerchantName(record.merchantName) == normalized {
            record.isSubscriptionLike = false
            record.isTrial = false
            record.nextExpectedDate = nil
            record.subscriptionStartDate = nil
            record.trialEndDate = nil
            record.renewalReminderDays = nil
            ExpenseRenewalReminderScheduler.cancel(for: record.id)
            _ = try persistence.upsertExpenseRecord(record)
        }
        refreshExpenses()
    }

    func convertExpenseToSubscription(id: UUID) throws {
        guard var record = try persistence.fetchExpenseRecord(id: id) else { return }
        let normalized = MerchantLogoEngine.normalizeMerchantName(record.merchantName)
        SettingsStore.shared.clearCancelledSubscription(normalizedMerchant: normalized)
        record.categoryRaw = TransactionCategory.subscriptions.rawValue
        record.isSubscriptionLike = true
        record.categoryId = try persistence.categoryId(for: .subscriptions)
        if record.subscriptionStartDate == nil {
            record.subscriptionStartDate = record.date
        }
        if record.nextExpectedDate == nil {
            record.nextExpectedDate = Calendar.current.date(byAdding: .month, value: 1, to: record.subscriptionStartDate ?? record.date)
        }
        _ = try saveExpenseRecord(record)
    }

    func unmarkExpenseRecurring(id: UUID) throws {
        guard var record = try persistence.fetchExpenseRecord(id: id) else { return }
        record.isRecurring = false
        record.recurrenceType = nil
        record.recurrenceConfidence = nil
        _ = try saveExpenseRecord(record)
    }

    func clearExpenseSubscription(
        id: UUID,
        restoreCategory: TransactionCategory,
        categoryId: UUID?
    ) throws {
        guard var record = try persistence.fetchExpenseRecord(id: id) else { return }
        let normalized = MerchantLogoEngine.normalizeMerchantName(record.merchantName)
        SettingsStore.shared.registerCancelledSubscription(normalizedMerchant: normalized)
        record.isSubscriptionLike = false
        record.isTrial = false
        record.subscriptionStartDate = nil
        record.trialEndDate = nil
        record.nextExpectedDate = nil
        record.renewalReminderDays = nil
        record.categoryRaw = restoreCategory.rawValue
        record.categoryId = categoryId ?? (try? persistence.categoryId(for: restoreCategory))
        _ = try saveExpenseRecord(record)
    }

    func offerExpenseUndo(_ record: ExpenseRecord) {
        expenseUndoTask?.cancel()
        expenseUndoOffer = record
        expenseUndoTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            expenseUndoOffer = nil
        }
    }

    func dismissExpenseUndo() {
        expenseUndoTask?.cancel()
        expenseUndoTask = nil
        expenseUndoOffer = nil
    }

    func performExpenseUndo() throws {
        guard let record = expenseUndoOffer else { return }
        let normalized = MerchantLogoEngine.normalizeMerchantName(record.merchantName)
        if record.isSubscriptionLike || record.isTrial {
            SettingsStore.shared.clearCancelledSubscription(normalizedMerchant: normalized)
        }
        try restoreExpenseRecord(record)
        dismissExpenseUndo()
    }

    func restoreExpenseRecord(_ record: ExpenseRecord) throws {
        _ = try saveExpenseRecord(record)
    }

    func markExpenseRecurring(id: UUID, type: String) throws {
        guard var record = try persistence.fetchExpenseRecord(id: id) else { return }
        record.isRecurring = true
        record.recurrenceType = type
        record.recurrenceConfidence = max(record.recurrenceConfidence ?? 0, 0.85)
        _ = try saveExpenseRecord(record)
    }

    func expenseIntelligenceDisplay(for id: UUID, locale: Locale? = nil) -> ExpenseIntelligenceDisplay {
        let resolvedLocale = locale ?? BuxInterfaceLocale.currentInterfaceLocale
        guard let record = try? persistence.fetchExpenseRecord(id: id) else { return .empty }
        let all = (try? persistence.fetchAllExpenseRecords()) ?? []
        let subs = financialEngine.activeSubscriptions()
        let categoryRecords = (try? fetchAllCategoryRecords()) ?? []
        let categoriesById = Dictionary(uniqueKeysWithValues: categoryRecords.map { ($0.id, $0) })
        return ExpenseIntelligenceEngine.analyze(
            record: record,
            allRecords: all,
            activeSubscriptions: subs,
            categoriesById: categoriesById,
            locale: resolvedLocale
        ).display
    }

    func categoryId(for category: TransactionCategory) throws -> UUID {
        try persistence.categoryId(for: category)
    }

    func fetchAllCategoryRecords() throws -> [ExpenseCategoryRecord] {
        try persistence.fetchAllCategoryRecords()
    }

    func createCategory(name: String, icon: String, color: String) throws -> ExpenseCategoryRecord {
        let created = try persistence.createCategory(name: name, icon: icon, color: color)
        categoryRecords = (try? fetchAllCategoryRecords()) ?? []
        return created
    }

    func updateCategory(_ record: ExpenseCategoryRecord) throws {
        try persistence.updateCategory(record)
        categoryRecords = (try? fetchAllCategoryRecords()) ?? []
    }

    func deleteCategory(id: UUID) throws {
        try persistence.deleteCategory(id: id)
        categoryRecords = (try? fetchAllCategoryRecords()) ?? []
    }

    func mergeCategories(sourceId: UUID, into targetId: UUID) throws {
        try persistence.mergeCategories(sourceId: sourceId, into: targetId)
        categoryRecords = (try? fetchAllCategoryRecords()) ?? []
        refreshExpenses()
    }

    func fetchAllMerchantRecords() throws -> [ExpenseMerchantRecord] {
        try persistence.fetchAllMerchantRecords()
    }

    func fetchMerchantRecord(id: UUID) throws -> ExpenseMerchantRecord? {
        try persistence.fetchMerchantRecord(id: id)
    }

    /// Store/brand string for `AsyncMerchantLogoView` (optional income store link, expenses with merchant).
    func merchantLogoName(for record: ExpenseRecord) -> String? {
        guard let merchantId = record.merchantId else { return nil }
        if let merchant = try? persistence.fetchMerchantRecord(id: merchantId) {
            let linked = merchant.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !linked.isEmpty else { return nil }
            return linked
        }
        let store = record.merchantName.trimmingCharacters(in: .whitespacesAndNewlines)
        let label = record.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !store.isEmpty, store.caseInsensitiveCompare(label) != .orderedSame else { return nil }
        return store
    }

    func updateMerchant(_ record: ExpenseMerchantRecord) throws {
        try persistence.updateMerchant(record)
    }

    @discardableResult
    public func duplicateExpense(_ transaction: Transaction) throws -> Transaction {
        let copy = Transaction(
            date: Date(),
            amount: transaction.amount,
            merchantName: transaction.merchantName,
            category: transaction.category,
            notes: transaction.notes
        )
        return try saveExpense(copy)
    }

    // MARK: - Snapshots

    public func scheduleSnapshotRefresh() {
        snapshotWorkItem?.cancel()
        let work = DispatchWorkItem { @MainActor [weak self] in
            self?.rebuildSnapshots()
        }
        snapshotWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: work)
    }

    private func refreshSnapshotsImmediately() {
        rebuildSnapshots()
    }

    private func rebuildSnapshots() {
        let txs = financialBridge.engine.allTransactions().sorted { $0.date > $1.date }
        let expenseRecords = (try? persistence.fetchAllExpenseRecords()) ?? []
        let recordsById = Self.recordsByID(expenseRecords)
        let recent = Array(txs.prefix(5)).map { tx in
            let record = recordsById[tx.id]
            let emotion = record?.emotion
            return DashboardRecentTransaction(
                id: tx.id,
                date: tx.date,
                amount: tx.amount,
                merchantName: tx.merchantName,
                category: tx.category,
                emotion: emotion,
                emotionSymbol: emotion.flatMap { EmotionalTaggingEngine.tag(for: $0)?.symbol }
            )
        }
        let subs = financialBridge.engine.activeSubscriptions()
        let currency = txs.first?.amount.currencyCode
            ?? subs.first?.cost.currencyCode
            ?? AppSettingsManager.preferredCurrencyCode
        let monthly = subs.reduce(Decimal(0)) { $0 + abs($1.cost.value) }
        let health = Self.subscriptionHealthScore(for: subs)

        let totalBalance = txs.reduce(Decimal(0)) { $0 + $1.amount.value }
        
        let calendar = Self.budgetCalendar()
        let now = Date()
        let store = SettingsStore.shared
        store.migrateLegacyCustomBudgetModeIfNeeded()
        store.normalizeEnvelopeCategoryStorageIfNeeded()
        let budgetPeriod = BuxBudgetPeriodCalculator.currentPeriod(
            configuration: .fromSettings,
            now: now,
            calendar: calendar
        )
        let periodTxs = txs.filter { $0.date >= budgetPeriod.start && $0.date < budgetPeriod.end }

        let budgetingMode = store.budgetingMode
        let activeBudgetName: String?
        let activeBudgetLimit: Decimal
        let activeBudgetSpent: Decimal
        var envelopeBudgets: [EnvelopeBudgetDisplay] = []
        let locale = BuxInterfaceLocale.currentInterfaceLocale
        let categoryRecords = (try? persistence.fetchAllCategoryRecords()) ?? []
        let incomePool = BudgetEnvelopeEngine.incomePool(
            records: (try? persistence.fetchAllExpenseRecords()) ?? [],
            fundingSource: store.incomeFundingSource,
            period: budgetPeriod,
            locale: locale
        )
        let approachingThreshold = store.budgetApproachingThresholdPercent

        switch budgetingMode {
        case .simple, .custom:
            if let workspaceBudget = WorkspaceCurrencyContext.activeWorkspaceBudget() {
                activeBudgetName = BuxLocalizedString.format(
                    "Workspace budget · %@",
                    locale: locale,
                    workspaceBudget.workspaceName
                )
                activeBudgetLimit = workspaceBudget.limit
            } else {
                activeBudgetName = BuxLocalizedString.format(
                    "Simple budget · %@",
                    locale: locale,
                    store.simpleBudgetCycle.catalogLabel(locale: locale)
                )
                if store.autoAdjustBudgetsFromHistory {
                    activeBudgetLimit = Self.trailingAverageMonthlySpend(from: txs, calendar: calendar)
                } else {
                    activeBudgetLimit = store.simpleBudgetLimit
                }
            }
            activeBudgetSpent = periodTxs.filter { $0.amount.value < 0 }.reduce(Decimal(0)) { $0 + abs($1.amount.value) }

        case .envelope:
            let activeProfile = store.customBudgetProfiles.first(where: { $0.isActive })
            activeBudgetName = activeProfile?.name
            activeBudgetLimit = activeProfile?.targetAmount ?? 0

            if let activeProfile {
                envelopeBudgets = BudgetEnvelopeEngine.computeEnvelopes(
                    profile: activeProfile,
                    records: (try? persistence.fetchAllExpenseRecords()) ?? [],
                    categoryRecords: categoryRecords,
                    period: budgetPeriod,
                    locale: locale
                )
                activeBudgetSpent = envelopeBudgets.reduce(0) { $0 + $1.spent }
            } else {
                activeBudgetSpent = 0
            }
        }

        let hubSnapshot = SubscriptionHubSnapshot(
            subscriptions: subs,
            totalMonthly: monthly,
            healthScore: health,
            currencyCode: currency
        )
        let allExpenseRecords = (try? persistence.fetchAllExpenseRecords()) ?? []
        let workspaceSynergy = store.sideHustleMatrixEnabled
            ? WorkspaceROIEngine.summarize(records: allExpenseRecords, hustles: HustleManager.shared.hustles)
            : .empty

        let dashSnapshot = DashboardSnapshot(
            recentTransactions: recent,
            subscriptionMonthlyTotal: monthly,
            subscriptionCount: subs.count,
            subscriptionHealthScore: health,
            currencyCode: currency,
            totalBalance: totalBalance,
            activeBudgetName: activeBudgetName,
            activeBudgetLimit: activeBudgetLimit,
            activeBudgetSpent: activeBudgetSpent,
            budgetingMode: budgetingMode,
            incomePoolThisPeriod: incomePool,
            envelopeBudgets: envelopeBudgets,
            budgetPeriodStart: budgetPeriod.start,
            budgetPeriodEnd: budgetPeriod.end,
            approachingThresholdPercent: budgetingMode == .envelope
                ? (store.customBudgetProfiles.first(where: { $0.isActive })?.approachingThresholdPercent ?? 80)
                : approachingThreshold,
            workspaceSynergy: workspaceSynergy
        )

        dashboardSnapshot = dashSnapshot
        subscriptionHubSnapshot = hubSnapshot
        persistIntelligenceCache(subs: subs, currency: currency)
    }

    nonisolated private static func subscriptionHealthScore(for subs: [SubscriptionInfo]) -> Int {
        var score = 100
        for sub in subs {
            for risk in sub.risks {
                switch risk.type {
                case .priceHike: score -= 8
                case .doubleCharge: score -= 15
                case .zombieSubscription: score -= 10
                case .irregularCycle: score -= 3
                case .currencyChange: score -= 5
                default: score -= 4
                }
            }
        }
        return max(10, min(100, score))
    }

    // MARK: - Persist (debounced)

    private func schedulePersistGoals() {
        scheduleSave { [weak self] in
            guard let self else { return }
            try self.persistence.replaceAllGoals(self.goalsEngine.goals)
        }
    }

    func persistPreferences(
        navigation: NavigationCoordinator,
        appSettings: AppSettingsManager
    ) {
        scheduleSave { [weak self] in
            guard let self else { return }
            try self.persistence.savePreferences(
                selectedTab: navigation.selectedTab,
                currencyCode: appSettings.selectedCurrency.id,
                isBalanceVisible: navigation.isBalanceVisible,
                activeCategoryPill: navigation.activeCategoryPill
            )
        }
    }

    func persistTheme(_ theme: AppTheme) {
        scheduleSave { [weak self] in
            try self?.persistence.saveThemeId(theme.id)
        }
    }

    public func persistInsightMetadata(_ insights: [FinancialInsight]) {
        scheduleSave { [weak self] in
            try self?.persistence.replaceInsightMetadata(insights)
        }
    }

    private func scheduleSave(_ block: @escaping @MainActor () throws -> Void) {
        saveWorkItem?.cancel()
        let work = DispatchWorkItem { @MainActor in
            try? block()
        }
        saveWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
    }

    private func persistIntelligenceCache(subs: [SubscriptionInfo], currency: String) {
        Task { @MainActor in
            do {
                try persistence.replaceSubscriptionCache(subs)
                let now = Date()
                let cal = Calendar.current
                let start = cal.date(byAdding: .month, value: -1, to: now) ?? now
                let range = DateInterval(start: start, end: now)
                let engine = financialBridge.engine
                let baselines: [(category: TransactionCategory, value: Decimal, currency: String)] =
                    TransactionCategory.allCases.compactMap { cat in
                        guard cat != .income else { return nil }
                        let ref = range.start
                        let val = Self.baselineApproximation(engine: engine, category: cat, referenceDate: ref)
                        return (cat, val, currency)
                    }
                try persistence.replaceBaselines(baselines, referenceDate: now)
            } catch {
                print("Intelligence cache save failed: \(error)")
            }
        }
    }

    private static func baselineApproximation(
        engine: FinancialIntelligenceEngine,
        category: TransactionCategory,
        referenceDate: Date
    ) -> Decimal {
        let cal = Calendar.current
        guard let threeMonthsAgo = cal.date(byAdding: .month, value: -3, to: referenceDate),
              let sixMonthsAgo = cal.date(byAdding: .month, value: -6, to: referenceDate) else { return 0 }
        let range = DateInterval(start: sixMonthsAgo, end: threeMonthsAgo)
        let txs = engine.allTransactions().filter { range.contains($0.date) && $0.category == category }
        let total = txs.reduce(Decimal(0)) { $0 + $1.amount.value }
        let months = max(1, Set(txs.map { cal.component(.month, from: $0.date) }).count)
        return total / Decimal(months)
    }

    // MARK: - Expense Interaction Display Pipeline

    func updateExpenseInteractionSnapshot(records: [ExpenseRecord], currency: CurrencySetting) {
        expenseInteractionSnapshot = buildExpenseInteractionDisplay(from: records, currency: currency)
    }

    public func generateExpenseInteractionDisplay() async -> ExpenseInteractionDisplay {
        let allRecords = (try? persistence.fetchAllExpenseRecords()) ?? []
        let scoped = HustleWorkspaceFilter.filter(allRecords) { $0.hustleId }
        let globalCurrency = AppSettingsManager.currencySetting(for: AppSettingsManager.preferredCurrencyCode)
        return buildExpenseInteractionDisplay(
            from: scoped,
            currency: WorkspaceCurrencyContext.activeDisplayCurrency(global: globalCurrency)
        )
    }

    private func buildExpenseInteractionDisplay(from allRecords: [ExpenseRecord], currency: CurrencySetting) -> ExpenseInteractionDisplay {
        guard !allRecords.isEmpty else { return .empty }

        let now = Date()
        let startOfMonth = Calendar.current.dateInterval(of: .month, for: now)?.start ?? now
        let thisMonthRecords = allRecords.filter { $0.date >= startOfMonth }

        let lastMonthStart = Calendar.current.date(byAdding: .month, value: -1, to: startOfMonth) ?? now
        let lastMonthRecords = allRecords.filter { $0.date >= lastMonthStart && $0.date < startOfMonth }

        let totalSpent = thisMonthRecords.reduce(0.0) { $0 + abs($1.amountDouble) }
        let lastMonthSpent = lastMonthRecords.reduce(0.0) { $0 + abs($1.amountDouble) }
        let change = totalSpent - lastMonthSpent

        let locale = BuxInterfaceLocale.currentInterfaceLocale
        let categoryRecords = (try? fetchAllCategoryRecords()) ?? []
        let categoriesById = Dictionary(uniqueKeysWithValues: categoryRecords.map { ($0.id, $0) })
        let categories = Dictionary(grouping: thisMonthRecords, by: {
            $0.resolvedCategoryLabel(categoriesById: categoriesById, locale: locale)
        })
        let biggestCategory = categories.max(by: { $0.value.reduce(0) { $0 + abs($1.amountDouble) } < $1.value.reduce(0) { $0 + abs($1.amountDouble) } })?.key

        let merchants = Dictionary(grouping: thisMonthRecords, by: { $0.merchantName })
        let biggestMerchant = merchants.max(by: { $0.value.reduce(0) { $0 + abs($1.amountDouble) } < $1.value.reduce(0) { $0 + abs($1.amountDouble) } })?.key

        var sparkline = [Double]()
        for i in 0..<7 {
            let day = Calendar.current.date(byAdding: .day, value: -6 + i, to: now) ?? now
            let dayStart = Calendar.current.startOfDay(for: day)
            let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart)!
            let spent = thisMonthRecords.filter { $0.date >= dayStart && $0.date < dayEnd }.reduce(0) { $0 + abs($1.amountDouble) }
            sparkline.append(spent)
        }

        let header = ExpensesHeaderDisplay(
            totalSpent: totalSpent,
            changeVsLastMonth: change,
            monthlyTransactionCount: thisMonthRecords.count,
            biggestCategory: biggestCategory,
            biggestMerchant: biggestMerchant,
            sparklinePoints: sparkline,
            microInsight: change > 0
                ? BuxLocalizedString.string("Spending is up this month", locale: locale)
                : BuxLocalizedString.string("Great job keeping costs down", locale: locale)
        )

        let timelineGroups = ExpenseTimelineGrouper.group(allRecords)
        var sections = [ExpenseSectionDisplay]()

        let hustles = HustleManager.shared.hustles
        for group in timelineGroups {
            let displayRows = group.records.map { r in
                ExpenseRowDisplay(
                    id: r.id,
                    name: IncomeSourceQuickPick.localizedDisplayName(for: r.name, locale: locale),
                    amount: r.amountDouble,
                    amountFormatted: AppSettingsManager.format(
                        amount: abs(r.amountDouble),
                        currency: AppSettingsManager.currencySetting(for: r.currencyCode)
                    ),
                    date: r.date,
                    category: r.resolvedCategoryLabel(categoriesById: categoriesById, locale: locale),
                    merchant: r.merchantName,
                    heatZone: r.heatZoneBucket,
                    habitSignature: r.habitSignatureId,
                    emotion: r.emotion,
                    emotionSymbol: r.emotion.flatMap { EmotionalTaggingEngine.tag(for: $0)?.symbol },
                    context: r.contextTag,
                    hustleId: r.hustleId,
                    isUnassignedWorkspace: SettingsStore.shared.sideHustleMatrixEnabled && HustleWorkspaceFilter.isUnassigned(r.hustleId),
                    workspaceLabel: WorkspaceExpenseRowChrome.workspaceLabel(for: r.hustleId, hustles: hustles),
                    bridgeBadge: WorkspaceExpenseRowChrome.bridgeBadge(for: r, hustles: hustles)
                )
            }
            sections.append(ExpenseSectionDisplay(
                title: group.section.catalogLabel(locale: locale),
                microInsight: BuxLocalizedString.format(
                    "%lld transactions",
                    locale: locale,
                    displayRows.count
                ),
                expenses: displayRows
            ))
        }

        let summaryCat = categories.map { ($0.key, $0.value.reduce(0) { $0 + abs($1.amountDouble) }) }.sorted(by: { $0.1 > $1.1 })
        let summaryMer = merchants.map { ($0.key, $0.value.reduce(0) { $0 + abs($1.amountDouble) }) }.sorted(by: { $0.1 > $1.1 })
        let projected = Decimal(totalSpent * 1.2)

        let summary = ExpensesSummaryDisplay(
            totalSpent: totalSpent,
            categoryBreakdown: Array(summaryCat.prefix(5)),
            merchantBreakdown: Array(summaryMer.prefix(5)),
            trendPoints: sparkline,
            prediction: BuxLocalizedString.format(
                "Trending towards %@ this month",
                locale: locale,
                AppSettingsManager.format(amount: projected, currency: currency)
            )
        )

        return ExpenseInteractionDisplay(header: header, sections: sections, summary: summary)
    }

    private static func transactionMatchesEnvelopeCategory(
        _ tx: Transaction,
        envelopeName: String,
        recordsById: [UUID: ExpenseRecord],
        categoryRecords: [ExpenseCategoryRecord]
    ) -> Bool {
        if let record = recordsById[tx.id], let categoryId = record.categoryId,
           let custom = categoryRecords.first(where: { $0.id == categoryId }) {
            if custom.name.localizedCaseInsensitiveCompare(envelopeName) == .orderedSame {
                return true
            }
        }

        if tx.category.displayName.localizedCaseInsensitiveCompare(envelopeName) == .orderedSame {
            return true
        }

        if let record = recordsById[tx.id], let categoryId = record.categoryId,
           let custom = categoryRecords.first(where: { $0.id == categoryId }),
           let raw = custom.systemCategoryRaw,
           let system = TransactionCategory(rawValue: raw),
           system.displayName.localizedCaseInsensitiveCompare(envelopeName) == .orderedSame {
            return true
        }

        return false
    }

    private static func budgetCalendar() -> Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = SettingsStore.shared.weekStartDay.calendarWeekday
        return calendar
    }

    /// Trailing 3-month average spend, rounded up 10% — used when auto-adjust is enabled.
    private static func trailingAverageMonthlySpend(from transactions: [Transaction], calendar: Calendar) -> Decimal {
        let expenses = transactions.filter { $0.amount.value < 0 }
        guard !expenses.isEmpty else { return SettingsStore.shared.simpleBudgetLimit }

        let now = Date()
        var monthlyTotals: [Decimal] = []
        for monthOffset in 0..<3 {
            guard let monthStart = calendar.date(byAdding: .month, value: -monthOffset, to: now),
                  let interval = calendar.dateInterval(of: .month, for: monthStart) else { continue }
            let spent = expenses
                .filter { interval.contains($0.date) }
                .reduce(Decimal(0)) { $0 + abs($1.amount.value) }
            monthlyTotals.append(spent)
        }

        guard !monthlyTotals.isEmpty else { return SettingsStore.shared.simpleBudgetLimit }
        let average = monthlyTotals.reduce(0, +) / Decimal(monthlyTotals.count)
        let adjusted = average * Decimal(string: "1.1")!
        return max(SettingsStore.shared.simpleBudgetLimit, adjusted)
    }
}
