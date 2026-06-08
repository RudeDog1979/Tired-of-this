//
//  ExpensePersistence.swift
//  BuxMuse
//
//  SwiftData persistence for expenses, categories, and merchants.
//

import Foundation
import SwiftData

extension PersistenceController {

    // MARK: - Seed

    func seedExpenseCatalogIfNeeded() throws {
        if didRunSeedAndMigration { return }

        let categoryCount = try context.fetchCount(FetchDescriptor<CategoryEntity>())
        if categoryCount == 0 {
            for def in ExpenseCategoryCatalog.systemDefinitions {
                context.insert(makeSystemCategoryEntity(for: def))
            }
            try context.save()
        }

        try syncMissingSystemCategoriesIfNeeded()
        try migrateLegacyExpenseRowsIfNeeded()
        try sanitizeMerchantEntitiesIfNeeded()

        didRunSeedAndMigration = true
    }

    /// Removes blank merchant rows and clears broken store links so list avatars do not trap the UI.
    private func sanitizeMerchantEntitiesIfNeeded() throws {
        let merchants = try context.fetch(FetchDescriptor<MerchantEntity>())
        var deletedIDs = Set<UUID>()
        for entity in merchants {
            let name = entity.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let normalized = entity.normalizedName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard name.isEmpty, normalized.isEmpty else { continue }
            deletedIDs.insert(entity.id)
            context.delete(entity)
        }
        guard !deletedIDs.isEmpty else { return }

        let expenses = try context.fetch(FetchDescriptor<ExpenseEntity>())
        var changed = false
        for expense in expenses where expense.merchantId.map({ deletedIDs.contains($0) }) == true {
            expense.merchantId = nil
            expense.updatedAt = Date()
            changed = true
        }
        if changed || !deletedIDs.isEmpty {
            try context.save()
        }
    }

    private func makeSystemCategoryEntity(
        for def: (TransactionCategory, icon: String, color: String)
    ) -> CategoryEntity {
        CategoryEntity(
            id: stableCategoryId(for: def.0),
            name: def.0.displayName,
            icon: def.1,
            color: def.2,
            isCustom: false,
            isSubscriptionCategory: def.0 == .subscriptions,
            subscriptionFrequency: def.0 == .subscriptions ? "monthly" : nil,
            systemCategoryRaw: def.0.rawValue
        )
    }

    /// Inserts newly added built-in categories for installs that seeded an older catalog.
    private func syncMissingSystemCategoriesIfNeeded() throws {
        let existing = try context.fetch(FetchDescriptor<CategoryEntity>())
        let existingRaws = Set(existing.compactMap(\.systemCategoryRaw))
        var changed = false

        for def in ExpenseCategoryCatalog.systemDefinitions {
            guard !existingRaws.contains(def.0.rawValue) else { continue }
            context.insert(makeSystemCategoryEntity(for: def))
            changed = true
        }

        if changed { try context.save() }
    }

    private func stableCategoryId(for category: TransactionCategory) -> UUID {
        var bytes = [UInt8](repeating: 0, count: 16)
        let raw = Array(category.rawValue.utf8)
        for (index, byte) in raw.enumerated() where index < 16 {
            bytes[index] = byte
        }
        bytes[6] = (bytes[6] & 0x0F) | 0x40
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }

    private func migrateLegacyExpenseRowsIfNeeded() throws {
        let entities = try context.fetch(FetchDescriptor<ExpenseEntity>())
        var changed = false
        for entity in entities {
            if entity.name.isEmpty {
                entity.name = entity.merchantName
                changed = true
            }
            if entity.merchantName.isEmpty {
                entity.merchantName = entity.name
                changed = true
            }
            if entity.categoryId == nil, let cat = TransactionCategory(rawValue: entity.categoryRaw) {
                entity.categoryId = stableCategoryId(for: cat)
                changed = true
            }
            if entity.createdAt.timeIntervalSince1970 < 1_000_000 {
                entity.createdAt = entity.date
                entity.updatedAt = entity.date
                changed = true
            }
        }
        if changed { try context.save() }
    }

