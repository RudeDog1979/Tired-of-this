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
    @Published public private(set) var expenseDataRevision: Int = 0
    /// Expenses tab list source — workspace-filtered cache for filters/search.
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
    private var allExpenseRecordsCache: [ExpenseRecord] = []
    private var expenseLedgerSignature: UInt64 = 0
    private var snapshotRebuildGeneration = 0

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
                self.refreshExpenses()
                self.scheduleSnapshotRefresh()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .buxMuseWalletSyncDidComplete)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshExpensesAfterWalletSync()
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
                self?.refreshForActiveWorkspaceChange()
                self?.scheduleSnapshotRefresh()
            }
            .store(in: &cancellables)

        SettingsStore.shared.$showUnassignedExpensesInWorkspace
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshForActiveWorkspaceChange()
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

        categoryRecords = (try? fetchAllCategoryRecords()) ?? []
        let settings = SettingsStore.shared
        settings.migrateLegacyCustomBudgetModeIfNeeded()
        settings.normalizeEnvelopeCategoryStorageIfNeeded()
        isHydrated = true
        scheduleSnapshotRefresh()
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

    private static func deduplicatedExpenseRecords(_ records: [ExpenseRecord]) -> [ExpenseRecord] {
        recordsByID(records).values.sorted { $0.date > $1.date }
    }

    // MARK: - Expenses (GRDB ledger)

    /// Full ledger reload — bulk sync, import, category merge only. Never hydrate or tab navigation.
    public func refreshExpenses() {
        guard !isRefreshingExpenses else { return }
        isRefreshingExpenses = true
        defer { isRefreshingExpenses = false }
        do {
            let all = try persistence.expenseDatabase.fetchAllRecords()
            applyFetchedExpenseRecords(all)
        } catch {
            print("refreshExpenses failed: \(error)")
        }
    }

    /// Wallet sync writes straight to GRDB — always re-hydrate ledger + bump revision for tab refresh.
    public func refreshExpensesAfterWalletSync() {
        guard !isRefreshingExpenses else { return }
        isRefreshingExpenses = true
        defer { isRefreshingExpenses = false }
        do {
            let all = try persistence.expenseDatabase.fetchAllRecords()
            expenseLedgerSignature = Self.ledgerSignature(for: all)
            allExpenseRecordsCache = all
            expenseRecords = HustleWorkspaceFilter.filter(all) { $0.hustleId }
            expenseDataRevision += 1
            loadTransactionsIntoEngine(all.map { $0.toTransaction() })
            scheduleSnapshotRefresh()
            financialBridge.objectWillChange.send()
            NotificationCenter.default.post(name: .buxMuseFinancialDataDidChange, object: nil)
        } catch {
            print("refreshExpensesAfterWalletSync failed: \(error)")
        }
    }

    private func applyFetchedExpenseRecords(_ all: [ExpenseRecord]) {
        let signature = Self.ledgerSignature(for: all)
        guard signature != expenseLedgerSignature else { return }

        expenseLedgerSignature = signature
        allExpenseRecordsCache = all
        expenseRecords = HustleWorkspaceFilter.filter(all) { $0.hustleId }
        expenseDataRevision += 1
        loadTransactionsIntoEngine(all.map { $0.toTransaction() })
        scheduleSnapshotRefresh()
        financialBridge.objectWillChange.send()
    }

    private func applyExpenseRecordUpsert(_ record: ExpenseRecord, isNew: Bool) {
        if let index = allExpenseRecordsCache.firstIndex(where: { $0.id == record.id }) {
            allExpenseRecordsCache[index] = record
        } else {
            allExpenseRecordsCache.append(record)
            allExpenseRecordsCache.sort { $0.date > $1.date }
        }
        expenseLedgerSignature = Self.ledgerSignature(for: allExpenseRecordsCache)
        expenseRecords = HustleWorkspaceFilter.filter(allExpenseRecordsCache) { $0.hustleId }
        expenseDataRevision += 1
        let transaction = record.toTransaction()
        if isNew {
            financialEngine.addTransaction(transaction)
        } else {
            financialEngine.updateTransaction(transaction)
        }
        financialBridge.objectWillChange.send()
        scheduleSnapshotRefresh()
    }

    private func applyExpenseRecordDelete(id: UUID) {
        allExpenseRecordsCache.removeAll { $0.id == id }
        expenseLedgerSignature = Self.ledgerSignature(for: allExpenseRecordsCache)
        expenseRecords = HustleWorkspaceFilter.filter(allExpenseRecordsCache) { $0.hustleId }
        expenseDataRevision += 1
        financialEngine.deleteTransaction(id: id)
        financialBridge.objectWillChange.send()
        scheduleSnapshotRefresh()
    }

    private static func ledgerSignature(for records: [ExpenseRecord]) -> UInt64 {
        guard !records.isEmpty else { return 0 }
        var signature = UInt64(records.count)
        let pendingRecords = records.filter(\.walletIsPending)
        signature ^= UInt64(pendingRecords.count) &* 7_919
        for pending in pendingRecords.prefix(16) {
            signature ^= UInt64(truncatingIfNeeded: pending.id.hashValue)
            signature ^= UInt64(bitPattern: Int64(pending.updatedAt.timeIntervalSince1970.bitPattern))
        }
        let stride = max(1, records.count / 64)
        for index in Swift.stride(from: 0, to: records.count, by: stride) {
            let record = records[index]
            signature ^= UInt64(bitPattern: Int64(record.updatedAt.timeIntervalSince1970.bitPattern))
            signature = signature &* 1_009 &+ UInt64(truncatingIfNeeded: record.id.hashValue)
            if record.walletIsPending {
                signature ^= 1
            }
        }
        if let newest = records.first, let oldest = records.last {
            signature ^= UInt64(truncatingIfNeeded: newest.id.hashValue)
            signature ^= UInt64(truncatingIfNeeded: oldest.id.hashValue)
        }
        return signature
    }

    /// Workspace pill changes only re-filter in-memory data.
    public func refreshForActiveWorkspaceChange() {
        expenseRecords = HustleWorkspaceFilter.filter(allExpenseRecordsCache) { $0.hustleId }
        expenseDataRevision += 1
        financialBridge.objectWillChange.send()
        scheduleSnapshotRefresh()
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
        let padUndoSnapshot = BuxPadExpenseUndoBridge.snapshotBeforeDelete(id: id, brain: self)
        let currencyCode = (try? fetchExpenseRecord(id: id))?.currencyCode ?? SettingsStore.shared.primaryLocalCurrency
        ExpenseRenewalReminderScheduler.cancel(for: id)
        try persistence.deleteExpenseRecord(id: id)
        applyExpenseRecordDelete(id: id)
        BuxPadExpenseUndoBridge.offerUndoAfterDelete(padUndoSnapshot, brain: self)
        PersonalCloudSyncEngine.shared.pushDeletedExpense(id: id, currencyCode: currencyCode)
    }

    /// Wallet reconciliation removed a stale pending duplicate — skip undo, keep ledger cache in sync.
    func removeWalletReconciledExpense(id: UUID) throws {
        guard let record = try? fetchExpenseRecord(id: id) else { return }
        ExpenseRenewalReminderScheduler.cancel(for: id)
        try persistence.deleteExpenseRecord(id: id)
        applyExpenseRecordDelete(id: id)
        PersonalCloudSyncEngine.shared.pushDeletedExpense(id: id, currencyCode: record.currencyCode)
    }

    // MARK: - Expense records (full SwiftData model)

    func fetchExpenseRecords(in period: DateInterval) throws -> [ExpenseRecord] {
        try persistence.fetchExpenseRecords(
            from: period.start,
            to: period.end,
            hustleId: HustleWorkspaceFilter.selectedHustleId,
            includeUnassigned: HustleWorkspaceFilter.showUnassignedWhenFiltered
        )
    }

    func fetchAllExpenseRecords() throws -> [ExpenseRecord] {
        try persistence.fetchAllExpenseRecords()
    }

    func fetchExpenseRecord(id: UUID) throws -> ExpenseRecord? {
        try persistence.fetchExpenseRecord(id: id)
    }

    @discardableResult
    func linkPaycheck(
        from record: ExpenseRecord,
        payCycle: SimpleBudgetCycle,
        payAnchorDate: Date
    ) throws -> ExpenseRecord {
        guard record.amountValue > 0 else {
            throw NSError(domain: "BuxMuseBrain", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Only incoming transactions can be linked as paycheck."
            ])
        }

        var updated = record
        SalaryPayrollMatcher.applySalaryTag(to: &updated)
        updated.categoryId = try persistence.categoryId(for: .income)
        let saved = try saveExpenseRecord(updated)

        let store = SettingsStore.shared
        store.salaryPayProfile = SalaryPayrollMatcher.buildProfile(
            from: saved,
            payCycle: payCycle,
            payAnchorDate: payAnchorDate
        )
        store.simpleBudgetCycle = payCycle
        store.simpleBudgetPeriodAnchor = Calendar.current.startOfDay(for: payAnchorDate)
        store.incomeFundingSource = .salary
        store.save()

        try retroactivelyApplySalaryProfile(store.salaryPayProfile)
        return saved
    }

    private func retroactivelyApplySalaryProfile(_ profile: SalaryPayProfile) throws {
        guard profile.isConfigured else { return }
        let records = try fetchAllExpenseRecords()
        for var record in records where record.amountValue > 0 && !record.isSalaryTagged {
            guard SalaryPayrollMatcher.applyAutoTagIfMatched(
                &record,
                profile: profile,
                weekStartDay: SettingsStore.shared.weekStartDay
            ) else { continue }
            _ = try saveExpenseRecord(record)
        }
    }

    @discardableResult
    func saveExpenseRecord(_ record: ExpenseRecord, merchantSelection: MerchantSelection? = nil) throws -> ExpenseRecord {
        var working = record
        let userDeclaredSubscription = working.isSubscriptionLike || working.isTrial
        let userMarkedRecurring = working.isRecurring && (working.recurrenceConfidence ?? 0) >= 0.85
        let intelligencePeers = (try? persistence.fetchExpenseRecordsForIntelligence(around: working)) ?? []
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
            allRecords: intelligencePeers,
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
            } else if merchantIsSubscriptionFlagged(
                normalizedMerchant: normalizedMerchant,
                merchantId: working.merchantId
            ) {
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
        applyExpenseRecordUpsert(saved, isNew: isNewRecord)
        Task { @MainActor in
            await ExpenseRenewalReminderScheduler.schedule(for: saved)
        }
        PersonalCloudSyncEngine.shared.pushExpenseIfNeeded(saved)
        return saved
    }

    private func merchantIsSubscriptionFlagged(normalizedMerchant: String, merchantId: UUID?) -> Bool {
        let merchants = (try? persistence.fetchAllMerchantRecords()) ?? []
        if let merchantId, let merchant = merchants.first(where: { $0.id == merchantId }) {
            return merchant.isSubscriptionMerchant
        }
        return merchants.contains {
            $0.isSubscriptionMerchant && $0.normalizedName == normalizedMerchant
        }
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
        if let updated = try persistence.fetchExpenseRecord(id: id) {
            applyExpenseRecordUpsert(updated, isNew: false)
        }
    }

    public func changeExpenseCategory(id: UUID, category: TransactionCategory, categoryId: UUID? = nil) throws {
        let existing = try persistence.fetchExpenseRecord(id: id)
        try persistence.updateExpenseCategory(id: id, category: category, categoryId: categoryId)
        if let existing {
            let merchantLabel = {
                let merchant = existing.merchantName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !merchant.isEmpty { return merchant }
                return existing.name.trimmingCharacters(in: .whitespacesAndNewlines)
            }()
            let walletRawLabel = existing.notes.flatMap {
                WalletStatementIntelligence.rawLabelFromStoredNote($0)
            }
            try persistence.rememberManualWalletMerchantCategory(
                merchantName: merchantLabel,
                walletRawLabel: walletRawLabel,
                category: category
            )
            if existing.financeKitTransactionId != nil {
                try persistence.markWalletCategoryUserConfirmed(expenseId: id)
            }
        }
        if let updated = try persistence.fetchExpenseRecord(id: id) {
            applyExpenseRecordUpsert(updated, isNew: false)
        }
    }

    public func cancelSubscription(merchantName: String) throws {
        let normalized = MerchantLogoEngine.normalizeMerchantName(merchantName)
        SettingsStore.shared.registerCancelledSubscription(normalizedMerchant: normalized)

        let affected = try persistence.fetchExpenseRecordsMatchingMerchant(merchantName: merchantName)
            .filter { MerchantLogoEngine.normalizeMerchantName($0.merchantName) == normalized }
        for var record in affected {
            record.isSubscriptionLike = false
            record.isTrial = false
            record.nextExpectedDate = nil
            record.subscriptionStartDate = nil
            record.trialEndDate = nil
            record.renewalReminderDays = nil
            ExpenseRenewalReminderScheduler.cancel(for: record.id)
            let saved = try persistence.upsertExpenseRecord(record)
            applyExpenseRecordUpsert(saved, isNew: false)
        }
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
        let intelligencePeers = (try? persistence.fetchExpenseRecordsForIntelligence(around: record)) ?? []
        let subs = financialEngine.activeSubscriptions()
        let categoryRecords = (try? fetchAllCategoryRecords()) ?? []
        let categoriesById = Dictionary(uniqueKeysWithValues: categoryRecords.map { ($0.id, $0) })
        return ExpenseIntelligenceEngine.analyze(
            record: record,
            allRecords: intelligencePeers,
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

    /// Store/brand string and optional persisted domain for `AsyncMerchantLogoView`.
    func merchantLogoContext(for record: ExpenseRecord) -> (name: String, knownDomain: String?)? {
        guard let merchantId = record.merchantId else {
            if record.amountValue > 0 || record.transactionCategory == .income {
                return nil
            }
            let store = record.merchantName.trimmingCharacters(in: .whitespacesAndNewlines)
            let label = record.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !store.isEmpty, store.caseInsensitiveCompare(label) != .orderedSame else { return nil }
            return (store, nil)
        }
        if let merchant = try? persistence.fetchMerchantRecord(id: merchantId) {
            let linked = merchant.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !linked.isEmpty else { return nil }
            let domain = merchant.logoURL.flatMap { MerchantLogoEngine.domain(fromStoredLogoURL: $0) }
            return (linked, domain)
        }
        let store = record.merchantName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !store.isEmpty else { return nil }
        return (store, nil)
    }

    /// Store/brand string for `AsyncMerchantLogoView` when the user explicitly linked a merchant.
    func merchantLogoName(for record: ExpenseRecord) -> String? {
        merchantLogoContext(for: record)?.name
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
            self?.startSnapshotRebuild()
        }
        snapshotWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: work)
    }

    private func refreshSnapshotsImmediately() {
        startSnapshotRebuild()
    }

    private func startSnapshotRebuild() {
        snapshotRebuildGeneration += 1
        let generation = snapshotRebuildGeneration
        let persistence = persistence
        let calendar = Self.budgetCalendar()
        let now = Date()
        let store = SettingsStore.shared
        let budgetPeriod = BuxBudgetPeriodCalculator.currentPeriod(
            configuration: .fromSettings,
            now: now,
            calendar: calendar
        )
        let hustleId = HustleWorkspaceFilter.selectedHustleId
        let includeUnassigned = HustleWorkspaceFilter.showUnassignedWhenFiltered
        let budgetingMode = store.budgetingMode
        let currencyCode = AppSettingsManager.preferredCurrencyCode
        let sql = persistence.expenseDatabase.sql

        Task.detached(priority: .utility) {
            let periodPayload = try? sql.fetchRecordsRaw(
                from: budgetPeriod.start,
                to: budgetPeriod.end,
                hustleId: hustleId,
                includeUnassigned: includeUnassigned
            )
            let recentPayload = try? sql.fetchRecentRecordsRaw(
                limit: 5,
                hustleId: hustleId,
                includeUnassigned: includeUnassigned
            )
            let monthlyTotals = (try? sql.fetchMonthlyOutflowTotals(months: 3)) ?? []
            let totalBalance = (try? sql.sumLedgerAmountValues(
                currencyCode: currencyCode,
                includePending: true,
                walletOnly: false
            )) ?? 0

            await MainActor.run { [weak self] in
                guard let self, generation == self.snapshotRebuildGeneration else { return }
                self.finishSnapshotRebuild(
                    periodPayload: periodPayload,
                    recentPayload: recentPayload,
                    monthlyTotals: monthlyTotals,
                    totalBalance: totalBalance,
                    budgetPeriod: budgetPeriod,
                    calendar: calendar,
                    store: store,
                    budgetingMode: budgetingMode
                )
            }
        }
    }

    private func finishSnapshotRebuild(
        periodPayload: ExpenseRowPayload?,
        recentPayload: ExpenseRowPayload?,
        monthlyTotals: [MonthlyOutflowTotal],
        totalBalance: Double,
        budgetPeriod: DateInterval,
        calendar: Calendar,
        store: SettingsStore,
        budgetingMode: BudgetingMode
    ) {
        let periodRecords = periodPayload.map { ExpenseGRDBRecordMapper.makeRecords(from: $0) } ?? []
        let recentRecords = recentPayload.map { ExpenseGRDBRecordMapper.makeRecords(from: $0) } ?? []
        let recent = recentRecords.map { record in
            let emotion = record.emotion
            return DashboardRecentTransaction(
                id: record.id,
                date: record.date,
                amount: record.toTransaction().amount,
                merchantName: record.merchantName,
                category: record.transactionCategory,
                emotion: emotion,
                emotionSymbol: emotion.flatMap { EmotionalTaggingEngine.tag(for: $0)?.symbol }
            )
        }
        let subs = financialBridge.engine.activeSubscriptions()
        let currency = periodRecords.first?.currencyCode
            ?? recentRecords.first?.currencyCode
            ?? subs.first?.cost.currencyCode
            ?? AppSettingsManager.preferredCurrencyCode
        let monthly = subs.reduce(Decimal(0)) { $0 + abs($1.cost.value) }
        let health = Self.subscriptionHealthScore(for: subs)

        let activeBudgetName: String?
        let activeBudgetLimit: Decimal
        let activeBudgetSpent: Decimal
        var essentialSpentThisPeriod: Decimal = 0
        var spendableRemainingThisPeriod: Decimal = 0
        var envelopeBudgets: [EnvelopeBudgetDisplay] = []
        let locale = BuxInterfaceLocale.currentInterfaceLocale
        let categoryRecords = (try? fetchAllCategoryRecords()) ?? []
        let loggedIncomePool = BudgetEnvelopeEngine.incomePool(
            records: periodRecords,
            fundingSource: store.incomeFundingSource,
            period: budgetPeriod,
            locale: locale
        )
        let simpleStudioSupplement = resolvedStandardSimpleStudioIncomeSupplement(
            period: budgetPeriod,
            records: periodRecords
        )
        let proStudioSupplement = resolvedStandardProStudioIncomeSupplement(
            period: budgetPeriod,
            records: periodRecords
        )
        let studioIncomeSupplement = simpleStudioSupplement.counted + proStudioSupplement.counted
        let studioIncomeExcludedByDedup = simpleStudioSupplement.excludedByDedup + proStudioSupplement.excludedByDedup
        let incomePool = loggedIncomePool + studioIncomeSupplement
        let approachingThreshold = store.budgetApproachingThresholdPercent
        let periodTxs = periodRecords.map { $0.toTransaction() }

        switch budgetingMode {
        case .simple, .custom:
            if let workspaceBudget = WorkspaceCurrencyContext.activeWorkspaceBudget() {
                activeBudgetName = BuxLocalizedString.format(
                    "Workspace budget · %@",
                    locale: locale,
                    workspaceBudget.workspaceName
                )
                activeBudgetLimit = workspaceBudget.limit
                activeBudgetSpent = periodTxs.filter { $0.amount.value < 0 }.reduce(Decimal(0)) { $0 + abs($1.amount.value) }
                spendableRemainingThisPeriod = workspaceBudget.limit - activeBudgetSpent
            } else {
                activeBudgetName = BuxLocalizedString.format(
                    "Standard budget · %@",
                    locale: locale,
                    store.simpleBudgetCycle.catalogLabel(locale: locale)
                )
                let spendingCap: Decimal = {
                    if store.autoAdjustBudgetsFromHistory {
                        return Self.trailingAverageMonthlySpend(from: monthlyTotals)
                    }
                    return store.simpleBudgetLimit
                }()
                let standardResult = BudgetPeriodEngine.computeStandardBudget(
                    records: periodRecords,
                    fundingSource: store.incomeFundingSource,
                    period: budgetPeriod,
                    spendingCap: spendingCap,
                    categoryRecords: categoryRecords,
                    supplementalEarned: studioIncomeSupplement,
                    locale: locale
                )
                activeBudgetLimit = standardResult.effectiveLimit
                activeBudgetSpent = standardResult.discretionarySpent
                essentialSpentThisPeriod = standardResult.essentialSpent
                spendableRemainingThisPeriod = standardResult.remaining
            }

        case .envelope:
            let activeProfile = store.customBudgetProfiles.first(where: { $0.isActive })
            activeBudgetName = activeProfile?.name
            activeBudgetLimit = activeProfile?.targetAmount ?? 0

            if let activeProfile {
                envelopeBudgets = BudgetEnvelopeEngine.computeEnvelopes(
                    profile: activeProfile,
                    records: periodRecords,
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
        let workspaceSynergy = store.sideHustleMatrixEnabled
            ? WorkspaceROIEngine.summarize(records: periodRecords, hustles: HustleManager.shared.hustles)
            : .empty

        let dashSnapshot = DashboardSnapshot(
            recentTransactions: recent,
            subscriptionMonthlyTotal: monthly,
            subscriptionCount: subs.count,
            subscriptionHealthScore: health,
            currencyCode: currency,
            totalBalance: Decimal(totalBalance),
            activeBudgetName: activeBudgetName,
            activeBudgetLimit: activeBudgetLimit,
            activeBudgetSpent: activeBudgetSpent,
            budgetingMode: budgetingMode,
            incomePoolThisPeriod: incomePool,
            standardSimpleStudioIncomeSupplement: simpleStudioSupplement.counted,
            standardProStudioIncomeSupplement: proStudioSupplement.counted,
            standardStudioIncomeExcludedByDedup: studioIncomeExcludedByDedup,
            essentialSpentThisPeriod: essentialSpentThisPeriod,
            spendableRemainingThisPeriod: spendableRemainingThisPeriod,
            envelopeBudgets: envelopeBudgets,
            budgetPeriodStart: budgetPeriod.start,
            budgetPeriodEnd: budgetPeriod.end,
            approachingThresholdPercent: budgetingMode == .envelope
                ? (store.customBudgetProfiles.first(where: { $0.isActive })?.approachingThresholdPercent ?? 80)
                : approachingThreshold,
            workspaceSynergy: workspaceSynergy
        )

        if dashboardSnapshot != dashSnapshot {
            dashboardSnapshot = dashSnapshot
        }
        if subscriptionHubSnapshot != hubSnapshot {
            subscriptionHubSnapshot = hubSnapshot
        }
        persistIntelligenceCache(subs: subs, currency: currency)
    }

    private static func trailingAverageMonthlySpend(from monthlyTotals: [MonthlyOutflowTotal]) -> Decimal {
        guard !monthlyTotals.isEmpty else { return SettingsStore.shared.simpleBudgetLimit }
        let totals = monthlyTotals.map { Decimal($0.total) }
        let average = totals.reduce(0, +) / Decimal(totals.count)
        let adjusted = average * Decimal(string: "1.1")!
        return max(SettingsStore.shared.simpleBudgetLimit, adjusted)
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
            PersonalCloudSyncEngine.shared.pushGoalsIfNeeded(self.goalsEngine.goals)
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

    func publishExpenseInteractionDisplay(_ display: ExpenseInteractionDisplay) {
        expenseInteractionSnapshot = display
    }

    /// Scoped GRDB fetch for the Expenses tab — SQL off main, mapping on MainActor.
    func fetchScopedExpenseTabContent(currency: CurrencySetting) async -> (display: ExpenseInteractionDisplay, listRecords: [ExpenseRecord])? {
        let calendar = Calendar.current
        let now = Date()
        guard let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start,
              let lastMonthStart = calendar.date(byAdding: .month, value: -1, to: startOfMonth) else {
            return nil
        }

        let store = SettingsStore.shared
        let budgetConfig = BuxBudgetPeriodCalculator.Configuration(
            cycle: store.simpleBudgetCycle,
            weekStartDay: store.weekStartDay,
            anchorDate: store.simpleBudgetPeriodAnchor
        )
        let budgetCalendar = BuxBudgetPeriodCalculator.calendar(weekStartDay: budgetConfig.weekStartDay)
        let currentPeriod = BuxBudgetPeriodCalculator.currentPeriod(
            configuration: budgetConfig,
            now: now,
            calendar: budgetCalendar
        )
        let previousAnchor = budgetCalendar.date(byAdding: .second, value: -1, to: currentPeriod.start) ?? currentPeriod.start
        let previousPeriod = BuxBudgetPeriodCalculator.currentPeriod(
            configuration: budgetConfig,
            now: previousAnchor,
            calendar: budgetCalendar
        )

        let hustleId = HustleWorkspaceFilter.selectedHustleId
        let includeUnassigned = HustleWorkspaceFilter.showUnassignedWhenFiltered
        let sql = persistence.expenseDatabase.sql
        let periodStart = currentPeriod.start
        let periodEnd = currentPeriod.end
        let prevPeriodStart = previousPeriod.start
        let prevPeriodEnd = previousPeriod.end

        let raw: (scope: LedgerScopeRaw, payPeriod: ExpenseRowPayload, previousPayPeriod: ExpenseRowPayload, ledgerBalance: Double)
        do {
            raw = try await Task.detached(priority: .userInitiated) {
                let scope = try sql.fetchLedgerScopeRaw(
                    currentMonthStart: startOfMonth,
                    lastMonthStart: lastMonthStart,
                    hustleId: hustleId,
                    includeUnassigned: includeUnassigned
                )
                let periodPayload = try sql.fetchRecordsRaw(
                    from: periodStart,
                    to: periodEnd,
                    hustleId: hustleId,
                    includeUnassigned: includeUnassigned
                )
                let previousPeriodPayload = try sql.fetchRecordsRaw(
                    from: prevPeriodStart,
                    to: prevPeriodEnd,
                    hustleId: hustleId,
                    includeUnassigned: includeUnassigned
                )
                let ledgerBalance = (try? sql.sumLedgerAmountValues(
                    currencyCode: currency.id,
                    includePending: true,
                    walletOnly: false
                )) ?? 0
                return (scope, periodPayload, previousPeriodPayload, ledgerBalance)
            }.value
        } catch {
            print("fetchScopedExpenseTabContent failed: \(error)")
            return nil
        }

        let pack = ExpenseGRDBRecordMapper.makeLedgerScopePack(from: raw.scope)
        let payPeriodRecords = ExpenseGRDBRecordMapper.makeRecords(from: raw.payPeriod)
        let previousPayPeriodRecords = ExpenseGRDBRecordMapper.makeRecords(from: raw.previousPayPeriod)
        let display = buildScopedExpenseDisplay(
            currentMonthRecords: pack.currentMonth,
            lastMonthRecords: pack.lastMonth,
            pendingWalletRecords: pack.pendingWallet,
            archiveMonths: pack.archiveMonths,
            currency: currency,
            budgetConfiguration: budgetConfig,
            payPeriodRecords: payPeriodRecords,
            previousPayPeriodRecords: previousPayPeriodRecords,
            referenceDate: now,
            ledgerBalance: raw.ledgerBalance
        )
        return (display, Self.deduplicatedExpenseRecords(pack.currentMonth + pack.pendingWallet))
    }

    func fetchArchiveMonthRecords(monthStart: Date) async -> [ExpenseRecord] {
        let calendar = Calendar.current
        guard let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) else { return [] }
        let sql = persistence.expenseDatabase.sql
        do {
            let payload = try await Task.detached(priority: .userInitiated) {
                try sql.fetchRecordsRaw(
                    from: monthStart,
                    to: monthEnd,
                    hustleId: nil,
                    includeUnassigned: false
                )
            }.value
            return ExpenseGRDBRecordMapper.makeRecords(from: payload)
        } catch {
            print("fetchArchiveMonthRecords failed: \(error)")
            return []
        }
    }

    func makeExpenseRowDisplays(from records: [ExpenseRecord]) -> [ExpenseRowDisplay] {
        guard !records.isEmpty else { return [] }
        let locale = BuxInterfaceLocale.currentInterfaceLocale
        let categoryRecords = self.categoryRecords
        let categoriesById = Dictionary(uniqueKeysWithValues: categoryRecords.map { ($0.id, $0) })
        let hustles = HustleManager.shared.hustles
        return records.map { record in
            let rowCurrency = AppSettingsManager.currencySetting(for: record.currencyCode)
            let isIncome = record.isIncomeInflow
            return ExpenseRowDisplay(
                id: record.id,
                name: ExpenseDisplayL10n.label(record.name, locale: locale),
                amount: record.amountDouble,
                amountFormatted: ExpenseDisplayL10n.signedAmount(for: record, currency: rowCurrency),
                date: record.date,
                category: record.resolvedCategoryLabel(categoriesById: categoriesById, locale: locale),
                merchant: record.merchantName,
                heatZone: record.heatZoneBucket,
                habitSignature: record.habitSignatureId,
                emotion: record.emotion,
                emotionSymbol: record.emotion.flatMap { EmotionalTaggingEngine.tag(for: $0)?.symbol },
                context: record.contextTag,
                hustleId: record.hustleId,
                isUnassignedWorkspace: SettingsStore.shared.sideHustleMatrixEnabled && HustleWorkspaceFilter.isUnassigned(record.hustleId),
                workspaceLabel: WorkspaceExpenseRowChrome.workspaceLabel(for: record.hustleId, hustles: hustles),
                bridgeBadge: WorkspaceExpenseRowChrome.bridgeBadge(for: record, hustles: hustles),
                isWalletPending: record.walletIsPending,
                isSalaryTagged: record.isSalaryTagged,
                isIncomeInflow: isIncome,
                isExcludedFromSpending: record.isExcludedFromSpending
            )
        }
    }

    func buildExpenseInteractionDisplay(from allRecords: [ExpenseRecord], currency: CurrencySetting) -> ExpenseInteractionDisplay {
        let ledgerBalance = (try? persistence.expenseDatabase.sql.sumLedgerAmountValues(
            currencyCode: currency.id,
            includePending: true,
            walletOnly: false
        )) ?? 0
        guard !allRecords.isEmpty else {
            if ledgerBalance == 0 { return .empty }
            return ExpenseInteractionDisplay(
                header: ExpensesHeaderDisplay(
                    totalSpent: 0,
                    totalIncome: 0,
                    ledgerBalance: ledgerBalance,
                    changeVsLastMonth: 0,
                    monthlyTransactionCount: 0,
                    biggestCategory: nil,
                    biggestMerchant: nil,
                    sparklinePoints: [],
                    microInsight: nil,
                    periodRangeSubtitle: nil,
                    periodElapsedDays: 1
                ),
                pendingExpenses: [],
                sections: [],
                summary: ExpensesSummaryDisplay(
                    totalSpent: 0,
                    changeVsLastMonth: 0,
                    categoryBreakdown: [],
                    merchantBreakdown: [],
                    trendPoints: [],
                    prediction: nil
                ),
                archiveMonths: []
            )
        }

        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
        let pendingWalletRecords = allRecords.filter(\.walletIsPending)
        let bookedRecords = allRecords.filter { !$0.walletIsPending }
        let currentMonthRecords = bookedRecords.filter { $0.date >= startOfMonth }
        let lastMonthStart = calendar.date(byAdding: .month, value: -1, to: startOfMonth) ?? now
        let lastMonthRecords = bookedRecords.filter { $0.date >= lastMonthStart && $0.date < startOfMonth }
        let archiveMonths: [ExpenseArchiveMonthIndex] = []

        return buildScopedExpenseDisplay(
            currentMonthRecords: currentMonthRecords,
            lastMonthRecords: lastMonthRecords,
            pendingWalletRecords: pendingWalletRecords,
            archiveMonths: archiveMonths,
            currency: currency,
            budgetConfiguration: BuxBudgetPeriodCalculator.Configuration.fromSettings,
            referenceDate: now,
            ledgerBalance: ledgerBalance
        )
    }

    func buildScopedExpenseDisplay(
        currentMonthRecords: [ExpenseRecord],
        lastMonthRecords: [ExpenseRecord],
        pendingWalletRecords: [ExpenseRecord],
        archiveMonths: [ExpenseArchiveMonthIndex],
        currency: CurrencySetting,
        budgetConfiguration: BuxBudgetPeriodCalculator.Configuration,
        payPeriodRecords: [ExpenseRecord]? = nil,
        previousPayPeriodRecords: [ExpenseRecord]? = nil,
        referenceDate: Date = Date(),
        ledgerBalance: Double = 0
    ) -> ExpenseInteractionDisplay {
        if currentMonthRecords.isEmpty,
           lastMonthRecords.isEmpty,
           archiveMonths.isEmpty,
           pendingWalletRecords.isEmpty,
           ledgerBalance == 0 {
            return .empty
        }

        let calendar = Calendar.current
        let now = referenceDate
        let budgetCalendar = BuxBudgetPeriodCalculator.calendar(weekStartDay: budgetConfiguration.weekStartDay)
        let currentPeriod = BuxBudgetPeriodCalculator.currentPeriod(
            configuration: budgetConfiguration,
            now: now,
            calendar: budgetCalendar
        )
        let previousAnchor = budgetCalendar.date(byAdding: .second, value: -1, to: currentPeriod.start) ?? currentPeriod.start
        let previousPeriod = BuxBudgetPeriodCalculator.currentPeriod(
            configuration: budgetConfiguration,
            now: previousAnchor,
            calendar: budgetCalendar
        )

        let bookedCurrentMonth = currentMonthRecords.filter { !$0.walletIsPending }

        let mergedBooked = bookedCurrentMonth + lastMonthRecords.filter { !$0.walletIsPending }

        let resolvedPeriodRecords = payPeriodRecords ?? mergedBooked.filter {
            $0.date >= currentPeriod.start && $0.date < currentPeriod.end
        }
        let resolvedPreviousPeriodRecords = previousPayPeriodRecords ?? mergedBooked.filter {
            $0.date >= previousPeriod.start && $0.date < previousPeriod.end
        }

        // Calendar month — summary card
        let thisMonthSpending = bookedCurrentMonth.filter(\.isSpendingOutflow)
        let lastMonthSpending = lastMonthRecords.filter { !$0.walletIsPending }.filter(\.isSpendingOutflow)
        let monthTotalSpent = thisMonthSpending.reduce(0.0) { $0 + $1.spendingAmountDouble }
        let lastMonthSpent = lastMonthSpending.reduce(0.0) { $0 + $1.spendingAmountDouble }
        let monthChange = monthTotalSpent - lastMonthSpent

        // Pay period — header card
        let periodBooked = resolvedPeriodRecords.filter { !$0.walletIsPending }
        let periodSpending = periodBooked.filter(\.isSpendingOutflow)
        let periodIncomeRecords = periodBooked.filter(\.isIncomeInflow)
        let previousPeriodSpending = resolvedPreviousPeriodRecords
            .filter { !$0.walletIsPending }
            .filter(\.isSpendingOutflow)

        let periodTotalSpent = periodSpending.reduce(0.0) { $0 + $1.spendingAmountDouble }
        let periodTotalIncome = periodIncomeRecords.reduce(0.0) { $0 + $1.incomeAmountDouble }
        let previousPeriodSpent = previousPeriodSpending.reduce(0.0) { $0 + $1.spendingAmountDouble }
        let periodChange = periodTotalSpent - previousPeriodSpent

        let periodElapsedDays = max(
            1,
            budgetCalendar.dateComponents([.day], from: currentPeriod.start, to: budgetCalendar.startOfDay(for: now)).day ?? 1
        )

        let locale = BuxInterfaceLocale.currentInterfaceLocale
        let categoryRecords = self.categoryRecords
        let categoriesById = Dictionary(uniqueKeysWithValues: categoryRecords.map { ($0.id, $0) })

        let periodCategories = Dictionary(grouping: periodSpending, by: {
            $0.resolvedCategoryLabel(categoriesById: categoriesById, locale: locale)
        })
        let biggestCategory = periodCategories.max(by: {
            $0.value.reduce(0) { $0 + $1.spendingAmountDouble } < $1.value.reduce(0) { $0 + $1.spendingAmountDouble }
        })?.key

        let periodMerchants = Dictionary(grouping: periodSpending, by: { $0.merchantName })
        let biggestMerchant = periodMerchants.max(by: {
            $0.value.reduce(0) { $0 + $1.spendingAmountDouble } < $1.value.reduce(0) { $0 + $1.spendingAmountDouble }
        })?.key

        var periodSparkline = [Double]()
        for i in 0..<7 {
            let day = calendar.date(byAdding: .day, value: -6 + i, to: now) ?? now
            let dayStart = calendar.startOfDay(for: day)
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
            let spent = periodSpending.filter { $0.date >= dayStart && $0.date < dayEnd }.reduce(0.0) {
                $0 + abs($1.amountDouble)
            }
            periodSparkline.append(spent)
        }

        var monthSparkline = [Double]()
        for i in 0..<7 {
            let day = calendar.date(byAdding: .day, value: -6 + i, to: now) ?? now
            let dayStart = calendar.startOfDay(for: day)
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
            let spent = thisMonthSpending.filter { $0.date >= dayStart && $0.date < dayEnd }.reduce(0) { $0 + $1.spendingAmountDouble }
            monthSparkline.append(spent)
        }

        let periodSubtitle = BuxBudgetPeriodCalculator.periodRangeSubtitle(
            period: currentPeriod,
            configuration: budgetConfiguration,
            locale: locale,
            calendar: budgetCalendar
        )

        let header = ExpensesHeaderDisplay(
            totalSpent: periodTotalSpent,
            totalIncome: periodTotalIncome,
            ledgerBalance: ledgerBalance,
            changeVsLastMonth: periodChange,
            monthlyTransactionCount: periodSpending.count,
            biggestCategory: biggestCategory,
            biggestMerchant: biggestMerchant,
            sparklinePoints: periodSparkline,
            microInsight: periodChange > 0
                ? BuxLocalizedString.string("Spending is up this period", locale: locale)
                : BuxLocalizedString.string("Great job keeping costs down", locale: locale),
            periodRangeSubtitle: periodSubtitle,
            periodElapsedDays: periodElapsedDays
        )

        let timelineGroups = ExpenseTimelineGrouper.group(bookedCurrentMonth, calendar: calendar)
        var sections = [ExpenseSectionDisplay]()
        for group in timelineGroups {
            let displayRows = makeExpenseRowDisplays(from: group.records)
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

        let pendingExpenses = makeExpenseRowDisplays(
            from: pendingWalletRecords.sorted {
                if $0.date != $1.date { return $0.date > $1.date }
                return $0.updatedAt > $1.updatedAt
            }
        )

        let summaryCat = Dictionary(grouping: thisMonthSpending, by: {
            $0.resolvedCategoryLabel(categoriesById: categoriesById, locale: locale)
        }).map { ($0.key, $0.value.reduce(0) { $0 + $1.spendingAmountDouble }) }.sorted(by: { $0.1 > $1.1 })
        let summaryMer = Dictionary(grouping: thisMonthSpending, by: { $0.merchantName })
            .map { ($0.key, $0.value.reduce(0) { $0 + $1.spendingAmountDouble }) }
            .sorted(by: { $0.1 > $1.1 })
        let projected = Decimal(monthTotalSpent * 1.2)

        let summary = ExpensesSummaryDisplay(
            totalSpent: monthTotalSpent,
            changeVsLastMonth: monthChange,
            categoryBreakdown: Array(summaryCat.prefix(5)),
            merchantBreakdown: Array(summaryMer.prefix(5)),
            trendPoints: monthSparkline,
            prediction: BuxLocalizedString.format(
                "Trending towards %@ this month",
                locale: locale,
                AppSettingsManager.format(amount: projected, currency: currency)
            )
        )

        return ExpenseInteractionDisplay(
            header: header,
            pendingExpenses: pendingExpenses,
            sections: sections,
            summary: summary,
            archiveMonths: archiveMonths
        )
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
    func resolvedStandardSpendingCap() -> Decimal {
        let store = SettingsStore.shared
        if store.autoAdjustBudgetsFromHistory {
            let totals = (try? persistence.expenseDatabase.sql.fetchMonthlyOutflowTotals(months: 3)) ?? []
            return Self.trailingAverageMonthlySpend(from: totals)
        }
        return store.simpleBudgetLimit
    }

    func resolvedStandardStudioIncomeSupplement(period: DateInterval, records: [ExpenseRecord]) -> Decimal {
        resolvedStandardSimpleStudioIncomeSupplement(period: period, records: records).counted
            + resolvedStandardProStudioIncomeSupplement(period: period, records: records).counted
    }

    func resolvedStandardSimpleStudioIncomeSupplement(
        period: DateInterval,
        records: [ExpenseRecord]
    ) -> StandardBudgetStudioSupplement {
        let store = SettingsStore.shared
        guard store.budgetingMode == .simple || store.budgetingMode == .custom else {
            return StandardBudgetStudioSupplement(counted: 0, excludedByDedup: 0)
        }
        return StandardBudgetStudioBridge.supplementalIncome(
            period: period,
            entries: SimpleStudioStore.shared.entries,
            incomeRecords: records,
            fundingSource: store.incomeFundingSource,
            studioEnabled: store.studioEnabled,
            studioMode: store.studioMode,
            includeInBudget: store.includeSimpleStudioIncomeInBudget
        )
    }

    func resolvedStandardProStudioIncomeSupplement(
        period: DateInterval,
        records: [ExpenseRecord]
    ) -> StandardBudgetStudioSupplement {
        let store = SettingsStore.shared
        guard store.budgetingMode == .simple || store.budgetingMode == .custom else {
            return StandardBudgetStudioSupplement(counted: 0, excludedByDedup: 0)
        }
        return StandardBudgetStudioBridge.proSupplementalIncome(
            period: period,
            invoices: StudioStore.shared.invoices,
            incomeRecords: records,
            fundingSource: store.incomeFundingSource,
            studioEnabled: store.studioEnabled,
            studioMode: store.studioMode,
            includeInBudget: store.includeProStudioIncomeInBudget
        )
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
