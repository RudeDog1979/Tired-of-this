//
//  ExpenseDatabase.swift
//  BuxMuse
//
//  MainActor facade — maps Row payloads to ExpenseRecord. SQL lives in ExpenseDatabaseSQL.
//

import Foundation

@MainActor
final class ExpenseDatabase {
    /// Background-safe SQL layer. Capture this in `Task.detached` — never call mapper methods off main.
    nonisolated let sql: ExpenseDatabaseSQL

    init() throws {
        sql = try ExpenseDatabaseSQL()
    }

    // MARK: - Migration

    func expenseCount() throws -> Int {
        try sql.expenseCount()
    }

    func migrateFromSwiftDataIfNeeded(swiftDataRecords: () throws -> [ExpenseRecord]) throws -> ExpenseGRDBMigrationManifest? {
        switch try sql.migrationPrecheck() {
        case .alreadyMigrated:
            return nil
        case .markCompleteOnly:
            try sql.markMigrationComplete()
            return nil
        case .importRecords:
            let records = try swiftDataRecords()
            let payloads = ExpenseGRDBRecordMapper.writePayloads(for: records)
            let splitCount = payloads.reduce(0) { $0 + $1.splitLines.count }
            try sql.importWritePayloads(payloads)
            return ExpenseGRDBMigrationManifest(
                importedExpenseCount: records.count,
                importedSplitLineCount: splitCount,
                completedAt: Date(),
                success: true
            )
        }
    }

    // MARK: - Reads

    func fetchAllRecords() throws -> [ExpenseRecord] {
        try ExpenseGRDBRecordMapper.makeRecords(from: sql.fetchAllRecordsRaw())
    }

    func fetchRecord(id: UUID) throws -> ExpenseRecord? {
        try ExpenseGRDBRecordMapper.makeRecords(from: sql.fetchRecordRaw(id: id.uuidString)).first
    }

    func fetchRecord(financeKitTransactionId: String) throws -> ExpenseRecord? {
        try ExpenseGRDBRecordMapper.makeRecords(
            from: sql.fetchRecordRaw(financeKitTransactionId: financeKitTransactionId)
        ).first
    }

    func fetchPendingWalletRecords() throws -> [ExpenseRecord] {
        try ExpenseGRDBRecordMapper.makeRecords(from: sql.fetchPendingWalletRecordsRaw())
    }

    func fetchWalletImportedRecords() throws -> [ExpenseRecord] {
        try ExpenseGRDBRecordMapper.makeRecords(from: sql.fetchWalletImportedRecordsRaw())
    }

    func fetchLedgerScope(
        currentMonthStart: Date,
        lastMonthStart: Date,
        hustleId: UUID?,
        includeUnassigned: Bool
    ) throws -> ExpenseLedgerScopePack {
        try ExpenseGRDBRecordMapper.makeLedgerScopePack(from: sql.fetchLedgerScopeRaw(
            currentMonthStart: currentMonthStart,
            lastMonthStart: lastMonthStart,
            hustleId: hustleId,
            includeUnassigned: includeUnassigned
        ))
    }

    func fetchRecords(
        from start: Date,
        to end: Date,
        hustleId: UUID? = nil,
        includeUnassigned: Bool = false
    ) throws -> [ExpenseRecord] {
        try ExpenseGRDBRecordMapper.makeRecords(from: sql.fetchRecordsRaw(
            from: start,
            to: end,
            hustleId: hustleId,
            includeUnassigned: includeUnassigned
        ))
    }

    func fetchRecordsForIntelligence(around record: ExpenseRecord) throws -> [ExpenseRecord] {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: record.date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? record.date
        let categoryLookback = calendar.date(byAdding: .day, value: -90, to: record.date) ?? record.date
        return try ExpenseGRDBRecordMapper.makeRecords(from: sql.fetchIntelligencePeersRaw(
            recordId: record.id.uuidString,
            merchantName: record.merchantName,
            name: record.name,
            amountText: NSDecimalNumber(decimal: record.amountValue).stringValue,
            categoryRaw: record.categoryRaw,
            dayStart: dayStart.timeIntervalSince1970,
            dayEnd: dayEnd.timeIntervalSince1970,
            categoryLookback: categoryLookback.timeIntervalSince1970
        ))
    }

    func fetchRecordsMatchingMerchant(merchantName: String) throws -> [ExpenseRecord] {
        try ExpenseGRDBRecordMapper.makeRecords(from: sql.fetchRecordsMatchingMerchantRaw(merchantName: merchantName))
    }

    func fetchMonthRecords(monthStart: Date, monthEnd: Date) throws -> [ExpenseRecord] {
        try fetchRecords(from: monthStart, to: monthEnd)
    }

    // MARK: - Writes

    func upsertRecord(_ record: ExpenseRecord) throws -> ExpenseRecord {
        let payload = ExpenseGRDBRecordMapper.writePayload(for: record)
        try sql.upsertWritePayload(payload)
        return try fetchRecord(id: record.id) ?? record
    }

    func deleteRecord(id: UUID) throws {
        try sql.deleteRecord(id: id.uuidString)
    }

    func updateCategory(id: UUID, categoryRaw: String, categoryId: UUID?) throws {
        try sql.updateCategory(id: id.uuidString, categoryRaw: categoryRaw, categoryId: categoryId?.uuidString)
    }

    func markWalletCategoryUserConfirmed(id: UUID) throws {
        try sql.updateWalletCategoryUserConfirmed(id: id.uuidString, confirmed: true)
    }

    func updateNotes(id: UUID, notes: String?) throws {
        try sql.updateNotes(id: id.uuidString, notes: notes)
    }

    func upsertWalletMerchantCategoryMemory(
        normalizedKey: String,
        categoryRaw: String,
        updatedAt: Date = Date()
    ) throws {
        try sql.upsertWalletMerchantCategoryMemory(
            normalizedKey: normalizedKey,
            categoryRaw: categoryRaw,
            updatedAt: updatedAt.timeIntervalSince1970
        )
    }

    func fetchWalletMerchantCategoryMemory(normalizedKey: String) throws -> TransactionCategory? {
        guard let raw = try sql.fetchWalletMerchantCategoryMemory(normalizedKey: normalizedKey) else {
            return nil
        }
        return TransactionCategory(rawValue: raw)
    }

    func clearMerchantId(_ merchantId: UUID) throws {
        try sql.clearMerchantId(merchantId.uuidString)
    }

    func reassignCategory(from sourceId: UUID, to targetId: UUID) throws {
        try sql.reassignCategory(from: sourceId.uuidString, to: targetId.uuidString)
    }

    func purgeAllExpenses() throws {
        try sql.purgeAllExpenses()
    }

    nonisolated static func removeDatabaseFiles() {
        ExpenseDatabaseSQL.removeDatabaseFiles()
    }
}
