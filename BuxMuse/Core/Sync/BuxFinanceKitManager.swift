//
//  BuxFinanceKitManager.swift
//  BuxMuse
//
//  Background synchronization and auto-matching engine for Apple Wallet transactions via FinanceKit.
//

import Foundation
import FinanceKit
import SwiftData
import Combine

public enum FinanceKitImportRange: String, CaseIterable, Identifiable {
    case oneMonth = "1M"
    case threeMonths = "3M"
    case sixMonths = "6M"
    case oneYear = "1Y"
    
    public var id: String { rawValue }
    
    public var monthsCount: Int {
        switch self {
        case .oneMonth: return 1
        case .threeMonths: return 3
        case .sixMonths: return 6
        case .oneYear: return 12
        }
    }
    
    public var displayName: String {
        switch self {
        case .oneMonth: return "1 Month"
        case .threeMonths: return "3 Months"
        case .sixMonths: return "6 Months"
        case .oneYear: return "1 Year"
        }
    }

    public func localizedDisplayName(locale: Locale) -> String {
        BuxLocalizedString.string(displayName, locale: locale)
    }
}

@MainActor
public final class BuxFinanceKitManager: ObservableObject {
    public static let shared = BuxFinanceKitManager()
    
    private let persistence = PersistenceController.shared
    private var isIncrementalSyncRunning = false
    private var automaticSyncTask: Task<Void, Never>?
    private var didScheduleDeferredSessionSync = false
    private var pendingSyncRequest: (startDate: Date, now: Date, isInitial: Bool)?
    private var walletSyncCloudPushIDs = Set<UUID>()
    
    private static let deferredSessionSyncDelay: TimeInterval = 60
    private static let automaticSyncInterval: TimeInterval = 3600

    public static let knownSubscriptionKeywords: Set<String> = [
        // Streaming & Entertainment
        "netflix", "spotify", "hulu", "disney+", "disney plus", "apple.com/bill", "icloud", 
        "youtube premium", "youtubetv", "youtube tv", "prime video", "amazon prime", "hbo max", "hbomax", 
        "paramount+", "paramount plus", "peacock tv", "peacocktv", "crunchyroll", "curiositystream", 
        "curiosity stream", "mubi", "plex", "vimeo", "audible", "twitch", "patreon", "substack", 
        "medium membership", "medium.com", "siriusxm", "sirius xm", "pandora", "deezer", "tidal",
        
        // Gaming
        "playstation plus", "ps plus", "xbox game pass", "game pass", "nintendo switch online", 
        "steam games", "epic games", "ea play", "roblox", "minecraft", "world of warcraft", "blizzard",
        
        // SaaS, Software & Productivity
        "adobe", "creative cloud", "photoshop", "illustrator", "canva", "figma", "sketch", 
        "microsoft 365", "office 365", "zoom.us", "zoom communications", "slack", "dropbox", 
        "google one", "google storage", "github", "gitpod", "openai", "chatgpt", "midjourney", 
        "notion", "evernote", "todoist", "linear", "trello", "asana", "jira", "atlassian", 
        "monday.com", "salesforce", "hubspot", "mailchimp", "squarespace", "wix.com", "shopify", 
        "godaddy", "bluehost", "digitalocean", "aws", "amazon web services", "heroku", "stripe", 
        "quickbooks", "xero", "dashlane", "1password", "lastpass", "nordvpn", "expressvpn", "protonmail",
        
        // News & Media
        "nytimes", "new york times", "washington post", "wash post", "wall street journal", "wsj", 
        "financial times", "ft.com", "the economist", "economist", "bloomberg", "the guardian", 
        "guardian news", "subscribestar", "readly", "pressreader", "scribd", "time magazine",
        
        // Fitness & Health
        "peloton", "strava", "fitbod", "nike training", "apple fitness", "hevy", "myfitnesspal", 
        "calm app", "headspace", "noom", "duolingo", "weight watchers", "ww app", "planet fitness", 
        "equinox", "la fitness", "gold's gym", "ymca", "orangetheory", "classpass", "anytime fitness", 
        "crunch fitness", "lifetime fitness",
        
        // Retail & Delivery
        "walmart+", "walmart plus", "instacart+", "instacart plus", "dashpass", "doordash", 
        "uber one", "grubhub+", "grubhub plus", "shipt", "costco member", "costco", "sams club", "sam's club"
    ]
    
    @Published public private(set) var isSyncing = false
    @Published public private(set) var lastSyncError: String? = nil
    
    private init() {}

    public func clearLastSyncError() {
        lastSyncError = nil
    }
    
    /// User-facing copy when FinanceKit is unavailable on this build or device.
    nonisolated public static let walletDataUnavailableMessage = "Apple Wallet financial data is not available on this device. Confirm FinanceKit is enabled for this app and try again."

    /// User-facing copy when the person declined Wallet access.
    nonisolated public static let walletAuthorizationDeniedMessage = "BuxMuse needs your permission to read Apple Wallet transactions. You can allow access in Settings → Privacy & Security → BuxMuse."

