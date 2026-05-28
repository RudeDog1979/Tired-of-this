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

    /// Bumped when SwiftData models change incompatibly (avoids loadIssueModelContainer on old stores).
    private static let storeName = "BuxMuse_v3"

    public init(inMemory: Bool = false) {
        let schema = Schema([
            ExpenseEntity.self,
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

        let config: ModelConfiguration
        if inMemory {
            config = ModelConfiguration(
                Self.storeName,
                schema: schema,
                isStoredInMemoryOnly: true
            )
        } else {
            let storeURL = Self.prepareOnDiskStoreURL()
            config = ModelConfiguration(
                Self.storeName,
                schema: schema,
                url: storeURL,
                allowsSave: true
            )
        }

        do {
            container = try Self.openContainer(schema: schema, configuration: config)
            context = container.mainContext
            context.autosaveEnabled = false
        } catch {
            fatalError("SwiftData container failed: \(error)")
        }
    }

    /// Ensures on-disk Library folders exist before SwiftData / Core Data open SQLite (fixes errno 2 on first device launch).
    private static func prepareOnDiskStoreURL() -> URL {
        let fm = FileManager.default
        for directory in [FileManager.SearchPathDirectory.applicationSupportDirectory, .cachesDirectory] {
            guard let url = fm.urls(for: directory, in: .userDomainMask).first else { continue }
            if fm.fileExists(atPath: url.path) { continue }
            do {
                try fm.createDirectory(at: url, withIntermediateDirectories: true)
            } catch {
                print("SwiftData: failed to create \(directory) directory: \(error)")
            }
        }
        let supportURL = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fm.temporaryDirectory
        return supportURL.appendingPathComponent("\(storeName).store", isDirectory: false)
    }

    private static func openContainer(schema: Schema, configuration: ModelConfiguration) throws -> ModelContainer {
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            guard !configuration.isStoredInMemoryOnly else { throw error }
            print("SwiftData: store load failed (\(error)). Recreating \(storeName).")
            removePersistentStoreFiles(for: configuration)
            return try ModelContainer(for: schema, configurations: [configuration])
        }
    }

    private static func removePersistentStoreFiles(for configuration: ModelConfiguration) {
        let storeURL = configuration.url
        let fm = FileManager.default
        if fm.fileExists(atPath: storeURL.path) {
            try? fm.removeItem(at: storeURL)
        }
        let base = storeURL.path
        for suffix in ["-shm", "-wal"] {
            let sidecar = base + suffix
            if fm.fileExists(atPath: sidecar) {
                try? fm.removeItem(atPath: sidecar)
            }
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