    func categoryId(for transactionCategory: TransactionCategory) throws -> UUID {
        try seedExpenseCatalogIfNeeded()
        return stableCategoryId(for: transactionCategory)
    }

    func categoryRecord(for transactionCategory: TransactionCategory) throws -> ExpenseCategoryRecord? {
        let id = try categoryId(for: transactionCategory)
        return try fetchCategoryEntity(id: id).map { ExpenseCategoryRecord.from($0) }
    }

    func fetchAllCategoryRecords() throws -> [ExpenseCategoryRecord] {
        try seedExpenseCatalogIfNeeded()
        let descriptor = FetchDescriptor<CategoryEntity>(sortBy: [SortDescriptor(\.name)])
        return try context.fetch(descriptor).map { ExpenseCategoryRecord.from($0) }
    }

    // MARK: - Expenses

    func fetchAllExpenseRecords() throws -> [ExpenseRecord] {
        try seedExpenseCatalogIfNeeded()
        let descriptor = FetchDescriptor<ExpenseEntity>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        return try context.fetch(descriptor).map { ExpenseRecord.from($0) }
    }

    func fetchExpenseRecord(id: UUID) throws -> ExpenseRecord? {
        try fetchExpenseEntity(id: id).map { ExpenseRecord.from($0) }
    }

