//
//  PersistenceController.swift
//  BuxMuse
//
//  SwiftData persistence — local-only, async APIs.
//

import Foundation
import SwiftData
import Combine

@MainActor
public final class PersistenceController: ObservableObject {
    public static let shared = PersistenceController()

    public let container: ModelContainer
    /// App-wide main-queue context (`container.mainContext`). Never use from background queues.
    public private(set) var context: ModelContext
    /// Set when we had to fall back to in-memory or recovery store — UI can surface a one-time notice.
    @Published public private(set) var lastBootstrapIssue: String?

    public var didRunSeedAndMigration = false

    /// Bumped when SwiftData models change incompatibly (avoids loadIssueModelContainer on old stores).
    static let storeName = PersistenceStoreMigration.activeStoreName

    public init(inMemory: Bool = false, customStoreName: String? = nil) {
        let schema = Self.makeSchema()
        let targetStoreName = customStoreName ?? Self.storeName

        let bootstrap: BootstrapResult
        if inMemory {
            bootstrap = Self.bootstrapInMemory(schema: schema, storeName: targetStoreName)
        } else {
            bootstrap = Self.bootstrapOnDisk(schema: schema, storeName: targetStoreName)
        }

        container = bootstrap.container
        context = container.mainContext
        context.autosaveEnabled = false
        lastBootstrapIssue = bootstrap.issueMessage

        if bootstrap.shouldAttemptMigration {
            PersistenceStoreMigration.migrateIfNeeded(into: self)
        }
    }

    private struct BootstrapResult {
        let container: ModelContainer
        let issueMessage: String?
        let shouldAttemptMigration: Bool
    }

    private static func makeSchema() -> Schema {
        Schema([
            ExpenseEntity.self,
            ExpenseSplitLineEntity.self,
            DebtEntity.self,
            DebtPaymentEntity.self,
            GoalEntity.self,
            ContributionEntity.self,
            InsightEntity.self,
            MerchantEntity.self,
            CategoryEntity.self,
            PatternEntity.self,
            BillingCycleEntity.self,
            BaselineEntity.self,
            OverspendEntity.self,
            SavingsOpportunityEntity.self,
            SubscriptionEntity.self,
            UserPreferencesEntity.self,
            ThemeEntity.self
        ])
    }

    /// Local SQLite only — never SwiftData CloudKit (personal/household sync uses CK APIs directly).
    static func localConfiguration(
        _ name: String,
        schema: Schema,
        url: URL? = nil,
        isStoredInMemoryOnly: Bool = false,
        allowsSave: Bool = true
    ) -> ModelConfiguration {
        if isStoredInMemoryOnly {
            return ModelConfiguration(
                name,
                schema: schema,
                isStoredInMemoryOnly: true,
                cloudKitDatabase: .none
            )
        }
        if let url {
            return ModelConfiguration(
                name,
                schema: schema,
                url: url,
                allowsSave: allowsSave,
                cloudKitDatabase: .none
            )
        }
        return ModelConfiguration(name, schema: schema, cloudKitDatabase: .none)
    }

