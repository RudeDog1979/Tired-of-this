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
        try normalizeSystemCategoryRecordsIfNeeded()
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

        for merchantId in deletedIDs {
            try expenseDatabase.clearMerchantId(merchantId)
        }

        let expenses = try context.fetch(FetchDescriptor<ExpenseEntity>())
        var changed = false
        for expense in expenses where expense.merchantId.map({ deletedIDs.contains($0) }) == true {
            expense.merchantId = nil
            expense.updatedAt = Date()
            changed = true
        }
        if changed {
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

    /// Repairs system categories whose `name` was saved as a localized label (e.g. "Otro" instead of "Other").
    private func normalizeSystemCategoryRecordsIfNeeded() throws {
        let migrationKey = "buxmuse.categories.normalizeEnglishKeys.v1"
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }

        let entities = try context.fetch(FetchDescriptor<CategoryEntity>())
        var changed = false
        for entity in entities {
            guard !entity.isCustom else { continue }

            if let raw = entity.systemCategoryRaw,
               let system = TransactionCategory(rawValue: raw) {
                let englishKey = system.catalogLabelKey
                if entity.name != englishKey {
                    entity.name = englishKey
                    changed = true
                }
                continue
            }

            if let system = CustomBudgetCategory.resolvedSystemCategory(storedName: entity.name) {
                entity.systemCategoryRaw = system.rawValue
                entity.name = system.catalogLabelKey
                entity.isCustom = false
                changed = true
            }
        }

        if changed { try context.save() }
        UserDefaults.standard.set(true, forKey: migrationKey)
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
        return try expenseDatabase.fetchAllRecords()
    }

    func hasFinanceKitImportedExpenses() throws -> Bool {
        try fetchAllExpenseRecords().contains { record in
            guard let financeKitTransactionId = record.financeKitTransactionId else { return false }
            return !financeKitTransactionId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    func fetchExpenseRecords(
        from start: Date,
        to end: Date,
        hustleId: UUID?,
        includeUnassigned: Bool
    ) throws -> [ExpenseRecord] {
        try seedExpenseCatalogIfNeeded()
        return try expenseDatabase.fetchRecords(
            from: start,
            to: end,
            hustleId: hustleId,
            includeUnassigned: includeUnassigned
        )
    }

    func fetchExpenseRecordsForIntelligence(around record: ExpenseRecord) throws -> [ExpenseRecord] {
        try seedExpenseCatalogIfNeeded()
        return try expenseDatabase.fetchRecordsForIntelligence(around: record)
    }

    func fetchExpenseRecordsMatchingMerchant(merchantName: String) throws -> [ExpenseRecord] {
        try seedExpenseCatalogIfNeeded()
        return try expenseDatabase.fetchRecordsMatchingMerchant(merchantName: merchantName)
    }

    func fetchExpenseRecord(id: UUID) throws -> ExpenseRecord? {
        try expenseDatabase.fetchRecord(id: id)
    }

    func fetchExpenseRecordByFinanceKitId(_ financeKitId: String) throws -> ExpenseRecord? {
        try expenseDatabase.fetchRecord(financeKitTransactionId: financeKitId)
    }

    func fetchPendingWalletExpenseRecords() throws -> [ExpenseRecord] {
        try expenseDatabase.fetchPendingWalletRecords()
    }

    func fetchWalletImportedExpenseRecords() throws -> [ExpenseRecord] {
        try expenseDatabase.fetchWalletImportedRecords()
    }

    func upsertExpenseRecord(_ record: ExpenseRecord, merchantSelection: MerchantSelection? = nil) throws -> ExpenseRecord {
        try seedExpenseCatalogIfNeeded()
        var saved = record
        if let merchant = try resolveMerchantIfNeeded(for: record, selection: merchantSelection) {
            saved.merchantId = merchant.id
            if saved.transactionCategory == .income {
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

        return try expenseDatabase.upsertRecord(saved)
    }

    func deleteExpenseRecord(id: UUID) throws {
        try expenseDatabase.deleteRecord(id: id)
    }

    func updateExpenseCategory(id: UUID, category: TransactionCategory, categoryId explicitCategoryId: UUID? = nil) throws {
        let resolvedCategoryId: UUID?
        if let explicitCategoryId {
            resolvedCategoryId = explicitCategoryId
        } else {
            resolvedCategoryId = try categoryId(for: category)
        }
        try expenseDatabase.updateCategory(id: id, categoryRaw: category.rawValue, categoryId: resolvedCategoryId)
    }

    func markWalletCategoryUserConfirmed(expenseId: UUID) throws {
        try expenseDatabase.markWalletCategoryUserConfirmed(id: expenseId)
    }

    func updateExpenseNotes(id: UUID, notes: String?) throws {
        try expenseDatabase.updateNotes(id: id, notes: notes)
    }

    // MARK: - Wallet merchant category memory (manual corrections only)

    func rememberManualWalletMerchantCategory(
        merchantName: String,
        walletRawLabel: String?,
        category: TransactionCategory
    ) throws {
        let keys = WalletMerchantCategoryMemory.normalizedKeys(
            merchantName: merchantName,
            walletRawLabel: walletRawLabel
        )
        guard !keys.isEmpty else { return }
        for key in keys {
            try expenseDatabase.upsertWalletMerchantCategoryMemory(
                normalizedKey: key,
                categoryRaw: category.rawValue
            )
        }
    }

    func walletMerchantCategoryMemory(
        merchantName: String,
        walletRawLabel: String?
    ) throws -> TransactionCategory? {
        for key in WalletMerchantCategoryMemory.normalizedKeys(
            merchantName: merchantName,
            walletRawLabel: walletRawLabel
        ) {
            if let category = try expenseDatabase.fetchWalletMerchantCategoryMemory(normalizedKey: key) {
                return category
            }
        }
        return nil
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
        try expenseDatabase.reassignCategory(from: sourceId, to: targetId)
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

    func buildWalletMerchantContexts() throws -> [WalletMerchantContext] {
        let merchants = try fetchAllMerchantRecords()
        let expenses = try fetchAllExpenseRecords()
        return merchants.map { merchant in
            let labels = expenses
                .filter { $0.merchantId == merchant.id }
                .flatMap { [$0.name, $0.merchantName] }
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            let unique = Array(Set(labels))
            let domain = merchant.logoURL.flatMap { MerchantLogoEngine.domain(fromStoredLogoURL: $0) }
            return WalletMerchantContext(
                id: merchant.id,
                displayName: merchant.name,
                normalizedName: merchant.normalizedName,
                domain: domain,
                statementLabels: unique
            )
        }
    }

    @discardableResult
    func resolveWalletImportedMerchant(
        resolution: WalletStatementResolution,
        rawStatementLabel: String
    ) throws -> ExpenseMerchantRecord? {
        let canonical = resolution.canonicalName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !canonical.isEmpty else { return nil }

        if let merchantId = resolution.matchedMerchantId,
           let existing = try fetchMerchantRecord(id: merchantId) {
            return try touchWalletMerchant(
                existing,
                canonicalName: canonical,
                domain: resolution.domain,
                rawStatementLabel: rawStatementLabel
            )
        }

        let normalized = MerchantLogoEngine.normalizeMerchantName(canonical)
        if let existing = try fetchMerchant(normalized: normalized, disambiguator: "") {
            return try touchWalletMerchant(
                existing,
                canonicalName: canonical,
                domain: resolution.domain,
                rawStatementLabel: rawStatementLabel
            )
        }

        return try createWalletMerchant(
            name: canonical,
            normalized: normalized,
            domain: resolution.domain
        )
    }

    @discardableResult
    func reconcileWalletImports() throws -> Int {
        var contexts = try buildWalletMerchantContexts()
        let expenses = try fetchWalletImportedExpenseRecords()
        var updated = 0

        for record in expenses {
            let raw = WalletStatementIntelligence.walletRawLabel(for: record)
            guard !raw.isEmpty else { continue }

            let resolution = WalletStatementIntelligence.resolve(rawLabel: raw, contexts: contexts)
            let displayName = resolution.canonicalName.isEmpty ? raw : resolution.canonicalName
            let userMemory = try walletMerchantCategoryMemory(
                merchantName: displayName,
                walletRawLabel: raw
            )
            let decision = WalletCategoryIntelligence.classify(
                WalletCategoryIntelligence.input(
                    rawLabel: raw,
                    displayName: displayName,
                    amountValue: record.amountValue,
                    userMemoryCategory: userMemory
                )
            )
            let classification = WalletTransactionClassification(
                rawLabel: raw,
                displayName: displayName,
                resolution: resolution,
                decision: decision,
                userMemoryCategory: userMemory
            )

            var changed = record
            var didChange = false

            let importNotes = WalletStatementIntelligence.walletImportNotes(rawLabel: raw)
            if changed.notes != importNotes {
                changed.notes = importNotes
                didChange = true
            }
            if changed.name != displayName {
                changed.name = displayName
                didChange = true
            }
            if changed.merchantName != displayName {
                changed.merchantName = displayName
                didChange = true
            }

            if !record.walletCategoryUserConfirmed,
               WalletTransactionClassifier.shouldRefreshCategory(
                   existing: WalletCategoryRefreshSnapshot(record: record),
                   classification: classification
               ) {
                let category = classification.category
                if changed.transactionCategory != category {
                    changed.categoryRaw = category.rawValue
                    changed.categoryId = try categoryId(for: category)
                    didChange = true
                }
                let confidence = decision.confidence.persistedRaw
                if changed.walletCategoryConfidence != confidence {
                    changed.walletCategoryConfidence = confidence
                    didChange = true
                }
                let subscriptionLike = walletSubscriptionLike(
                    name: displayName,
                    category: category
                )
                if changed.isSubscriptionLike != subscriptionLike {
                    changed.isSubscriptionLike = subscriptionLike
                    didChange = true
                }
                if changed.isRecurring != subscriptionLike {
                    changed.isRecurring = subscriptionLike
                    didChange = true
                }
            }

            if let merchant = try resolveWalletImportedMerchant(
                resolution: resolution,
                rawStatementLabel: raw
            ) {
                if changed.merchantId != merchant.id {
                    changed.merchantId = merchant.id
                    didChange = true
                }
                contexts = mergeWalletMerchantContext(
                    contexts,
                    merchant: merchant,
                    rawLabel: raw,
                    canonicalName: displayName
                )
            }

            if didChange {
                _ = try upsertExpenseRecord(changed)
                updated += 1
            }
        }

        return updated
    }

    private func walletSubscriptionLike(name: String, category: TransactionCategory) -> Bool {
        if category == .subscriptions { return true }
        let lower = name.lowercased()
        return BuxFinanceKitManager.knownSubscriptionKeywords.contains { lower.contains($0) }
    }

    private func mergeWalletMerchantContext(
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

    private func touchWalletMerchant(
        _ merchant: ExpenseMerchantRecord,
        canonicalName: String,
        domain: String?,
        rawStatementLabel: String
    ) throws -> ExpenseMerchantRecord {
        guard let entity = try fetchMerchantEntity(id: merchant.id) else { return merchant }
        let trimmed = canonicalName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            entity.name = trimmed
        }
        entity.lastSeenAt = Date()
        let storedDomain = entity.logoURL.flatMap { MerchantLogoEngine.domain(fromStoredLogoURL: $0) }
        let resolved = domain?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let preferred = MerchantDomainResolver.preferredLogoDomain(stored: storedDomain, resolved: resolved) {
            entity.logoURL = MerchantLogoEngine.googleFaviconURL(for: preferred)
            MerchantLogoEngine.schedulePrefetch(
                for: trimmed.isEmpty ? merchant.name : trimmed,
                knownDomain: preferred
            )
        }
        try context.save()
        return ExpenseMerchantRecord.from(entity)
    }

    private func createWalletMerchant(
        name: String,
        normalized: String,
        domain: String?
    ) throws -> ExpenseMerchantRecord {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !normalized.isEmpty else {
            throw NSError(
                domain: "ExpensePersistence",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Merchant name is required."]
            )
        }
        let trimmedDomain = domain?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedDomain = trimmedDomain.flatMap { MerchantDomainResolver.isPlausibleLogoHost($0) ? $0 : nil }
            ?? MerchantLogoEngine.resolveDomain(for: trimmed)
        let entity = MerchantEntity(
            normalizedName: normalized,
            name: trimmed,
            disambiguator: "",
            logoURL: resolvedDomain.flatMap { MerchantLogoEngine.googleFaviconURL(for: $0) },
            cluster: MerchantIntelligence.normalize(trimmed)
        )
        context.insert(entity)
        try context.save()
        MerchantLogoEngine.schedulePrefetch(for: trimmed, knownDomain: resolvedDomain)
        return ExpenseMerchantRecord.from(entity)
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
            MerchantLogoEngine.schedulePrefetch(for: trimmed, knownDomain: domain)
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
        MerchantLogoEngine.schedulePrefetch(for: trimmed, knownDomain: domain)
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
