//
//  PersistenceStoreMigration.swift
//  BuxMuse
//
//  Production-safe migration from BuxMuse_v1–v4 stores into the active local store.
//  Never deletes legacy files. Re-runs if the target store is missing data.
//

import Foundation
import SwiftData

struct PersistenceMigrationManifest: Codable, Equatable {
    var sourceStoreName: String
    var sourceExpenseCount: Int
    var sourceGoalCount: Int
    var sourceDebtCount: Int
    var importedExpenseCount: Int
    var importedGoalCount: Int
    var importedDebtCount: Int
    var completedAt: Date
    var success: Bool
}

enum PersistenceStoreMigration {
    private static let manifestURL: URL = {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return support.appendingPathComponent("buxmuse_migration_manifest.json")
    }()

    static let activeStoreName = "BuxMuse_v5"

    @MainActor
    static func migrateIfNeeded(into persistence: PersistenceController) {
        let targetCounts = currentCounts(in: persistence.context)
        let candidates = PersistenceSQLiteStoreReader.discoverLegacyCandidates(excludingStoreName: activeStoreName)

        guard let source = candidates.max(by: { $0.counts.totalFinancialRows < $1.counts.totalFinancialRows }) else {
            if targetCounts.expenses > 0 {
                markSuccessIfNeeded(
                    source: nil,
                    sourceCounts: .init(expenses: 0, goals: 0, debts: 0, merchants: 0, categories: 0),
                    imported: targetCounts
                )
            }
            return
        }

        if targetCounts.expenses >= source.counts.expenses,
           targetCounts.goals >= source.counts.goals,
           targetCounts.debts >= source.counts.debts,
           targetCounts.expenses > 0 || source.counts.expenses == 0 {
            markSuccessIfNeeded(source: source, sourceCounts: source.counts, imported: targetCounts)
            return
        }

        if let manifest = loadManifest(),
           manifest.success,
           manifest.sourceStoreName == source.storeName,
           manifest.sourceExpenseCount == source.counts.expenses,
           targetCounts.expenses >= manifest.importedExpenseCount,
           targetCounts.expenses >= source.counts.expenses {
            return
        }

        print("SwiftData: migrating from \(source.storeName) → \(activeStoreName) (expenses \(source.counts.expenses), goals \(source.counts.goals), debts \(source.counts.debts))")

        var imported = ImportedTotals()

        if source.storeName == "BuxMuse_v4", migrateViaModelContainer(from: source, into: persistence, imported: &imported) {
            finalize(source: source, imported: imported, persistence: persistence)
            return
        }

        imported = ImportedTotals()
        if migrateViaSQLite(from: source, into: persistence, imported: &imported) {
            finalize(source: source, imported: imported, persistence: persistence)
            return
        }

        print("SwiftData: migration failed for \(source.storeName)")
    }

    static func legacyStoresContainData(excludingStoreName: String = activeStoreName) -> Bool {
        PersistenceSQLiteStoreReader.discoverLegacyCandidates(excludingStoreName: excludingStoreName)
            .contains { $0.counts.totalFinancialRows > 0 }
    }

    // MARK: - Paths

