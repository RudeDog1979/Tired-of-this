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
    @Published public private(set) var isHydrated: Bool = false

    let persistence: PersistenceController
    public let financialBridge: FinancialEngineBridge
    public let goalsEngine: GoalsEngine
    public let insightsEngine: InsightsEngine

    private let computeQueue = DispatchQueue(label: "com.buxmuse.brain.compute", qos: .userInitiated)
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
    }

    // MARK: - Hydration

    func hydrateFromPersistence(appSettings: AppSettingsManager, themeManager: ThemeManager, navigation: NavigationCoordinator) {
        do {
            try persistence.seedExpenseCatalogIfNeeded()
            let transactions = try persistence.fetchAllExpenses()
            loadTransactionsIntoEngine(transactions)

            let goals = try persistence.fetchAllGoals()
            goalsEngine.replaceAllGoals(goals)

            let prefs = try persistence.loadPreferences()
            navigation.restore(
                tab: AppTab.from(storageKey: prefs.selectedTabRaw),
                activeCategory: prefs.activeCategoryPill,
                isBalanceVisible: prefs.isBalanceVisible
            )
            if let currency = AppSettingsManager.availableCurrencies.first(where: { $0.id == prefs.currencyCode }) {
                appSettings.applyCurrency(currency, persist: false)
            }

            let themeId = try persistence.loadThemeId()
            if let theme = AppTheme.all.first(where: { $0.id == themeId }) {
                themeManager.applyTheme(theme, persist: false)
            }

            _ = try? persistence.fetchInsightMetadata()
        } catch {
            print("Brain hydration error: \(error)")
        }

        refreshSnapshotsImmediately()
        if let records = try? persistence.fetchAllExpenseRecords() {
            updateExpenseInteractionSnapshot(records: records, currency: appSettings.selectedCurrency)
        }
        isHydrated = true
    }

    private func loadTransactionsIntoEngine(_ transactions: [Transaction]) {
        if let engine18 = financialBridge.engine as? LocalFinancialIntelligenceEngine18 {
            engine18.loadTransactions(transactions)
        }
        if #available(iOS 26, *) {
            if let engine26 = financialBridge.engine as? LocalFinancialIntelligenceEngine {
                engine26.loadTransactions(transactions)
            }
        }
    }

    // MARK: - Expenses (immediate SwiftData — no debounce)

    /// Reload in-memory engine + snapshots from SwiftData only. Does not write to disk.
    public func refreshExpenses() {
        isRefreshingExpenses = true
        defer { isRefreshingExpenses = false }

        do {
            let transactions = try persistence.fetchAllExpenses()
            loadTransactionsIntoEngine(transactions)
            refreshSnapshotsImmediately()
            financialBridge.objectWillChange.send()
            
            // Recompute expense interaction display
            Task {
                let display = await generateExpenseInteractionDisplay()
                await MainActor.run {
                    self.expenseInteractionSnapshot = display
                }
            }
        } catch {
            print("refreshExpenses failed: \(error)")
        }
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
    func saveExpenseRecord(_ record: ExpenseRecord) throws -> ExpenseRecord {
        var working = record
        let userDeclaredSubscription = working.isSubscriptionLike || working.isTrial
        let all = (try? persistence.fetchAllExpenseRecords()) ?? []
        let subs = financialEngine.activeSubscriptions()
        let analysis = ExpenseIntelligenceEngine.analyze(record: working, allRecords: all, activeSubscriptions: subs)
        working.isRecurring = analysis.isRecurring
        working.recurrenceType = analysis.recurrenceType
        working.recurrenceConfidence = analysis.recurrenceConfidence
        if !userDeclaredSubscription {
            working.isSubscriptionLike = analysis.isSubscriptionLike
        }
        if working.nextExpectedDate == nil {
            working.nextExpectedDate = analysis.nextExpectedDate
        }
        if userDeclaredSubscription, working.isSubscriptionLike {
            working.categoryRaw = TransactionCategory.subscriptions.rawValue
            working.categoryId = try? persistence.categoryId(for: .subscriptions)
        }
        working.heatZoneBucket = analysis.heatZoneBucket

        let saved = try persistence.upsertExpenseRecord(working)
        refreshExpenses()
        Task {
            await ExpenseRenewalReminderScheduler.schedule(for: saved)
        }
        return saved
    }

    func updateExpenseNotes(id: UUID, notes: String?) throws {
        try persistence.updateExpenseNotes(id: id, notes: notes)
        refreshExpenses()
    }

    public func changeExpenseCategory(id: UUID, category: TransactionCategory) throws {
        try persistence.updateExpenseCategory(id: id, category: category)
        refreshExpenses()
    }

    func convertExpenseToSubscription(id: UUID) throws {
        guard var record = try persistence.fetchExpenseRecord(id: id) else { return }
        record.categoryRaw = TransactionCategory.subscriptions.rawValue
        record.isSubscriptionLike = true
        record.categoryId = try persistence.categoryId(for: .subscriptions)
        _ = try saveExpenseRecord(record)
    }

    func markExpenseRecurring(id: UUID, type: String) throws {
        guard var record = try persistence.fetchExpenseRecord(id: id) else { return }
        record.isRecurring = true
        record.recurrenceType = type
        record.recurrenceConfidence = max(record.recurrenceConfidence ?? 0, 0.85)
        _ = try saveExpenseRecord(record)
    }

    func expenseIntelligenceDisplay(for id: UUID) -> ExpenseIntelligenceDisplay {
        guard let record = try? persistence.fetchExpenseRecord(id: id) else { return .empty }
        let all = (try? persistence.fetchAllExpenseRecords()) ?? []
        let subs = financialEngine.activeSubscriptions()
        return ExpenseIntelligenceEngine.analyze(record: record, allRecords: all, activeSubscriptions: subs).display
    }

    func categoryId(for category: TransactionCategory) throws -> UUID {
        try persistence.categoryId(for: category)
    }

    func fetchAllCategoryRecords() throws -> [ExpenseCategoryRecord] {
        try persistence.fetchAllCategoryRecords()
    }

    func createCategory(name: String, icon: String, color: String) throws -> ExpenseCategoryRecord {
        try persistence.createCategory(name: name, icon: icon, color: color)
    }

    func updateCategory(_ record: ExpenseCategoryRecord) throws {
        try persistence.updateCategory(record)
    }

    func deleteCategory(id: UUID) throws {
        try persistence.deleteCategory(id: id)
    }

    func mergeCategories(sourceId: UUID, into targetId: UUID) throws {
        try persistence.mergeCategories(sourceId: sourceId, into: targetId)
        refreshExpenses()
    }

    func fetchAllMerchantRecords() throws -> [ExpenseMerchantRecord] {
        try persistence.fetchAllMerchantRecords()
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
        let work = DispatchWorkItem { [weak self] in
            self?.rebuildSnapshotsOffMain()
        }
        snapshotWorkItem = work
        computeQueue.asyncAfter(deadline: .now() + 0.05, execute: work)
    }

    private func refreshSnapshotsImmediately() {
        rebuildSnapshotsOffMain()
    }

    private func rebuildSnapshotsOffMain() {
        let txs = financialBridge.engine.allTransactions().sorted { $0.date > $1.date }
        let recent = Array(txs.prefix(5))
        let subs = financialBridge.engine.activeSubscriptions()
        let currency = txs.first?.amount.currencyCode
            ?? subs.first?.cost.currencyCode
            ?? AppSettingsManager.preferredCurrencyCode
        let monthly = subs.reduce(Decimal(0)) { $0 + abs($1.cost.value) }
        let health = Self.subscriptionHealthScore(for: subs)

        let hubSnapshot = SubscriptionHubSnapshot(
            subscriptions: subs,
            totalMonthly: monthly,
            healthScore: health,
            currencyCode: currency
        )
        let dashSnapshot = DashboardSnapshot(
            recentTransactions: recent,
            subscriptionMonthlyTotal: monthly,
            subscriptionCount: subs.count,
            subscriptionHealthScore: health,
            currencyCode: currency
        )

        computeQueue.async { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                self.dashboardSnapshot = dashSnapshot
                self.subscriptionHubSnapshot = hubSnapshot
                self.persistIntelligenceCache(subs: subs, currency: currency)
            }
        }
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

    private func scheduleSave(_ block: @escaping () throws -> Void) {
        saveWorkItem?.cancel()
        let work = DispatchWorkItem {
            Task { @MainActor in
                try? block()
            }
        }
        saveWorkItem = work
        computeQueue.asyncAfter(deadline: .now() + 0.25, execute: work)
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
        return buildExpenseInteractionDisplay(
            from: allRecords,
            currency: AppSettingsManager.currencySetting(for: AppSettingsManager.preferredCurrencyCode)
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

        let categories = Dictionary(grouping: thisMonthRecords, by: { $0.transactionCategory.displayName })
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
            biggestCategory: biggestCategory,
            biggestMerchant: biggestMerchant,
            sparklinePoints: sparkline,
            microInsight: change > 0 ? "Spending is up this month" : "Great job keeping costs down"
        )

        let timelineGroups = ExpenseTimelineGrouper.group(allRecords)
        var sections = [ExpenseSectionDisplay]()

        for group in timelineGroups {
            let displayRows = group.records.map { r in
                ExpenseRowDisplay(
                    id: r.id,
                    name: r.name,
                    amount: r.amountDouble,
                    amountFormatted: AppSettingsManager.format(amount: abs(r.amountDouble), currency: currency),
                    date: r.date,
                    category: r.transactionCategory.displayName,
                    merchant: r.merchantName,
                    heatZone: r.heatZoneBucket,
                    habitSignature: r.habitSignatureId,
                    emotion: r.emotion,
                    context: r.contextTag
                )
            }
            sections.append(ExpenseSectionDisplay(
                title: group.section.rawValue,
                microInsight: "\(displayRows.count) transactions",
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
            prediction: "Trending towards \(AppSettingsManager.format(amount: projected, currency: currency)) this month"
        )

        return ExpenseInteractionDisplay(header: header, sections: sections, summary: summary)
    }
}