    private static func bootstrapInMemory(schema: Schema, storeName: String) -> BootstrapResult {
        let config = localConfiguration(
            "\(storeName)_\(UUID().uuidString)",
            schema: schema,
            isStoredInMemoryOnly: true
        )
        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            return BootstrapResult(container: container, issueMessage: nil, shouldAttemptMigration: false)
        } catch {
            print("SwiftData: in-memory container failed: \(error)")
            let fallback = localConfiguration("fallback_memory", schema: schema, isStoredInMemoryOnly: true)
            guard let container = try? ModelContainer(for: schema, configurations: [fallback]) else {
                fatalError("SwiftData could not create any local container: \(error)")
            }
            return BootstrapResult(
                container: container,
                issueMessage: "Using temporary in-memory storage.",
                shouldAttemptMigration: false
            )
        }
    }

    private static func bootstrapOnDisk(schema: Schema, storeName: String) -> BootstrapResult {
        let supportURL = applicationSupportURL()
        let storeURL = makeStoreURL(for: storeName, in: supportURL)
        let config = localConfiguration(storeName, schema: schema, url: storeURL)

        if let container = try? ModelContainer(for: schema, configurations: [config]) {
            return BootstrapResult(container: container, issueMessage: nil, shouldAttemptMigration: true)
        }

        let legacyHasData = PersistenceStoreMigration.legacyStoresContainData(excludingStoreName: storeName)
        if legacyHasData {
            print("SwiftData: \(storeName) failed to open but legacy data exists — recreating target store only (legacy files preserved).")
        } else {
            print("SwiftData: primary store load failed for \(storeName). Removing store artifacts and retrying.")
        }
        removeAllStoreArtifacts(forBaseName: storeName, in: supportURL)

        if let container = try? ModelContainer(for: schema, configurations: [config]) {
            return BootstrapResult(
                container: container,
                issueMessage: legacyHasData
                    ? "Restored local database shell; importing your previous data…"
                    : "Local database was reset after an update.",
                shouldAttemptMigration: true
            )
        }

        let recoveryName = "\(storeName)_recovery"
        let recoveryURL = makeStoreURL(for: recoveryName, in: supportURL)
        removeAllStoreArtifacts(forBaseName: recoveryName, in: supportURL)
        let recoveryConfig = localConfiguration(recoveryName, schema: schema, url: recoveryURL)

        if let container = try? ModelContainer(for: schema, configurations: [recoveryConfig]) {
            return BootstrapResult(
                container: container,
                issueMessage: "Recovered using a fresh database file.",
                shouldAttemptMigration: true
            )
        }

        print("SwiftData: disk bootstrap failed for \(storeName). Falling back to in-memory store.")
        let memoryConfig = localConfiguration(
            "\(storeName)_memory_\(UUID().uuidString)",
            schema: schema,
            isStoredInMemoryOnly: true
        )
        if let container = try? ModelContainer(for: schema, configurations: [memoryConfig]) {
            return BootstrapResult(
                container: container,
                issueMessage: "Could not open on-disk storage. Data will not persist until you restart after freeing space.",
                shouldAttemptMigration: true
            )
        }

        let fallback = localConfiguration("fallback_memory", schema: schema, isStoredInMemoryOnly: true)
        guard let container = try? ModelContainer(for: schema, configurations: [fallback]) else {
            fatalError("SwiftData could not create any local container.")
        }
        return BootstrapResult(
            container: container,
            issueMessage: "Database unavailable. Running with temporary storage.",
            shouldAttemptMigration: true
        )
    }

    private static func applicationSupportURL() -> URL {
        let fm = FileManager.default
        let url = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? fm.temporaryDirectory
        if !fm.fileExists(atPath: url.path) {
            try? fm.createDirectory(at: url, withIntermediateDirectories: true)
        }
        return url
    }

    private static func makeStoreURL(for storeName: String, in supportURL: URL) -> URL {
        supportURL.appendingPathComponent("\(storeName).store")
    }

    /// Removes `.store` bundles and SQLite sidecars (SwiftData may use directory packages).
    private static func removeAllStoreArtifacts(forBaseName baseName: String, in directory: URL) {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        for url in contents where url.lastPathComponent.hasPrefix(baseName) {
            try? fm.removeItem(at: url)
        }
    }

    func replaceAllExpenses(_ transactions: [Transaction]) throws {
        let existing = try context.fetch(FetchDescriptor<ExpenseEntity>())
        existing.forEach { context.delete($0) }
        for tx in transactions {
            try upsertExpense(tx)
        }
    }

    // MARK: - Goals

    func fetchAllGoals() throws -> [Goal] {
        let descriptor = FetchDescriptor<GoalEntity>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        return try context.fetch(descriptor).map { $0.toGoal() }
    }

    func replaceAllGoals(_ goals: [Goal]) throws {
        let existing = try context.fetch(FetchDescriptor<GoalEntity>())
        existing.forEach { context.delete($0) }
        for goal in goals {
            context.insert(GoalEntity.from(goal))
        }
        try context.save()
    }

    // MARK: - Insights metadata

    func replaceInsightMetadata(_ insights: [FinancialInsight]) throws {
        let existing = try context.fetch(FetchDescriptor<InsightEntity>())
        existing.forEach { context.delete($0) }
        for insight in insights {
            if let entity = InsightEntity.from(insight) {
                context.insert(entity)
            }
        }
        try context.save()
    }

    func fetchInsightMetadata() throws -> [FinancialInsight] {
        let descriptor = FetchDescriptor<InsightEntity>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        return try context.fetch(descriptor).compactMap { $0.toInsight() }
    }

    // MARK: - Preferences & theme

    func loadPreferences() throws -> UserPreferencesEntity {
        var descriptor = FetchDescriptor<UserPreferencesEntity>(predicate: #Predicate { $0.id == "default" })
        descriptor.fetchLimit = 1
        if let existing = try context.fetch(descriptor).first {
            return existing
        }
        let created = UserPreferencesEntity()
        context.insert(created)
        try context.save()
        return created
    }

    func savePreferences(
        selectedTab: AppTab,
        currencyCode: String,
        isBalanceVisible: Bool,
        activeCategoryPill: String
    ) throws {
        let prefs = try loadPreferences()
        prefs.selectedTabRaw = selectedTab.storageKey
        prefs.currencyCode = currencyCode
        prefs.isBalanceVisible = isBalanceVisible
        prefs.activeCategoryPill = activeCategoryPill
        try context.save()
    }

    func loadThemeId() throws -> String {
        var descriptor = FetchDescriptor<ThemeEntity>(predicate: #Predicate { $0.id == "default" })
        descriptor.fetchLimit = 1
        if let existing = try context.fetch(descriptor).first {
            return existing.themeId
        }
        let created = ThemeEntity()
        context.insert(created)
        try context.save()
        return created.themeId
    }

    func saveThemeId(_ themeId: String) throws {
        var descriptor = FetchDescriptor<ThemeEntity>(predicate: #Predicate { $0.id == "default" })
        descriptor.fetchLimit = 1
        let entity: ThemeEntity
        if let existing = try context.fetch(descriptor).first {
            entity = existing
        } else {
            entity = ThemeEntity()
            context.insert(entity)
        }
        entity.themeId = themeId
        entity.updatedAt = Date()
        try context.save()
    }

    // MARK: - Intelligence cache

    func replaceSubscriptionCache(_ subscriptions: [SubscriptionInfo]) throws {
        let existing = try context.fetch(FetchDescriptor<SubscriptionEntity>())
        existing.forEach { context.delete($0) }
        let encoder = JSONEncoder()
        for sub in subscriptions {
            let key = MerchantLogoEngine.normalizeMerchantName(sub.merchantName)
            guard let data = try? encoder.encode(sub) else { continue }
            context.insert(SubscriptionEntity(merchantKey: key, payloadJSON: data))
        }
        try context.save()
    }

    func replaceBaselines(_ baselines: [(category: TransactionCategory, value: Decimal, currency: String)], referenceDate: Date) throws {
        let existing = try context.fetch(FetchDescriptor<BaselineEntity>())
        existing.forEach { context.delete($0) }
        for item in baselines {
            context.insert(BaselineEntity(
                categoryRaw: item.category.rawValue,
                baselineValue: item.value,
                currencyCode: item.currency,
                updatedAt: referenceDate
            ))
        }
        try context.save()
    }

    // MARK: - Data control (Settings export / purge)

    func fetchAllExpenseEntities() throws -> [ExpenseEntity] {
        try context.fetch(FetchDescriptor<ExpenseEntity>())
    }

    func fetchAllGoalEntities() throws -> [GoalEntity] {
        try context.fetch(FetchDescriptor<GoalEntity>())
    }

    func purgeExpensesAndGoals() throws {
        let expenses = try fetchAllExpenseEntities()
        expenses.forEach { context.delete($0) }
        let goals = try fetchAllGoalEntities()
        goals.forEach { context.delete($0) }
        let debts = try fetchAllDebtEntities()
        debts.forEach { context.delete($0) }
        try context.save()
    }

    /// Wipes user financial rows and merchant links (keeps system category seeds).
    func purgeAllUserFinancialData() throws {
        try purgeExpensesAndGoals()
        let merchants = try context.fetch(FetchDescriptor<MerchantEntity>())
        merchants.forEach { context.delete($0) }
        let categories = try context.fetch(FetchDescriptor<CategoryEntity>())
        for category in categories where category.isCustom {
            context.delete(category)
        }
        try context.save()
    }
}

// MARK: - AppTab persistence

extension AppTab {
    var storageKey: String {
        switch self {
        case .home: return "home"
        case .expense: return "expense"
        case .studio: return "studio"
        case .settings: return "settings"
        }
    }

    static func from(storageKey: String) -> AppTab {
        switch storageKey {
        case "expense": return .expense
        case "freelance": return .studio
        case "studio": return .studio
        case "settings": return .settings
        default: return .home
        }
    }
}