    @MainActor
    private static func migrateViaModelContainer(
        from source: PersistenceSQLiteStoreReader.LegacyStoreCandidate,
        into persistence: PersistenceController,
        imported: inout ImportedTotals
    ) -> Bool {
        let schema = Schema([
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
        let config = PersistenceController.localConfiguration(
            source.storeName,
            schema: schema,
            url: source.storeURL,
            allowsSave: false
        )
        guard let legacyContainer = try? ModelContainer(for: schema, configurations: [config]) else { return false }
        return copyFromModelContext(legacyContainer.mainContext, into: persistence.context, imported: &imported)
    }

    @MainActor
    private static func migrateViaSQLite(
        from source: PersistenceSQLiteStoreReader.LegacyStoreCandidate,
        into persistence: PersistenceController,
        imported: inout ImportedTotals
    ) -> Bool {
        guard let payload = PersistenceSQLiteStoreReader.readPayload(from: source) else { return false }

        for record in payload.expenses {
            if (try? persistence.fetchExpenseRecord(id: record.id)) != nil { continue }
            _ = try? persistence.upsertExpenseRecord(record, merchantSelection: nil)
            imported.expenses += 1
        }

        let existingGoals = (try? persistence.fetchAllGoals()) ?? []
        let existingGoalIDs = Set(existingGoals.map(\.id))
        var mergedGoals = existingGoals
        for goal in payload.goals where !existingGoalIDs.contains(goal.id) {
            mergedGoals.append(goal)
            imported.goals += 1
        }
        if imported.goals > 0 {
            try? persistence.replaceAllGoals(mergedGoals)
        }

        let existingDebts = (try? persistence.fetchAllDebts()) ?? []
        let existingDebtIDs = Set(existingDebts.map(\.id))
        var mergedDebts = existingDebts
        for debt in payload.debts where !existingDebtIDs.contains(debt.id) {
            mergedDebts.append(debt)
            imported.debts += 1
        }
        if imported.debts > 0 {
            try? persistence.replaceAllDebts(mergedDebts)
        }

        return imported.expenses > 0 || imported.goals > 0 || imported.debts > 0
    }

    @MainActor
    private static func copyFromModelContext(
        _ source: ModelContext,
        into destination: ModelContext,
        imported: inout ImportedTotals
    ) -> Bool {
        let legacyExpenses = (try? source.fetch(FetchDescriptor<ExpenseEntity>())) ?? []
        guard !legacyExpenses.isEmpty else { return false }

        for legacy in legacyExpenses {
            let legacyId = legacy.id
            if (try? destination.fetch(FetchDescriptor<ExpenseEntity>(predicate: #Predicate { $0.id == legacyId })).first) != nil {
                continue
            }
            let splitLines = legacy.splitLines.map { line in
                ExpenseSplitLineEntity(
                    id: line.id,
                    categoryId: line.categoryId,
                    categoryRaw: line.categoryRaw,
                    amountValue: line.amountValue,
                    sortOrder: line.sortOrder
                )
            }
            let entity = ExpenseEntity(
                id: legacy.id,
                name: legacy.name,
                amountValue: legacy.amountValue,
                currencyCode: legacy.currencyCode,
                categoryId: legacy.categoryId,
                merchantId: legacy.merchantId,
                date: legacy.date,
                notes: legacy.notes,
                isRecurring: legacy.isRecurring,
                recurrenceType: legacy.recurrenceType,
                recurrenceConfidence: legacy.recurrenceConfidence,
                nextExpectedDate: legacy.nextExpectedDate,
                isSubscriptionLike: legacy.isSubscriptionLike,
                isTrial: legacy.isTrial,
                subscriptionStartDate: legacy.subscriptionStartDate,
                trialEndDate: legacy.trialEndDate,
                renewalReminderDays: legacy.renewalReminderDays,
                heatZoneBucket: legacy.heatZoneBucket,
                emotion: legacy.emotion,
                contextTag: legacy.contextTag,
                hustleId: legacy.hustleId,
                habitSignatureId: legacy.habitSignatureId,
                subscriptionConfidence: legacy.subscriptionConfidence,
                microCommitmentType: legacy.microCommitmentType,
                microCommitmentValue: legacy.microCommitmentValue,
                futureImpact1Y: legacy.futureImpact1Y,
                futureImpact5Y: legacy.futureImpact5Y,
                createdAt: legacy.createdAt,
                updatedAt: legacy.updatedAt,
                categoryRaw: legacy.categoryRaw,
                merchantName: legacy.merchantName,
                paymentMethod: legacy.paymentMethod,
                isBarterExchange: legacy.isBarterExchange,
                barterGoodsGiven: legacy.barterGoodsGiven,
                barterGoodsReceived: legacy.barterGoodsReceived,
                barterEstimatedValue: legacy.barterEstimatedValue,
                bridgeGroupId: legacy.bridgeGroupId,
                bridgeKind: legacy.bridgeKind,
                bridgeRole: legacy.bridgeRole,
                bridgeSharePercent: legacy.bridgeSharePercent,
                bridgePeerExpenseId: legacy.bridgePeerExpenseId,
                bridgeCounterpartyHustleId: legacy.bridgeCounterpartyHustleId,
                isCategorySplit: legacy.isCategorySplit,
                householdScopeRaw: legacy.householdScopeRaw,
                splitLines: splitLines
            )
            for line in splitLines { line.expense = entity }
            destination.insert(entity)
            imported.expenses += 1
        }

        let legacyGoals = (try? source.fetch(FetchDescriptor<GoalEntity>())) ?? []
        for legacyGoal in legacyGoals {
            let goalId = legacyGoal.id
            if (try? destination.fetch(FetchDescriptor<GoalEntity>(predicate: #Predicate { $0.id == goalId })).first) != nil {
                continue
            }
            destination.insert(GoalEntity.from(legacyGoal.toGoal()))
            imported.goals += 1
        }

        let legacyDebts = (try? source.fetch(FetchDescriptor<DebtEntity>())) ?? []
        for legacyDebt in legacyDebts {
            let debtId = legacyDebt.id
            if (try? destination.fetch(FetchDescriptor<DebtEntity>(predicate: #Predicate { $0.id == debtId })).first) != nil {
                continue
            }
            let payments = legacyDebt.payments.map { payment in
                DebtPaymentEntity(
                    id: payment.id,
                    amount: payment.amount,
                    date: payment.date,
                    linkedExpenseId: payment.linkedExpenseId,
                    notes: payment.notes
                )
            }
            let debt = DebtEntity(
                id: legacyDebt.id,
                name: legacyDebt.name,
                typeRaw: legacyDebt.typeRaw,
                currentBalance: legacyDebt.currentBalance,
                originalBalance: legacyDebt.originalBalance,
                aprPercent: legacyDebt.aprPercent,
                minimumPayment: legacyDebt.minimumPayment,
                dueDayOfMonth: legacyDebt.dueDayOfMonth,
                lender: legacyDebt.lender,
                notes: legacyDebt.notes,
                isArchived: legacyDebt.isArchived,
                createdAt: legacyDebt.createdAt,
                updatedAt: legacyDebt.updatedAt,
                payments: payments
            )
            for payment in payments { payment.debt = debt }
            destination.insert(debt)
            imported.debts += 1
        }

        try? destination.save()
        return imported.expenses > 0 || imported.goals > 0 || imported.debts > 0
    }

    // MARK: - Bookkeeping

    private struct ImportedTotals {
        var expenses = 0
        var goals = 0
        var debts = 0
    }

    private struct RowCounts {
        let expenses: Int
        let goals: Int
        let debts: Int
    }

    @MainActor
    private static func currentCounts(in context: ModelContext) -> RowCounts {
        RowCounts(
            expenses: (try? context.fetchCount(FetchDescriptor<ExpenseEntity>())) ?? 0,
            goals: (try? context.fetchCount(FetchDescriptor<GoalEntity>())) ?? 0,
            debts: (try? context.fetchCount(FetchDescriptor<DebtEntity>())) ?? 0
        )
    }

    @MainActor
    private static func finalize(
        source: PersistenceSQLiteStoreReader.LegacyStoreCandidate,
        imported: ImportedTotals,
        persistence: PersistenceController
    ) {
        let final = currentCounts(in: persistence.context)
        let manifest = PersistenceMigrationManifest(
            sourceStoreName: source.storeName,
            sourceExpenseCount: source.counts.expenses,
            sourceGoalCount: source.counts.goals,
            sourceDebtCount: source.counts.debts,
            importedExpenseCount: final.expenses,
            importedGoalCount: final.goals,
            importedDebtCount: final.debts,
            completedAt: Date(),
            success: migrationSucceeded(final: final, source: source.counts)
        )
        saveManifest(manifest)
        print("SwiftData: migration complete — expenses \(final.expenses)/\(source.counts.expenses), goals \(final.goals)/\(source.counts.goals), debts \(final.debts)/\(source.counts.debts)")
    }

    private static func migrationSucceeded(final: RowCounts, source: PersistenceSQLiteStoreReader.StoreCounts) -> Bool {
        (source.expenses == 0 || final.expenses >= source.expenses)
            && (source.goals == 0 || final.goals >= source.goals)
            && (source.debts == 0 || final.debts >= source.debts)
            && (source.totalFinancialRows == 0 || final.expenses + final.goals + final.debts > 0)
    }

    @MainActor
    private static func markSuccessIfNeeded(
        source: PersistenceSQLiteStoreReader.LegacyStoreCandidate?,
        sourceCounts: PersistenceSQLiteStoreReader.StoreCounts,
        imported: RowCounts
    ) {
        guard imported.expenses > 0 || imported.goals > 0 else { return }
        let manifest = PersistenceMigrationManifest(
            sourceStoreName: source?.storeName ?? activeStoreName,
            sourceExpenseCount: sourceCounts.expenses,
            sourceGoalCount: sourceCounts.goals,
            sourceDebtCount: sourceCounts.debts,
            importedExpenseCount: imported.expenses,
            importedGoalCount: imported.goals,
            importedDebtCount: imported.debts,
            completedAt: Date(),
            success: true
        )
        saveManifest(manifest)
    }

    private static func loadManifest() -> PersistenceMigrationManifest? {
        guard let data = try? Data(contentsOf: manifestURL) else { return nil }
        return try? JSONDecoder().decode(PersistenceMigrationManifest.self, from: data)
    }

    private static func saveManifest(_ manifest: PersistenceMigrationManifest) {
        guard let data = try? JSONEncoder().encode(manifest) else { return }
        try? data.write(to: manifestURL, options: [.atomic])
    }
}