    /// User-facing copy when sync runs without prior authorization.
    nonisolated static let walletAuthorizationRequiredMessage = "Allow Apple Wallet access before BuxMuse can import your transactions."

    nonisolated static func localizedSyncErrorMessage(_ message: String, locale: Locale) -> String {
        let catalogKeys: Set<String> = [
            walletDataUnavailableMessage,
            walletAuthorizationDeniedMessage,
            walletAuthorizationRequiredMessage
        ]
        if catalogKeys.contains(message) {
            return BuxLocalizedString.string(message, locale: locale)
        }
        return message
    }

    /// Requests Apple Wallet/FinanceKit authorization (shows the system consent sheet when needed).
    public func requestAuthorization() async throws -> Bool {
        #if targetEnvironment(simulator)
        // Simulator doesn't support active FinanceKit background store, simulate approval.
        return true
        #else
        guard FinanceStore.isDataAvailable(.financialData) else {
            lastSyncError = Self.walletDataUnavailableMessage
            return false
        }
        let status = try await FinanceStore.shared.requestAuthorization()
        let authorized = status == .authorized
        if !authorized {
            lastSyncError = Self.walletAuthorizationDeniedMessage
        } else {
            lastSyncError = nil
        }
        return authorized
        #endif
    }

    /// Returns true only when FinanceKit is authorized. Prompts when `promptIfNeeded` and access has not been granted yet.
    public func ensureAuthorizedForWalletAccess(promptIfNeeded: Bool = true) async -> Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        guard FinanceStore.isDataAvailable(.financialData) else {
            lastSyncError = Self.walletDataUnavailableMessage
            return false
        }
        if (try? await checkAuthorizationStatus()) == true {
            lastSyncError = nil
            return true
        }
        guard promptIfNeeded else { return false }
        do {
            return try await requestAuthorization()
        } catch {
            lastSyncError = error.localizedDescription
            return false
        }
        #endif
    }
    
    /// Checks the current authorization status.
    public func checkAuthorizationStatus() async throws -> Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        guard FinanceStore.isDataAvailable(.financialData) else {
            return false
        }
        let status = try await FinanceStore.shared.authorizationStatus()
        return status == .authorized
        #endif
    }

    /// Home hero balance — live FinanceKit balance for the main asset account in this currency.
    public func fetchHeroBalance(currencyCode: String) async -> Decimal? {
        #if targetEnvironment(simulator)
        return nil
        #else
        guard SettingsStore.shared.appleWalletSyncEnabled else { return nil }
        guard FinanceStore.isDataAvailable(.financialData) else { return nil }
        guard (try? await checkAuthorizationStatus()) == true else { return nil }

        do {
            let store = FinanceStore.shared
            let accountQuery = AccountQuery(
                sortDescriptors: [],
                predicate: nil,
                limit: nil,
                offset: nil
            )
            let accounts = try await store.accounts(query: accountQuery)
            let assetAccounts = accounts.filter { account in
                guard case .asset = account else { return false }
                return account.currencyCode.caseInsensitiveCompare(currencyCode) == .orderedSame
            }
            guard !assetAccounts.isEmpty else { return nil }

            var ranked: [(Decimal)] = []
            for account in assetAccounts {
                if let balance = try await Self.fetchBalance(for: account.id, store: store) {
                    ranked.append(balance)
                }
            }
            return ranked.max()
        } catch {
            return nil
        }
        #endif
    }

    #if !targetEnvironment(simulator)
    private static func fetchBalance(for accountID: UUID, store: FinanceStore) async throws -> Decimal? {
        let balancePredicate = #Predicate<AccountBalance> { balance in
            balance.accountID == accountID
        }
        let balanceQuery = AccountBalanceQuery(
            sortDescriptors: [SortDescriptor(\AccountBalance.id, order: .reverse)],
            predicate: balancePredicate,
            limit: 1,
            offset: nil
        )
        guard let latest = try await store.accountBalances(query: balanceQuery).first else { return nil }
        return decimalAmount(from: latest)
    }

    private static func decimalAmount(from balance: AccountBalance) -> Decimal {
        switch balance.currentBalance {
        case .available(let walletBalance):
            return walletBalance.amount.amount
        case .booked(let walletBalance):
            return walletBalance.amount.amount
        case .availableAndBooked(available: let available, booked: _):
            return available.amount.amount
        @unknown default:
            return 0
        }
    }
    #endif
    
    /// Manual historical import from the Wallet sheet.
    public func syncTransactions(range: FinanceKitImportRange) async {
        let calendar = Calendar.current
        let now = Date()
        guard let startDate = calendar.date(byAdding: .month, value: -range.monthsCount, to: now) else {
            return
        }
        await performSync(since: startDate, now: now, isInitialHistoricalImport: true)
    }
    
    /// Manual incremental sync — Expenses menu / pull-to-refresh. Does not require auto-sync toggle.
    public func syncWalletNow() async {
        guard SettingsStore.shared.appleWalletSyncEnabled else { return }
        guard await ensureAuthorizedForWalletAccess() else { return }
        migrateWalletInitialSyncStateIfNeeded()
        await runIncrementalSync()
    }

    /// One deferred auto-sync per app session so hero animations can settle first.
    public func scheduleDeferredSessionSyncIfNeeded() {
        guard !didScheduleDeferredSessionSync else { return }
        guard SettingsStore.shared.appleWalletSyncEnabled,
              SettingsStore.shared.appleWalletAutoSyncEnabled else { return }
        migrateWalletInitialSyncStateIfNeeded()
        guard SettingsStore.shared.appleWalletInitialSyncCompleted else { return }

        didScheduleDeferredSessionSync = true
        Task {
            try? await Task.sleep(for: .seconds(Self.deferredSessionSyncDelay))
            await triggerBackgroundAutoSync()
        }
    }

    /// Call when the app returns to .active from background to allow the deferred sync to fire again.
    public func resetSessionSyncFlag() {
        didScheduleDeferredSessionSync = false
    }

    private func runIncrementalSync() async {
        guard !isIncrementalSyncRunning else { return }

        isIncrementalSyncRunning = true
        defer { isIncrementalSyncRunning = false }

        if !UserDefaults.standard.bool(forKey: Self.walletReconcileMigrationKey) {
            _ = try? persistence.reconcileWalletImports()
            UserDefaults.standard.set(true, forKey: Self.walletReconcileMigrationKey)
        }

        let now = Date()
        let startDate = incrementalSyncStartDate(relativeTo: now)
        await performSync(since: startDate, now: now, isInitialHistoricalImport: false)
    }

    /// Foreground / background incremental fetch for new Wallet transactions.
    public func triggerBackgroundAutoSync() async {
        guard SettingsStore.shared.appleWalletSyncEnabled else { return }
        migrateWalletAutoSyncDefaultIfNeeded()
        guard SettingsStore.shared.appleWalletAutoSyncEnabled else { return }
        migrateWalletInitialSyncStateIfNeeded()
        guard SettingsStore.shared.appleWalletInitialSyncCompleted else { return }
        await runIncrementalSync()
    }

    /// Hourly auto-sync loop only — no sync on scheduler start (session defer handles launch).
    public func beginAutomaticSyncIfConfigured() {
        guard SettingsStore.shared.appleWalletSyncEnabled,
              SettingsStore.shared.appleWalletAutoSyncEnabled else {
            stopAutomaticSyncScheduler()
            return
        }
        guard automaticSyncTask == nil else { return }

        automaticSyncTask = Task { [weak self] in
            defer { self?.automaticSyncTask = nil }
            await self?.runPeriodicIncrementalSyncLoop()
        }
    }

    public func stopAutomaticSyncScheduler() {
        automaticSyncTask?.cancel()
        automaticSyncTask = nil
    }

    private func runPeriodicIncrementalSyncLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(Self.automaticSyncInterval))
            guard !Task.isCancelled else { return }
            await triggerBackgroundAutoSync()
        }
    }

    private static let walletReconcileMigrationKey = "buxmuse.applewallet.reconcile.v5"
    private static let autoSyncDefaultMigrationKey = "buxmuse.applewallet.autosync.default.v1"

    /// Wallet sync should pull new transactions automatically once enabled — default auto-sync on for existing users.
    private func migrateWalletAutoSyncDefaultIfNeeded() {
        guard SettingsStore.shared.appleWalletSyncEnabled else { return }
        guard !UserDefaults.standard.bool(forKey: Self.autoSyncDefaultMigrationKey) else { return }
        if !SettingsStore.shared.appleWalletAutoSyncEnabled {
            SettingsStore.shared.appleWalletAutoSyncEnabled = true
        }
        UserDefaults.standard.set(true, forKey: Self.autoSyncDefaultMigrationKey)
    }

    private func migrateWalletInitialSyncStateIfNeeded() {
        guard !SettingsStore.shared.appleWalletInitialSyncCompleted else { return }
        guard (try? persistence.hasFinanceKitImportedExpenses()) == true else { return }
        SettingsStore.shared.appleWalletInitialSyncCompleted = true
        if SettingsStore.shared.appleWalletLastSyncDate == nil {
            SettingsStore.shared.appleWalletLastSyncDate = Date()
        }
    }
    
    private func incrementalSyncStartDate(relativeTo now: Date) -> Date {
        let calendar = Calendar.current
        if let lastSync = SettingsStore.shared.appleWalletLastSyncDate {
            return calendar.date(byAdding: .day, value: -7, to: lastSync) ?? lastSync
        }
        return calendar.date(byAdding: .month, value: -1, to: now) ?? now
    }

    private func performSync(since startDate: Date, now: Date, isInitialHistoricalImport: Bool) async {
        guard !isSyncing else {
            pendingSyncRequest = (startDate, now, isInitialHistoricalImport)
            return
        }

        isSyncing = true
        lastSyncError = nil
        walletSyncCloudPushIDs.removeAll()
        
        try? await Task.sleep(for: .milliseconds(isInitialHistoricalImport ? 600 : 0))
        
        do {
            let isAuthorized = try await checkAuthorizationStatus()

            #if targetEnvironment(simulator)
            try await importMockTransactions(since: startDate, now: now)
            #else
            guard isAuthorized else {
                if isInitialHistoricalImport {
                    lastSyncError = Self.walletAuthorizationRequiredMessage
                }
                isSyncing = false
                if let queued = pendingSyncRequest {
                    pendingSyncRequest = nil
                    await performSync(since: queued.startDate, now: queued.now, isInitialHistoricalImport: queued.isInitial)
                }
                return
            }
            try await importRealTransactions(since: startDate, now: now)
            #endif

            SettingsStore.shared.appleWalletLastSyncDate = now
            if isInitialHistoricalImport {
                SettingsStore.shared.appleWalletInitialSyncCompleted = true
                SettingsStore.shared.appleWalletAutoSyncEnabled = true
                _ = try persistence.reconcileWalletImports()
            }

            await flushWalletExpensesToCloud()
            NotificationCenter.default.post(name: .buxMuseWalletSyncDidComplete, object: nil)
        } catch {
            lastSyncError = error.localizedDescription
        }
        
        isSyncing = false
        
        if let queued = pendingSyncRequest {
            pendingSyncRequest = nil
            await performSync(since: queued.startDate, now: queued.now, isInitialHistoricalImport: queued.isInitial)
        }
    }
    
    /// Real Apple Wallet transaction fetch using FinanceStore.
    private func importRealTransactions(since startDate: Date, now: Date) async throws {
        let store = FinanceStore.shared
        
        let queryPredicate = #Predicate<FinanceKit.Transaction> { transaction in
            transaction.transactionDate >= startDate && transaction.transactionDate <= now
        }
        
        let query = TransactionQuery(
            sortDescriptors: [SortDescriptor(\FinanceKit.Transaction.transactionDate, order: .reverse)],
            predicate: queryPredicate,
            limit: nil,
            offset: nil
        )
        
        let walletTransactions = try await store.transactions(query: query)
        var merchantContexts = try persistence.buildWalletMerchantContexts()

        for tx in walletTransactions {
            _ = try upsertWalletTransaction(tx, now: now, merchantContexts: &merchantContexts)
        }

        _ = try await importOpenWalletTransactions(now: now, merchantContexts: &merchantContexts)
        _ = try await refreshTrackedPendingWalletTransactions(now: now, merchantContexts: &merchantContexts)
        _ = try? persistence.reconcileWalletImports()
    }

    /// Pulls all open (pending/authorized) Wallet transactions regardless of last sync window.
    private func importOpenWalletTransactions(
        now: Date,
        merchantContexts: inout [WalletMerchantContext]
    ) async throws -> Bool {
        let store = FinanceStore.shared
        let statusPredicate = TransactionQuery.predicate(forStatuses: [.pending, .authorized])
        let query = TransactionQuery(
            sortDescriptors: [SortDescriptor(\FinanceKit.Transaction.transactionDate, order: .reverse)],
            predicate: statusPredicate,
            limit: nil,
            offset: nil
        )
        let openTransactions = try await store.transactions(query: query)
        var didWrite = false
        for tx in openTransactions {
            if try upsertWalletTransaction(tx, now: now, merchantContexts: &merchantContexts) {
                didWrite = true
            }
        }
        return didWrite
    }

    /// Re-fetches Wallet rows we still treat as pending so cleared charges move into the booked ledger.
    private func refreshTrackedPendingWalletTransactions(
        now: Date,
        merchantContexts: inout [WalletMerchantContext]
    ) async throws -> Bool {
        let pendingRecords = try persistence.fetchPendingWalletExpenseRecords()
        guard !pendingRecords.isEmpty else { return false }

        #if targetEnvironment(simulator)
        return false
        #else
        let store = FinanceStore.shared
        var didWrite = false
        var stalePendingIDsToRemove: [UUID] = []
        var absentPendingToResolve: [ExpenseRecord] = []

        for record in pendingRecords {
            var fetchedById: FinanceKit.Transaction?
            if let financeKitId = record.financeKitTransactionId,
               let uuid = UUID(uuidString: financeKitId) {
                fetchedById = try await fetchFinanceKitTransaction(id: uuid, store: store)
            }

            if let tx = fetchedById {
                if try upsertWalletTransaction(tx, now: now, merchantContexts: &merchantContexts) {
                    didWrite = true
                }
                if !financeKitTransactionIsPending(tx) {
                    continue
                }
            }

            if let tx = try await findBookedWalletTransactionMatch(for: record, store: store),
               try applyWalletUpdateToPendingRecord(
                record,
                tx: tx,
                now: now,
                merchantContexts: &merchantContexts,
                stalePendingIDsToRemove: &stalePendingIDsToRemove
               ) {
                didWrite = true
                continue
            }

            if fetchedById == nil, record.financeKitTransactionId != nil {
                absentPendingToResolve.append(record)
            }
        }

        for record in absentPendingToResolve {
            if try resolveAbsentPendingWalletRecord(record, now: now) {
                didWrite = true
            }
        }

        for id in Set(stalePendingIDsToRemove) {
            if try removeWalletReconciledExpense(id: id) {
                didWrite = true
            }
        }

        return didWrite
        #endif
    }

    #if !targetEnvironment(simulator)
    private func fetchFinanceKitTransaction(id: UUID, store: FinanceStore) async throws -> FinanceKit.Transaction? {
        let idPredicate = #Predicate<FinanceKit.Transaction> { $0.id == id }
        let query = TransactionQuery(
            sortDescriptors: [],
            predicate: idPredicate,
            limit: 1,
            offset: nil
        )
        return try await store.transactions(query: query).first
    }

    private func findBookedWalletTransactionMatch(
        for record: ExpenseRecord,
        store: FinanceStore
    ) async throws -> FinanceKit.Transaction? {
        let calendar = Calendar.current
        let windowStart = calendar.date(byAdding: .day, value: -7, to: record.date) ?? record.date
        let windowEnd = calendar.date(byAdding: .day, value: 7, to: record.date) ?? record.date
        let start = windowStart
        let end = windowEnd

        let predicate = #Predicate<FinanceKit.Transaction> { tx in
            tx.transactionDate >= start && tx.transactionDate <= end
        }
        let query = TransactionQuery(
            sortDescriptors: [SortDescriptor(\FinanceKit.Transaction.transactionDate, order: .reverse)],
            predicate: predicate,
            limit: 100,
            offset: nil
        )
        let candidates = try await store.transactions(query: query)
        let recordAmount = abs(record.amountValue)
        let merchantKey = record.merchantName.lowercased()

        return candidates.first { tx in
            guard !financeKitTransactionIsPending(tx) else { return false }
            let txAmount = abs(alignedAmount(for: tx))
            guard walletAmountsApproximatelyEqual(recordAmount, txAmount) else { return false }
            let txLabel = (tx.merchantName ?? tx.transactionDescription).lowercased()
            return walletMerchantLabelsMatch(recordMerchant: merchantKey, financeKitLabel: txLabel)
        }
    }
    #endif

    @discardableResult
    private func applyWalletUpdateToPendingRecord(
        _ record: ExpenseRecord,
        tx: FinanceKit.Transaction,
        now: Date,
        merchantContexts: inout [WalletMerchantContext],
        stalePendingIDsToRemove: inout [UUID]
    ) throws -> Bool {
        if let existing = try persistence.fetchExpenseRecordByFinanceKitId(tx.id.uuidString),
           existing.id != record.id {
            _ = try upsertWalletTransaction(tx, now: now, merchantContexts: &merchantContexts)
            stalePendingIDsToRemove.append(record.id)
            return true
        }

        var existing = record
        let snapshotChanged = applyWalletTransactionSnapshot(to: &existing, tx: tx, now: now)
        let linkChanged = existing.financeKitTransactionId != tx.id.uuidString
        if linkChanged {
            existing.financeKitTransactionId = tx.id.uuidString
        }

        let classificationChanged = try refreshWalletClassificationIfNeeded(
            on: &existing,
            tx: tx,
            merchantContexts: &merchantContexts,
            now: now
        )
        guard snapshotChanged || linkChanged || classificationChanged else { return false }

        existing.updatedAt = now
        _ = try persistWalletExpense(existing)
        return true
    }

    /// Clears the pending badge when FinanceKit no longer exposes that hold and no booked match exists.
    private func resolveAbsentPendingWalletRecord(_ record: ExpenseRecord, now: Date) throws -> Bool {
        guard record.walletIsPending else { return false }
        var updated = record
        updated.walletIsPending = false
        updated.updatedAt = now
        _ = try persistWalletExpense(updated)
        return true
    }

    @discardableResult
    private func removeWalletReconciledExpense(id: UUID) throws -> Bool {
        try persistence.deleteExpenseRecord(id: id)
        return true
    }

    private func walletAmountsApproximatelyEqual(_ lhs: Decimal, _ rhs: Decimal, tolerance: Decimal = 0.02) -> Bool {
        abs(lhs - rhs) <= tolerance
    }

    private func walletMerchantLabelsMatch(recordMerchant: String, financeKitLabel: String) -> Bool {
        let left = recordMerchant.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let right = financeKitLabel.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !left.isEmpty, !right.isEmpty else { return true }
        return left.contains(right) || right.contains(left)
    }

    private func financeKitTransactionIsPending(_ tx: FinanceKit.Transaction) -> Bool {
        switch tx.status {
        case .pending, .authorized:
            return true
        default:
            return false
        }
    }

    private func alignedAmount(for tx: FinanceKit.Transaction) -> Decimal {
        let rawAmount = tx.transactionAmount.amount
        let decimalAmount = NSDecimalNumber(decimal: rawAmount).decimalValue
        if tx.creditDebitIndicator == .credit {
            return abs(decimalAmount)
        }
        return -abs(decimalAmount)
    }

    @discardableResult
    private func persistWalletExpense(_ record: ExpenseRecord) throws -> ExpenseRecord {
        let saved = try persistence.upsertExpenseRecord(record)
        walletSyncCloudPushIDs.insert(saved.id)
        return saved
    }

    private func flushWalletExpensesToCloud() async {
        guard !walletSyncCloudPushIDs.isEmpty else { return }
        let ids = walletSyncCloudPushIDs
        walletSyncCloudPushIDs.removeAll()
        let records: [ExpenseRecord] = ids.compactMap { try? persistence.fetchExpenseRecord(id: $0) }
        await PersonalCloudSyncEngine.shared.pushExpenses(records)
    }

    @discardableResult
    private func upsertWalletTransaction(
        _ tx: FinanceKit.Transaction,
        now: Date,
        merchantContexts: inout [WalletMerchantContext]
    ) throws -> Bool {
        let txId = tx.id.uuidString
        let currency = tx.transactionAmount.currencyCode

        if var existing = try persistence.fetchExpenseRecordByFinanceKitId(txId) {
            let snapshotChanged = applyWalletTransactionSnapshot(to: &existing, tx: tx, now: now)
            let classificationChanged = try refreshWalletClassificationIfNeeded(
                on: &existing,
                tx: tx,
                merchantContexts: &merchantContexts,
                now: now
            )
            guard snapshotChanged || classificationChanged else { return false }

            existing.updatedAt = now
            _ = try persistWalletExpense(existing)
            return true
        }

        guard let classification = try WalletTransactionClassifier.classify(
            tx: tx,
            merchantContexts: merchantContexts,
            userMemoryLookup: walletUserMemoryLookup()
        ) else { return false }

        let category = classification.category
        let isSubscriptionLike = detectSubscriptionLike(
            name: classification.displayName,
            category: category,
            transactionType: tx.transactionType
        )
        
        var record = ExpenseRecord(
            name: classification.displayName,
            amountValue: alignedAmount(for: tx),
            currencyCode: currency,
            categoryId: nil,
            merchantId: nil,
            date: tx.postedDate ?? tx.transactionDate,
            notes: WalletStatementIntelligence.walletImportNotes(rawLabel: classification.rawLabel),
            isRecurring: isSubscriptionLike,
            isSubscriptionLike: isSubscriptionLike,
            createdAt: now,
            updatedAt: now,
            categoryRaw: category.rawValue,
            merchantName: classification.displayName,
            walletIsPending: financeKitTransactionIsPending(tx),
            walletCategoryConfidence: classification.decision.confidence.persistedRaw
        )
        record.financeKitTransactionId = txId
        
        if isSubscriptionLike {
            record.nextExpectedDate = Calendar.current.date(byAdding: .month, value: 1, to: record.date)
        }

        record.categoryId = try persistence.categoryId(for: category)
        _ = applyWalletIncomeClassification(to: &record, alignedAmount: record.amountValue)
        if let merchant = try persistence.resolveWalletImportedMerchant(
            resolution: classification.resolution,
            rawStatementLabel: classification.rawLabel
        ) {
            record.merchantId = merchant.id
            merchantContexts = upsertContext(
                merchantContexts,
                merchant: merchant,
                rawLabel: classification.rawLabel,
                canonicalName: classification.displayName
            )
        }
        
        _ = try persistWalletExpense(record)
        return true
    }

    private func walletUserMemoryLookup() -> (String, String?) throws -> TransactionCategory? {
        { [persistence] merchantName, walletRawLabel in
            try persistence.walletMerchantCategoryMemory(
                merchantName: merchantName,
                walletRawLabel: walletRawLabel
            )
        }
    }

    @discardableResult
    private func applyWalletTransactionSnapshot(
        to record: inout ExpenseRecord,
        tx: FinanceKit.Transaction,
        now: Date
    ) -> Bool {
        let isPending = financeKitTransactionIsPending(tx)
        let alignedAmount = alignedAmount(for: tx)
        let date = tx.postedDate ?? tx.transactionDate
        var changed = false
        if record.walletIsPending != isPending {
            record.walletIsPending = isPending
            changed = true
        }
        if record.amountValue != alignedAmount {
            record.amountValue = alignedAmount
            changed = true
        }
        if abs(record.date.timeIntervalSince(date)) > 1 {
            record.date = date
            changed = true
        }
        if applyWalletIncomeClassification(to: &record, alignedAmount: alignedAmount) {
            changed = true
        }
        _ = now
        return changed
    }

    @discardableResult
    private func refreshWalletClassificationIfNeeded(
        on record: inout ExpenseRecord,
        tx: FinanceKit.Transaction,
        merchantContexts: inout [WalletMerchantContext],
        now: Date
    ) throws -> Bool {
        guard let classification = try WalletTransactionClassifier.classify(
            tx: tx,
            merchantContexts: merchantContexts,
            userMemoryLookup: walletUserMemoryLookup()
        ) else { return false }

        var changed = false
        let importNotes = WalletStatementIntelligence.walletImportNotes(rawLabel: classification.rawLabel)
        if record.notes != importNotes {
            record.notes = importNotes
            changed = true
        }
        if record.name != classification.displayName {
            record.name = classification.displayName
            changed = true
        }
        if record.merchantName != classification.displayName {
            record.merchantName = classification.displayName
            changed = true
        }

        if WalletTransactionClassifier.shouldRefreshCategory(
            existing: WalletCategoryRefreshSnapshot(record: record),
            classification: classification
        ) {
            let category = classification.category
            if record.transactionCategory != category {
                record.categoryRaw = category.rawValue
                record.categoryId = try persistence.categoryId(for: category)
                changed = true
            }
            let confidence = classification.decision.confidence.persistedRaw
            if record.walletCategoryConfidence != confidence {
                record.walletCategoryConfidence = confidence
                changed = true
            }
            let subscriptionLike = detectSubscriptionLike(
                name: classification.displayName,
                category: category,
                transactionType: tx.transactionType
            )
            if record.isSubscriptionLike != subscriptionLike {
                record.isSubscriptionLike = subscriptionLike
                changed = true
            }
            if record.isRecurring != subscriptionLike {
                record.isRecurring = subscriptionLike
                changed = true
            }
        }

        if let merchant = try persistence.resolveWalletImportedMerchant(
            resolution: classification.resolution,
            rawStatementLabel: classification.rawLabel
        ) {
            if record.merchantId != merchant.id {
                record.merchantId = merchant.id
                changed = true
            }
            merchantContexts = upsertContext(
                merchantContexts,
                merchant: merchant,
                rawLabel: classification.rawLabel,
                canonicalName: classification.displayName
            )
        }

        _ = now
        return changed
    }

    private func upsertContext(
        _ contexts: [WalletMerchantContext],
        merchant: ExpenseMerchantRecord,
        rawLabel: String,
        canonicalName: String
    ) -> [WalletMerchantContext] {
        var updated = contexts
        let domain = merchant.logoURL.flatMap { MerchantLogoEngine.domain(fromStoredLogoURL: $0) }
        if let index = updated.firstIndex(where: { $0.id == merchant.id }) {
            var labels = Set(updated[index].statementLabels)
            labels.insert(rawLabel)
            labels.insert(canonicalName)
            updated[index] = WalletMerchantContext(
                id: merchant.id,
                displayName: merchant.name,
                normalizedName: merchant.normalizedName,
                domain: domain,
                statementLabels: Array(labels)
            )
        } else {
            updated.append(
                WalletMerchantContext(
                    id: merchant.id,
                    displayName: merchant.name,
                    normalizedName: merchant.normalizedName,
                    domain: domain,
                    statementLabels: [rawLabel, canonicalName]
                )
            )
        }
        return updated
    }
    
    /// Re-add paycheck auto-tag on Wallet credit imports (not part of backup, kept intentionally).
    @discardableResult
    private func applyWalletIncomeClassification(to record: inout ExpenseRecord, alignedAmount: Decimal) -> Bool {
        guard alignedAmount > 0 else { return false }
        var changed = false
        if record.transactionCategory != .income {
            record.categoryRaw = TransactionCategory.income.rawValue
            record.categoryId = try? persistence.categoryId(for: .income)
            changed = true
        }
        if SalaryPayrollMatcher.applyAutoTagIfMatched(
            &record,
            profile: SettingsStore.shared.salaryPayProfile,
            weekStartDay: SettingsStore.shared.weekStartDay
        ) {
            changed = true
        }
        return changed
    }

    private func detectSubscriptionLike(name: String, category: TransactionCategory, transactionType: FinanceKit.TransactionType? = nil) -> Bool {
        if let type = transactionType {
            if type == .transfer || type == .standingOrder || type == .atm {
                return false
            }
        }
        if category == .subscriptions { return true }
        let lower = name.lowercased()
        return Self.knownSubscriptionKeywords.contains(where: { lower.contains($0) })
    }
    
    private func importMockTransactions(since startDate: Date, now: Date) async throws {
        struct MockTx {
            let id: String
            let name: String
            let amount: Decimal
            let category: TransactionCategory
            let daysAgo: Int
            let isPending: Bool
        }
        
        let mockData = [
            MockTx(id: "mock_wallet_001", name: "Starbucks Coffee", amount: -6.80, category: .restaurants, daysAgo: 0, isPending: true),
            MockTx(id: "mock_wallet_002", name: "Whole Foods Market", amount: -84.20, category: .groceries, daysAgo: 1, isPending: false),
            MockTx(id: "mock_wallet_003", name: "Uber Ride", amount: -22.50, category: .transport, daysAgo: 1, isPending: true),
            MockTx(id: "mock_wallet_004", name: "Apple.com/Bill iCloud", amount: -2.99, category: .subscriptions, daysAgo: 3, isPending: false),
            MockTx(id: "mock_wallet_005", name: "Netflix Subscription", amount: -15.49, category: .subscriptions, daysAgo: 5, isPending: false),
            MockTx(id: "mock_wallet_006", name: "Chevron Gas Station", amount: -48.00, category: .transport, daysAgo: 8, isPending: false),
            MockTx(id: "mock_wallet_007", name: "Target Store", amount: -35.60, category: .shopping, daysAgo: 12, isPending: false),
            MockTx(id: "mock_wallet_008", name: "Salary Payout", amount: 2850.00, category: .income, daysAgo: 15, isPending: false),
            MockTx(id: "mock_wallet_009", name: "Trader Joe's", amount: -62.15, category: .groceries, daysAgo: 18, isPending: false),
            MockTx(id: "mock_wallet_010", name: "Apple Card Cashback", amount: 14.25, category: .income, daysAgo: 20, isPending: false),
            MockTx(id: "mock_wallet_011", name: "Sweetgreen", amount: -16.40, category: .restaurants, daysAgo: 22, isPending: false),
            MockTx(id: "mock_wallet_012", name: "App Store Subscription", amount: -9.99, category: .subscriptions, daysAgo: 26, isPending: false),
            MockTx(id: "mock_wallet_013", name: "PAYPAL PAYMENT", amount: -42.00, category: .shopping, daysAgo: 4, isPending: true),
            MockTx(id: "mock_wallet_014", name: "WWW.VOXI.COM", amount: -15.00, category: .subscriptions, daysAgo: 6, isPending: false),
            MockTx(id: "mock_wallet_015", name: "GOOGLE ONE", amount: -1.99, category: .subscriptions, daysAgo: 9, isPending: false),
            MockTx(id: "mock_wallet_016", name: "ChatGPT Plus", amount: -20.00, category: .subscriptions, daysAgo: 35, isPending: false),
            MockTx(id: "mock_wallet_017", name: "Amazon Retail", amount: -128.40, category: .shopping, daysAgo: 45, isPending: false),
            MockTx(id: "mock_wallet_018", name: "Equinox Gym", amount: -180.00, category: .entertainment, daysAgo: 50, isPending: false),
            MockTx(id: "mock_wallet_019", name: "Electric Utility Bill", amount: -95.20, category: .utilities, daysAgo: 65, isPending: false),
            MockTx(id: "mock_wallet_020", name: "Housing Rent Payment", amount: -1350.00, category: .housing, daysAgo: 92, isPending: false),
            MockTx(id: "mock_wallet_021", name: "Airbnb Travel Booking", amount: -480.00, category: .travel, daysAgo: 120, isPending: false),
            MockTx(id: "mock_wallet_022", name: "Harvard Online Course", amount: -250.00, category: .education, daysAgo: 180, isPending: false),
            MockTx(id: "mock_wallet_023", name: "CVS Pharmacy", amount: -32.80, category: .health, daysAgo: 200, isPending: false),
            MockTx(id: "mock_wallet_024", name: "Delta Airlines", amount: -380.00, category: .travel, daysAgo: 270, isPending: false)
        ]
        
        let calendar = Calendar.current
        var merchantContexts = try persistence.buildWalletMerchantContexts()
        
        for mock in mockData {
            guard let txDate = calendar.date(byAdding: .day, value: -mock.daysAgo, to: now) else { continue }
            guard txDate >= startDate else { continue }

            if var existing = try persistence.fetchExpenseRecordByFinanceKitId(mock.id) {
                let pendingChanged = existing.walletIsPending != mock.isPending
                let amountChanged = existing.amountValue != mock.amount
                guard pendingChanged || amountChanged else { continue }
                existing.walletIsPending = mock.isPending
                existing.amountValue = mock.amount
                existing.updatedAt = now
                _ = try persistWalletExpense(existing)
                continue
            }
            
            let resolution = WalletStatementIntelligence.resolve(
                rawLabel: mock.name,
                contexts: merchantContexts
            )
            let displayName = resolution.canonicalName.isEmpty ? mock.name : resolution.canonicalName
            let isSubscriptionLike = detectSubscriptionLike(name: displayName, category: mock.category)
            
            var record = ExpenseRecord(
                name: displayName,
                amountValue: mock.amount,
                currencyCode: "USD",
                categoryId: nil,
                merchantId: nil,
                date: txDate,
                notes: WalletStatementIntelligence.walletImportNotes(rawLabel: mock.name),
                isRecurring: isSubscriptionLike,
                isSubscriptionLike: isSubscriptionLike,
                createdAt: now,
                updatedAt: now,
                categoryRaw: mock.category.rawValue,
                merchantName: displayName,
                walletIsPending: mock.isPending
            )
            record.financeKitTransactionId = mock.id
            
            record.categoryId = try persistence.categoryId(for: mock.category)
            if let merchant = try persistence.resolveWalletImportedMerchant(
                resolution: resolution,
                rawStatementLabel: mock.name
            ) {
                record.merchantId = merchant.id
                merchantContexts = upsertContext(
                    merchantContexts,
                    merchant: merchant,
                    rawLabel: mock.name,
                    canonicalName: displayName
                )
            }
            
            _ = try persistWalletExpense(record)
        }
    }
}
