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
        let categoryCount = try context.fetchCount(FetchDescriptor<CategoryEntity>())
        if categoryCount == 0 {
            for def in ExpenseCategoryCatalog.systemDefinitions {
                let entity = CategoryEntity(
                    id: stableCategoryId(for: def.0),
                    name: def.0.displayName,
                    icon: def.1,
                    color: def.2,
                    isCustom: false,
                    isSubscriptionCategory: def.0 == .subscriptions,
                    subscriptionFrequency: def.0 == .subscriptions ? "monthly" : nil,
                    systemCategoryRaw: def.0.rawValue
                )
                context.insert(entity)
            }
            try context.save()
        }

        try migrateLegacyExpenseRowsIfNeeded()
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
        var descriptor = FetchDescriptor<CategoryEntity>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first.map { ExpenseCategoryRecord.from($0) }
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
        var descriptor = FetchDescriptor<ExpenseEntity>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first.map { ExpenseRecord.from($0) }
    }

    func upsertExpenseRecord(_ record: ExpenseRecord, merchantSelection: MerchantSelection? = nil) throws -> ExpenseRecord {
        try seedExpenseCatalogIfNeeded()
        let merchant = try resolveMerchant(for: record, selection: merchantSelection)
        var saved = record
        saved.merchantId = merchant.id
        if saved.merchantName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            saved.merchantName = merchant.name
        }
        if saved.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            saved.name = saved.merchantName
        }

        if saved.categoryId == nil {
            saved.categoryId = try categoryId(for: saved.transactionCategory)
        }

        let id = saved.id
        var descriptor = FetchDescriptor<ExpenseEntity>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        let now = Date()

        if let existing = try context.fetch(descriptor).first {
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
                habitSignatureId: saved.habitSignatureId,
                subscriptionConfidence: saved.subscriptionConfidence,
                microCommitmentType: saved.microCommitmentType,
                microCommitmentValue: saved.microCommitmentValue,
                futureImpact1Y: saved.futureImpact1Y,
                futureImpact5Y: saved.futureImpact5Y,
                createdAt: saved.createdAt,
                updatedAt: now,
                categoryRaw: saved.categoryRaw,
                merchantName: saved.merchantName
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
        entity.habitSignatureId = record.habitSignatureId
        entity.subscriptionConfidence = record.subscriptionConfidence
        entity.microCommitmentType = record.microCommitmentType
        entity.microCommitmentValue = record.microCommitmentValue
        entity.futureImpact1Y = record.futureImpact1Y
        entity.futureImpact5Y = record.futureImpact5Y
        entity.categoryRaw = record.categoryRaw
        entity.updatedAt = updatedAt
    }

    func deleteExpenseRecord(id: UUID) throws {
        var descriptor = FetchDescriptor<ExpenseEntity>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        if let existing = try context.fetch(descriptor).first {
            context.delete(existing)
            try context.save()
        }
    }

    func updateExpenseCategory(id: UUID, category: TransactionCategory, categoryId explicitCategoryId: UUID? = nil) throws {
        var descriptor = FetchDescriptor<ExpenseEntity>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        guard let existing = try context.fetch(descriptor).first else { return }
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
        var descriptor = FetchDescriptor<ExpenseEntity>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        guard let existing = try context.fetch(descriptor).first else { return }
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
        let targetId = record.id
        var descriptor = FetchDescriptor<CategoryEntity>(predicate: #Predicate { $0.id == targetId })
        descriptor.fetchLimit = 1
        guard let entity = try context.fetch(descriptor).first else { return }
        entity.name = record.name
        entity.icon = record.icon
        entity.color = record.color
        entity.isSubscriptionCategory = record.isSubscriptionCategory
        entity.subscriptionFrequency = record.subscriptionFrequency
        try context.save()
    }

    func deleteCategory(id: UUID) throws {
        var descriptor = FetchDescriptor<CategoryEntity>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        guard let entity = try context.fetch(descriptor).first, entity.isCustom else { return }
        context.delete(entity)
        try context.save()
    }

    func mergeCategories(sourceId: UUID, into targetId: UUID) throws {
        let expenses = try context.fetch(FetchDescriptor<ExpenseEntity>())
        for expense in expenses where expense.categoryId == sourceId {
            expense.categoryId = targetId
            expense.updatedAt = Date()
        }
        var descriptor = FetchDescriptor<CategoryEntity>(predicate: #Predicate { $0.id == sourceId })
        descriptor.fetchLimit = 1
        if let source = try context.fetch(descriptor).first, source.isCustom {
            context.delete(source)
        }
        try context.save()
    }

    func reassignCategory(from sourceId: UUID, to targetId: UUID) throws {
        try mergeCategories(sourceId: sourceId, into: targetId)
    }

    // MARK: - Merchants

    func resolveMerchant(for record: ExpenseRecord, selection: MerchantSelection?) throws -> ExpenseMerchantRecord {
        if let selection {
            return try resolveMerchant(selection: selection)
        }
        if let merchantId = record.merchantId, let existing = try fetchMerchantRecord(id: merchantId) {
            return try touchMerchant(existing, displayName: record.merchantName)
        }
        return try upsertMerchant(forName: record.merchantName)
    }

    func resolveMerchant(selection: MerchantSelection) throws -> ExpenseMerchantRecord {
        let displayName = selection.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let disambiguator = selection.disambiguator?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if let merchantId = selection.merchantId, var existing = try fetchMerchantRecord(id: merchantId) {
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
        let targetId = merchant.id
        var descriptor = FetchDescriptor<MerchantEntity>(predicate: #Predicate { $0.id == targetId })
        descriptor.fetchLimit = 1
        guard let entity = try context.fetch(descriptor).first else { return merchant }
        entity.name = displayName
        entity.lastSeenAt = Date()
        if entity.logoURL == nil, let domain = MerchantLogoEngine.resolveDomain(for: displayName) {
            entity.logoURL = MerchantLogoEngine.googleFaviconURL(for: domain)
        }
        try context.save()
        return ExpenseMerchantRecord.from(entity)
    }

    private func createMerchant(name: String, normalized: String, disambiguator: String) throws -> ExpenseMerchantRecord {
        let domain = MerchantLogoEngine.resolveDomain(for: name)
        let entity = MerchantEntity(
            normalizedName: normalized,
            name: name,
            disambiguator: disambiguator,
            logoURL: domain.map { MerchantLogoEngine.googleFaviconURL(for: $0) },
            cluster: MerchantIntelligence.normalize(name)
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
        var descriptor = FetchDescriptor<MerchantEntity>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first.map { ExpenseMerchantRecord.from($0) }
    }

    func updateMerchant(_ record: ExpenseMerchantRecord) throws {
        let targetId = record.id
        var descriptor = FetchDescriptor<MerchantEntity>(predicate: #Predicate { $0.id == targetId })
        descriptor.fetchLimit = 1
        guard let entity = try context.fetch(descriptor).first else { return }
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
}