    func upsertExpenseRecord(_ record: ExpenseRecord, merchantSelection: MerchantSelection? = nil) throws -> ExpenseRecord {
        try seedExpenseCatalogIfNeeded()
        var saved = record
        if let merchant = try resolveMerchantIfNeeded(for: record, selection: merchantSelection) {
            saved.merchantId = merchant.id
            if saved.transactionCategory == .income {
                // Keep the user label in `name`; persist brand string for logos (matches dashboard lookup).
                let brand = merchant.name.trimmingCharacters(in: .whitespacesAndNewlines)
                saved.merchantName = brand.isEmpty ? saved.name : brand
            } else if saved.merchantName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                saved.merchantName = merchant.name
            }
            if saved.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                saved.name = saved.merchantName
            }
        } else {
            saved.merchantId = record.merchantId
        }

        if saved.categoryId == nil {
            saved.categoryId = try categoryId(for: saved.transactionCategory)
        }

        let id = saved.id
        let now = Date()

        if let existing = try fetchExpenseEntity(id: id) {
            apply(record: saved, to: existing, updatedAt: now)
        } else {
            let entity = ExpenseEntity(
                id: saved.id,
                name: saved.name,
                amountValue: saved.amountValue,
                currencyCode: saved.currencyCode,
                categoryId: saved.categoryId,
                merchantId: saved.merchantId,
                date: saved.date,
                notes: saved.notes,
                isRecurring: saved.isRecurring,
                recurrenceType: saved.recurrenceType,
                recurrenceConfidence: saved.recurrenceConfidence,
                nextExpectedDate: saved.nextExpectedDate,
                isSubscriptionLike: saved.isSubscriptionLike,
                isTrial: saved.isTrial,
                subscriptionStartDate: saved.subscriptionStartDate,
                trialEndDate: saved.trialEndDate,
                renewalReminderDays: saved.renewalReminderDays,
                heatZoneBucket: saved.heatZoneBucket,
                emotion: saved.emotion,
                contextTag: saved.contextTag,
                hustleId: saved.hustleId,
                habitSignatureId: saved.habitSignatureId,
                subscriptionConfidence: saved.subscriptionConfidence,
                microCommitmentType: saved.microCommitmentType,
                microCommitmentValue: saved.microCommitmentValue,
                futureImpact1Y: saved.futureImpact1Y,
                futureImpact5Y: saved.futureImpact5Y,
                createdAt: saved.createdAt,
                updatedAt: now,
                categoryRaw: saved.categoryRaw,
                merchantName: saved.merchantName,
                paymentMethod: saved.paymentMethod,
                isBarterExchange: saved.isBarterExchange,
                barterGoodsGiven: saved.barterGoodsGiven,
                barterGoodsReceived: saved.barterGoodsReceived,
                barterEstimatedValue: saved.barterEstimatedValue,
                bridgeGroupId: saved.bridgeGroupId,
                bridgeKind: saved.bridgeKind,
                bridgeRole: saved.bridgeRole,
                bridgeSharePercent: saved.bridgeSharePercent,
                bridgePeerExpenseId: saved.bridgePeerExpenseId,
                bridgeCounterpartyHustleId: saved.bridgeCounterpartyHustleId
            )
            context.insert(entity)
        }
        try context.save()
        return try fetchExpenseRecord(id: saved.id) ?? saved
    }

    private func apply(record: ExpenseRecord, to entity: ExpenseEntity, updatedAt: Date) {
        entity.name = record.name
        entity.merchantName = record.merchantName
        entity.amountValue = record.amountValue
        entity.currencyCode = record.currencyCode
        entity.categoryId = record.categoryId
        entity.merchantId = record.merchantId
        entity.date = record.date
        entity.notes = record.notes
        entity.isRecurring = record.isRecurring
        entity.recurrenceType = record.recurrenceType
        entity.recurrenceConfidence = record.recurrenceConfidence
        entity.nextExpectedDate = record.nextExpectedDate
        entity.isSubscriptionLike = record.isSubscriptionLike
        entity.isTrial = record.isTrial
        entity.subscriptionStartDate = record.subscriptionStartDate
        entity.trialEndDate = record.trialEndDate
        entity.renewalReminderDays = record.renewalReminderDays
        entity.heatZoneBucket = record.heatZoneBucket
        entity.emotion = record.emotion
        entity.contextTag = record.contextTag
        entity.hustleId = record.hustleId
        entity.habitSignatureId = record.habitSignatureId
        entity.subscriptionConfidence = record.subscriptionConfidence
        entity.microCommitmentType = record.microCommitmentType
        entity.microCommitmentValue = record.microCommitmentValue
        entity.futureImpact1Y = record.futureImpact1Y
        entity.futureImpact5Y = record.futureImpact5Y
        entity.categoryRaw = record.categoryRaw
        entity.paymentMethod = record.paymentMethod
        entity.isBarterExchange = record.isBarterExchange
        entity.barterGoodsGiven = record.barterGoodsGiven
        entity.barterGoodsReceived = record.barterGoodsReceived
        entity.barterEstimatedValue = record.barterEstimatedValue
        entity.bridgeGroupId = record.bridgeGroupId
        entity.bridgeKind = record.bridgeKind
        entity.bridgeRole = record.bridgeRole
        entity.bridgeSharePercent = record.bridgeSharePercent
        entity.bridgePeerExpenseId = record.bridgePeerExpenseId
        entity.bridgeCounterpartyHustleId = record.bridgeCounterpartyHustleId
        entity.updatedAt = updatedAt
    }

    func deleteExpenseRecord(id: UUID) throws {
        if let existing = try fetchExpenseEntity(id: id) {
            context.delete(existing)
            try context.save()
        }
    }

    func updateExpenseCategory(id: UUID, category: TransactionCategory, categoryId explicitCategoryId: UUID? = nil) throws {
        guard let existing = try fetchExpenseEntity(id: id) else { return }
        existing.categoryRaw = category.rawValue
        if let explicitCategoryId {
            existing.categoryId = explicitCategoryId
        } else {
            existing.categoryId = try categoryId(for: category)
        }
        existing.updatedAt = Date()
        try context.save()
    }

    func updateExpenseNotes(id: UUID, notes: String?) throws {
        guard let existing = try fetchExpenseEntity(id: id) else { return }
        existing.notes = notes
        existing.updatedAt = Date()
        try context.save()
    }

    // MARK: - Categories CRUD

    func createCategory(name: String, icon: String, color: String) throws -> ExpenseCategoryRecord {
        let entity = CategoryEntity(
            name: name,
            icon: icon,
            color: color,
            isCustom: true
        )
        context.insert(entity)
        try context.save()
        return ExpenseCategoryRecord.from(entity)
    }

    func updateCategory(_ record: ExpenseCategoryRecord) throws {
        guard let entity = try fetchCategoryEntity(id: record.id) else { return }
        entity.name = record.name
        entity.icon = record.icon
        entity.color = record.color
        entity.isSubscriptionCategory = record.isSubscriptionCategory
        entity.subscriptionFrequency = record.subscriptionFrequency
        try context.save()
    }

    func deleteCategory(id: UUID) throws {
        guard let entity = try fetchCategoryEntity(id: id), entity.isCustom else { return }
        context.delete(entity)
        try context.save()
    }

    func mergeCategories(sourceId: UUID, into targetId: UUID) throws {
        let expenses = try context.fetch(FetchDescriptor<ExpenseEntity>())
        for expense in expenses where expense.categoryId == sourceId {
            expense.categoryId = targetId
            expense.updatedAt = Date()
        }
        if let source = try fetchCategoryEntity(id: sourceId), source.isCustom {
            context.delete(source)
        }
        try context.save()
    }

    func reassignCategory(from sourceId: UUID, to targetId: UUID) throws {
        try mergeCategories(sourceId: sourceId, into: targetId)
    }

    // MARK: - Merchants

    func resolveMerchant(for record: ExpenseRecord, selection: MerchantSelection?) throws -> ExpenseMerchantRecord {
        if let merchant = try resolveMerchantIfNeeded(for: record, selection: selection) {
            return merchant
        }
        return try upsertMerchant(forName: record.merchantName)
    }

    /// Links a store only when explicitly chosen. Income labels (Salary, Refund, …) do not auto-create merchants.
    func resolveMerchantIfNeeded(for record: ExpenseRecord, selection: MerchantSelection?) throws -> ExpenseMerchantRecord? {
        if let selection {
            return try resolveMerchant(selection: selection)
        }
        if let merchantId = record.merchantId, let existing = try fetchMerchantRecord(id: merchantId) {
            return try touchMerchant(existing, displayName: existing.name)
        }
        if record.transactionCategory == .income {
            return nil
        }
        let merchantLabel = record.merchantName.trimmingCharacters(in: .whitespacesAndNewlines)
        let nameLabel = record.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let label = merchantLabel.isEmpty ? nameLabel : merchantLabel
        guard !label.isEmpty else { return nil }
        return try upsertMerchant(forName: label)
    }

    func resolveMerchant(selection: MerchantSelection) throws -> ExpenseMerchantRecord {
        let displayName = selection.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let disambiguator = selection.disambiguator?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if let merchantId = selection.merchantId, var existing = try fetchMerchantRecord(id: merchantId) {
            if displayName.isEmpty {
                return try touchMerchant(existing, displayName: existing.name)
            }
            existing.name = selection.historyLabel ?? displayName
            return try touchMerchant(existing, displayName: existing.name)
        }

        let normalized = MerchantLogoEngine.normalizeMerchantName(displayName)
        if !selection.createNew, var existing = try fetchMerchant(normalized: normalized, disambiguator: disambiguator) {
            existing.name = selection.historyLabel ?? displayName
            return try touchMerchant(existing, displayName: existing.name)
        }

        return try createMerchant(
            name: selection.historyLabel ?? displayName,
            normalized: normalized,
            disambiguator: disambiguator
        )
    }

    func upsertMerchant(forName name: String) throws -> ExpenseMerchantRecord {
        try resolveMerchant(selection: MerchantSelection(displayName: name, createNew: false))
    }

    private func fetchMerchant(normalized: String, disambiguator: String) throws -> ExpenseMerchantRecord? {
        let trimmedDisambiguator = disambiguator.trimmingCharacters(in: .whitespacesAndNewlines)
        let all = try fetchAllMerchantRecords()
        if let match = all.first(where: { merchant in
            merchant.normalizedName == normalized
                && merchant.disambiguator.trimmingCharacters(in: .whitespacesAndNewlines) == trimmedDisambiguator
        }) {
            return match
        }
        if trimmedDisambiguator.isEmpty,
           let primary = all.first(where: { $0.normalizedName == normalized && $0.disambiguator.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            return primary
        }
        return nil
    }

    private func touchMerchant(_ merchant: ExpenseMerchantRecord, displayName: String) throws -> ExpenseMerchantRecord {
        guard let entity = try fetchMerchantEntity(id: merchant.id) else { return merchant }
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        entity.name = trimmed.isEmpty ? merchant.name : trimmed
        entity.lastSeenAt = Date()
        if entity.logoURL == nil,
           !trimmed.isEmpty,
           let domain = MerchantLogoEngine.resolveDomain(for: trimmed) {
            entity.logoURL = MerchantLogoEngine.googleFaviconURL(for: domain)
        }
        try context.save()
        return ExpenseMerchantRecord.from(entity)
    }

    private func createMerchant(name: String, normalized: String, disambiguator: String) throws -> ExpenseMerchantRecord {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !normalized.isEmpty else {
            throw NSError(
                domain: "ExpensePersistence",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Merchant name is required."]
            )
        }
        let domain = MerchantLogoEngine.resolveDomain(for: trimmed)
        let entity = MerchantEntity(
            normalizedName: normalized,
            name: trimmed,
            disambiguator: disambiguator,
            logoURL: domain.map { MerchantLogoEngine.googleFaviconURL(for: $0) },
            cluster: MerchantIntelligence.normalize(trimmed)
        )
        context.insert(entity)
        try context.save()
        return ExpenseMerchantRecord.from(entity)
    }

    func fetchAllMerchantRecords() throws -> [ExpenseMerchantRecord] {
        let descriptor = FetchDescriptor<MerchantEntity>(sortBy: [SortDescriptor(\.name)])
        return try context.fetch(descriptor).map { ExpenseMerchantRecord.from($0) }
    }

    func fetchMerchantRecord(id: UUID) throws -> ExpenseMerchantRecord? {
        return try fetchMerchantEntity(id: id).map { ExpenseMerchantRecord.from($0) }
    }

    func updateMerchant(_ record: ExpenseMerchantRecord) throws {
        guard let entity = try fetchMerchantEntity(id: record.id) else { return }
        entity.name = record.name
        entity.disambiguator = record.disambiguator
        entity.logoURL = record.logoURL
        entity.localLogoPath = record.localLogoPath
        entity.cluster = record.cluster
        entity.riskScore = record.riskScore
        entity.isSubscriptionMerchant = record.isSubscriptionMerchant
        try context.save()
    }

    // MARK: - Legacy transaction bridge

    func fetchAllExpenses() throws -> [Transaction] {
        try fetchAllExpenseRecords().map { $0.toTransaction() }
    }

    func upsertExpense(_ transaction: Transaction) throws {
        let record = ExpenseRecord.from(
            transaction,
            categoryId: try categoryId(for: transaction.category),
            merchantId: nil
        )
        _ = try upsertExpenseRecord(record)
    }

    // MARK: - Safe Entity Fetch Helpers

    private func fetchExpenseEntity(id: UUID) throws -> ExpenseEntity? {
        var descriptor = FetchDescriptor<ExpenseEntity>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func fetchCategoryEntity(id: UUID) throws -> CategoryEntity? {
        var descriptor = FetchDescriptor<CategoryEntity>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func fetchMerchantEntity(id: UUID) throws -> MerchantEntity? {
        var descriptor = FetchDescriptor<MerchantEntity>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}
