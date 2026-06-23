//
//  ExpenseDatabaseSQL.swift
//  BuxMuse
//
//  Nonisolated GRDB layer — Row/SQL only. No ExpenseRecord. Safe for Task.detached.
//

import Foundation
import GRDB

nonisolated
final class ExpenseDatabaseSQL: @unchecked Sendable {
    private enum MetaKey {
        static let migrationCompleted = "swiftdata_migration_completed"
    }

    enum MigrationPrecheck: Sendable {
        case alreadyMigrated
        case markCompleteOnly
        case importRecords
    }

    private static let fileName = "expenses.sqlite"

    private let dbQueue: DatabaseQueue

    init() throws {
        let url = Self.databaseURL()
        var config = Configuration()
        config.prepareDatabase { db in
            try db.execute(sql: "PRAGMA foreign_keys = ON")
        }
        dbQueue = try DatabaseQueue(path: url.path, configuration: config)
        try migrator.migrate(dbQueue)
    }

    // MARK: - Migration

    func expenseCount() throws -> Int {
        try dbQueue.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM expenses") ?? 0
        }
    }

    func migrationPrecheck() throws -> MigrationPrecheck {
        try dbQueue.read { db in
            if try Self.metaFlag(db, key: MetaKey.migrationCompleted) {
                return .alreadyMigrated
            }
            let existing = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM expenses") ?? 0
            return existing > 0 ? .markCompleteOnly : .importRecords
        }
    }

    func markMigrationComplete() throws {
        try dbQueue.write { db in
            try Self.setMetaFlag(db, key: MetaKey.migrationCompleted, value: true)
        }
    }

    func importWritePayloads(_ payloads: [ExpenseWritePayload]) throws {
        try dbQueue.write { db in
            for payload in payloads {
                try Self.insertExpense(payload, db: db)
            }
            try Self.setMetaFlag(db, key: MetaKey.migrationCompleted, value: true)
        }
    }

    // MARK: - Reads (raw)

    func fetchAllRecordsRaw() throws -> ExpenseRowPayload {
        try dbQueue.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT * FROM expenses ORDER BY date DESC
                """)
            let splitRows = try Self.fetchSplitRows(for: rows, db: db)
            return ExpenseRowPayload(expenses: rows, splits: splitRows)
        }
    }

    func fetchRecordRaw(id: String) throws -> ExpenseRowPayload {
        try dbQueue.read { db in
            guard let row = try Row.fetchOne(
                db,
                sql: "SELECT * FROM expenses WHERE id = ?",
                arguments: [id]
            ) else {
                return ExpenseRowPayload(expenses: [], splits: [])
            }
            let splitRows = try Self.fetchSplitRows(for: [row], db: db)
            return ExpenseRowPayload(expenses: [row], splits: splitRows)
        }
    }

    func fetchRecordRaw(financeKitTransactionId: String) throws -> ExpenseRowPayload {
        try dbQueue.read { db in
            guard let row = try Row.fetchOne(
                db,
                sql: "SELECT * FROM expenses WHERE financeKitTransactionId = ? LIMIT 1",
                arguments: [financeKitTransactionId]
            ) else {
                return ExpenseRowPayload(expenses: [], splits: [])
            }
            let splitRows = try Self.fetchSplitRows(for: [row], db: db)
            return ExpenseRowPayload(expenses: [row], splits: splitRows)
        }
    }

    func fetchPendingWalletRecordsRaw() throws -> ExpenseRowPayload {
        try dbQueue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT * FROM expenses
                WHERE COALESCE(walletIsPending, 0) = 1
                  AND financeKitTransactionId IS NOT NULL
                ORDER BY date DESC, updatedAt DESC
                """
            )
            let splitRows = try Self.fetchSplitRows(for: rows, db: db)
            return ExpenseRowPayload(expenses: rows, splits: splitRows)
        }
    }

    func fetchWalletImportedRecordsRaw() throws -> ExpenseRowPayload {
        try dbQueue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT * FROM expenses
                WHERE financeKitTransactionId IS NOT NULL
                  AND TRIM(financeKitTransactionId) != ''
                ORDER BY date DESC
                """
            )
            let splitRows = try Self.fetchSplitRows(for: rows, db: db)
            return ExpenseRowPayload(expenses: rows, splits: splitRows)
        }
    }

    func fetchLedgerScopeRaw(
        currentMonthStart: Date,
        lastMonthStart: Date,
        hustleId: UUID?,
        includeUnassigned: Bool
    ) throws -> LedgerScopeRaw {
        try dbQueue.read { db in
            let monthStart = currentMonthStart.timeIntervalSince1970
            let prevStart = lastMonthStart.timeIntervalSince1970
            let workspace = Self.workspaceClause(hustleId: hustleId, includeUnassigned: includeUnassigned)

            let currentRows = try Row.fetchAll(
                db,
                sql: "SELECT * FROM expenses WHERE date >= ? AND COALESCE(walletIsPending, 0) = 0\(workspace.sql) ORDER BY date DESC",
                arguments: StatementArguments([monthStart] + workspace.arguments)
            )
            let lastRows = try Row.fetchAll(
                db,
                sql: "SELECT * FROM expenses WHERE date >= ? AND date < ? AND COALESCE(walletIsPending, 0) = 0\(workspace.sql) ORDER BY date DESC",
                arguments: StatementArguments([prevStart, monthStart] + workspace.arguments)
            )
            let pendingRows = try Row.fetchAll(
                db,
                sql: "SELECT * FROM expenses WHERE COALESCE(walletIsPending, 0) = 1\(workspace.sql) ORDER BY date DESC, updatedAt DESC",
                arguments: StatementArguments(workspace.arguments)
            )
            let archiveMonths = try Self.fetchArchiveMonthIndex(
                db: db,
                before: monthStart,
                hustleId: hustleId,
                includeUnassigned: includeUnassigned
            )
            let splitRows = try Self.fetchSplitRows(for: currentRows + lastRows + pendingRows, db: db)
            return LedgerScopeRaw(current: currentRows, last: lastRows, pending: pendingRows, splits: splitRows, archive: archiveMonths)
        }
    }

    func fetchRecordsRaw(
        from start: Date,
        to end: Date,
        hustleId: UUID?,
        includeUnassigned: Bool
    ) throws -> ExpenseRowPayload {
        try dbQueue.read { db in
            let workspace = Self.workspaceClause(hustleId: hustleId, includeUnassigned: includeUnassigned)
            let rows = try Row.fetchAll(
                db,
                sql: "SELECT * FROM expenses WHERE date >= ? AND date < ?\(workspace.sql) ORDER BY date DESC",
                arguments: StatementArguments([start.timeIntervalSince1970, end.timeIntervalSince1970] + workspace.arguments)
            )
            let splitRows = try Self.fetchSplitRows(for: rows, db: db)
            return ExpenseRowPayload(expenses: rows, splits: splitRows)
        }
    }

    func fetchRecentRecordsRaw(
        limit: Int,
        hustleId: UUID?,
        includeUnassigned: Bool
    ) throws -> ExpenseRowPayload {
        try dbQueue.read { db in
            let workspace = Self.workspaceClause(hustleId: hustleId, includeUnassigned: includeUnassigned)
            let rows = try Row.fetchAll(
                db,
                sql: "SELECT * FROM expenses WHERE 1 = 1\(workspace.sql) ORDER BY date DESC LIMIT ?",
                arguments: StatementArguments(workspace.arguments + [limit])
            )
            let splitRows = try Self.fetchSplitRows(for: rows, db: db)
            return ExpenseRowPayload(expenses: rows, splits: splitRows)
        }
    }

    func fetchIntelligencePeersRaw(
        recordId: String,
        merchantName: String,
        name: String,
        amountText: String,
        categoryRaw: String,
        dayStart: Double,
        dayEnd: Double,
        categoryLookback: Double
    ) throws -> ExpenseRowPayload {
        try dbQueue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT * FROM expenses
                WHERE id != ?
                  AND (
                    merchantName = ? OR name = ? OR merchantName = ? OR name = ?
                    OR (date >= ? AND date < ? AND amountValue = ?)
                    OR (categoryRaw = ? AND date >= ?)
                  )
                ORDER BY date DESC
                LIMIT 500
                """,
                arguments: [
                    recordId,
                    merchantName, name, name, merchantName,
                    dayStart, dayEnd, amountText,
                    categoryRaw, categoryLookback
                ]
            )
            let splitRows = try Self.fetchSplitRows(for: rows, db: db)
            return ExpenseRowPayload(expenses: rows, splits: splitRows)
        }
    }

    func fetchRecordsMatchingMerchantRaw(merchantName: String) throws -> ExpenseRowPayload {
        try dbQueue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT * FROM expenses
                WHERE merchantName = ? OR name = ?
                ORDER BY date DESC
                """,
                arguments: [merchantName, merchantName]
            )
            let splitRows = try Self.fetchSplitRows(for: rows, db: db)
            return ExpenseRowPayload(expenses: rows, splits: splitRows)
        }
    }

    func fetchMonthlyOutflowTotals(months: Int) throws -> [MonthlyOutflowTotal] {
        let calendar = Calendar.current
        guard let oldestMonth = calendar.date(byAdding: .month, value: -(months - 1), to: Date()),
              let oldestStart = calendar.dateInterval(of: .month, for: oldestMonth)?.start else {
            return []
        }
        return try dbQueue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT
                    CAST(strftime('%s', strftime('%Y-%m-01', datetime(date, 'unixepoch'))) AS REAL) AS monthStart,
                    SUM(ABS(CAST(amountValue AS REAL))) AS total
                FROM expenses
                WHERE date >= ? AND CAST(amountValue AS REAL) < 0
                GROUP BY strftime('%Y-%m', datetime(date, 'unixepoch'))
                ORDER BY monthStart DESC
                LIMIT ?
                """,
                arguments: [oldestStart.timeIntervalSince1970, months]
            )
            var totals: [MonthlyOutflowTotal] = []
            totals.reserveCapacity(rows.count)
            for row in rows {
                guard let start = row["monthStart"] as Double?,
                      let total = row["total"] as Double? else { continue }
                totals.append(MonthlyOutflowTotal(monthStart: start, total: total))
            }
            return totals
        }
    }

    func sumAllAmountValues() throws -> Double {
        try dbQueue.read { db in
            try Double.fetchOne(
                db,
                sql: "SELECT COALESCE(SUM(CAST(amountValue AS REAL)), 0) FROM expenses"
            ) ?? 0
        }
    }

    /// Running ledger balance: every signed amount in, credits (+) and debits (−), optional Wallet-only filter.
    func sumLedgerAmountValues(
        currencyCode: String,
        includePending: Bool = true,
        walletOnly: Bool = false
    ) throws -> Double {
        try dbQueue.read { db in
            var sql = """
                SELECT COALESCE(SUM(CAST(amountValue AS REAL)), 0)
                FROM expenses
                WHERE currencyCode = ?
                """
            let arguments: [DatabaseValueConvertible] = [currencyCode]
            if walletOnly {
                sql += " AND financeKitTransactionId IS NOT NULL"
            }
            if !includePending {
                sql += " AND COALESCE(walletIsPending, 0) = 0"
            }
            return try Double.fetchOne(db, sql: sql, arguments: StatementArguments(arguments)) ?? 0
        }
    }

    func fetchAllBookedRecordsRaw(currencyCode: String) throws -> ExpenseRowPayload {
        try dbQueue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT * FROM expenses
                WHERE COALESCE(walletIsPending, 0) = 0
                  AND currencyCode = ?
                ORDER BY date DESC
                """,
                arguments: [currencyCode]
            )
            let splitRows = try Self.fetchSplitRows(for: rows, db: db)
            return ExpenseRowPayload(expenses: rows, splits: splitRows)
        }
    }

    func fetchAllRecordsRaw(currencyCode: String) throws -> ExpenseRowPayload {
        try dbQueue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: "SELECT * FROM expenses WHERE currencyCode = ? ORDER BY date DESC",
                arguments: [currencyCode]
            )
            let splitRows = try Self.fetchSplitRows(for: rows, db: db)
            return ExpenseRowPayload(expenses: rows, splits: splitRows)
        }
    }

    /// Sum of booked (posted) rows — excludes pending Wallet authorizations.
    func sumBookedAmountValues(currencyCode: String? = nil) throws -> Double {
        try dbQueue.read { db in
            if let currencyCode {
                return try Double.fetchOne(
                    db,
                    sql: """
                    SELECT COALESCE(SUM(CAST(amountValue AS REAL)), 0)
                    FROM expenses
                    WHERE COALESCE(walletIsPending, 0) = 0
                      AND currencyCode = ?
                    """,
                    arguments: [currencyCode]
                ) ?? 0
            }
            return try Double.fetchOne(
                db,
                sql: """
                SELECT COALESCE(SUM(CAST(amountValue AS REAL)), 0)
                FROM expenses
                WHERE COALESCE(walletIsPending, 0) = 0
                """
            ) ?? 0
        }
    }

    // MARK: - Writes

    func upsertWritePayload(_ payload: ExpenseWritePayload) throws {
        try dbQueue.write { db in
            try Self.insertExpense(payload, db: db)
        }
    }

    func deleteRecord(id: String) throws {
        try dbQueue.write { db in
            try db.execute(sql: "DELETE FROM expenses WHERE id = ?", arguments: [id])
        }
    }

    func updateCategory(id: String, categoryRaw: String, categoryId: String?) throws {
        try dbQueue.write { db in
            try db.execute(
                sql: """
                UPDATE expenses
                SET categoryRaw = ?, categoryId = ?, updatedAt = ?
                WHERE id = ?
                """,
                arguments: [categoryRaw, categoryId, Date().timeIntervalSince1970, id]
            )
        }
    }

    func updateWalletCategoryUserConfirmed(id: String, confirmed: Bool) throws {
        try dbQueue.write { db in
            try db.execute(
                sql: """
                UPDATE expenses
                SET walletCategoryUserConfirmed = ?, updatedAt = ?
                WHERE id = ?
                """,
                arguments: [confirmed ? 1 : 0, Date().timeIntervalSince1970, id]
            )
        }
    }

    func updateNotes(id: String, notes: String?) throws {
        try dbQueue.write { db in
            try db.execute(
                sql: "UPDATE expenses SET notes = ?, updatedAt = ? WHERE id = ?",
                arguments: [notes, Date().timeIntervalSince1970, id]
            )
        }
    }

    // MARK: - Wallet merchant category memory

    func upsertWalletMerchantCategoryMemory(
        normalizedKey: String,
        categoryRaw: String,
        updatedAt: TimeInterval
    ) throws {
        try dbQueue.write { db in
            try db.execute(
                sql: """
                INSERT OR REPLACE INTO wallet_merchant_category_memory
                (normalizedKey, categoryRaw, updatedAt)
                VALUES (?, ?, ?)
                """,
                arguments: [normalizedKey, categoryRaw, updatedAt]
            )
        }
    }

    func fetchWalletMerchantCategoryMemory(normalizedKey: String) throws -> String? {
        try dbQueue.read { db in
            try String.fetchOne(
                db,
                sql: "SELECT categoryRaw FROM wallet_merchant_category_memory WHERE normalizedKey = ?",
                arguments: [normalizedKey]
            )
        }
    }

    func deleteWalletMerchantCategoryMemory(normalizedKey: String) throws {
        try dbQueue.write { db in
            try db.execute(
                sql: "DELETE FROM wallet_merchant_category_memory WHERE normalizedKey = ?",
                arguments: [normalizedKey]
            )
        }
    }

    func clearMerchantId(_ merchantId: String) throws {
        try dbQueue.write { db in
            try db.execute(
                sql: "UPDATE expenses SET merchantId = NULL, updatedAt = ? WHERE merchantId = ?",
                arguments: [Date().timeIntervalSince1970, merchantId]
            )
        }
    }

    func reassignCategory(from sourceId: String, to targetId: String) throws {
        try dbQueue.write { db in
            let now = Date().timeIntervalSince1970
            try db.execute(
                sql: "UPDATE expenses SET categoryId = ?, updatedAt = ? WHERE categoryId = ?",
                arguments: [targetId, now, sourceId]
            )
            try db.execute(
                sql: "UPDATE expense_split_lines SET categoryId = ? WHERE categoryId = ?",
                arguments: [targetId, sourceId]
            )
        }
    }

    func purgeAllExpenses() throws {
        try dbQueue.write { db in
            try db.execute(sql: "DELETE FROM expense_split_lines")
            try db.execute(sql: "DELETE FROM expenses")
            try db.execute(sql: "DELETE FROM expense_meta")
            try db.execute(sql: "DELETE FROM wallet_merchant_category_memory")
        }
    }

    static func removeDatabaseFiles() {
        let url = databaseURL()
        let fm = FileManager.default
        for path in [url.path, url.path + "-wal", url.path + "-shm"] {
            try? fm.removeItem(atPath: path)
        }
    }

    // MARK: - Private

    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1_expenses") { db in
            try db.create(table: "expenses") { t in
                t.column("id", .text).primaryKey()
                t.column("name", .text).notNull()
                t.column("merchantName", .text).notNull()
                t.column("amountValue", .text).notNull()
                t.column("currencyCode", .text).notNull()
                t.column("categoryId", .text)
                t.column("merchantId", .text)
                t.column("date", .double).notNull()
                t.column("notes", .text)
                t.column("isRecurring", .integer).notNull().defaults(to: 0)
                t.column("recurrenceType", .text)
                t.column("recurrenceConfidence", .double)
                t.column("nextExpectedDate", .double)
                t.column("isSubscriptionLike", .integer).notNull().defaults(to: 0)
                t.column("isTrial", .integer).notNull().defaults(to: 0)
                t.column("subscriptionStartDate", .double)
                t.column("trialEndDate", .double)
                t.column("renewalReminderDays", .integer)
                t.column("heatZoneBucket", .text)
                t.column("emotion", .text)
                t.column("contextTag", .text)
                t.column("hustleId", .text)
                t.column("habitSignatureId", .text)
                t.column("subscriptionConfidence", .double)
                t.column("microCommitmentType", .text)
                t.column("microCommitmentValue", .double)
                t.column("futureImpact1Y", .double)
                t.column("futureImpact5Y", .double)
                t.column("createdAt", .double).notNull()
                t.column("updatedAt", .double).notNull()
                t.column("categoryRaw", .text).notNull()
                t.column("paymentMethod", .text)
                t.column("isBarterExchange", .integer).notNull().defaults(to: 0)
                t.column("barterGoodsGiven", .text)
                t.column("barterGoodsReceived", .text)
                t.column("barterEstimatedValue", .text)
                t.column("bridgeGroupId", .text)
                t.column("bridgeKind", .text)
                t.column("bridgeRole", .text)
                t.column("bridgeSharePercent", .double)
                t.column("bridgePeerExpenseId", .text)
                t.column("bridgeCounterpartyHustleId", .text)
                t.column("isCategorySplit", .integer).notNull().defaults(to: 0)
                t.column("householdScopeRaw", .text).notNull()
                t.column("financeKitTransactionId", .text)
            }

            try db.create(table: "expense_split_lines") { t in
                t.column("id", .text).primaryKey()
                t.column("expenseId", .text)
                    .notNull()
                    .indexed()
                    .references("expenses", onDelete: .cascade)
                t.column("categoryId", .text)
                t.column("categoryRaw", .text).notNull()
                t.column("amountValue", .text).notNull()
                t.column("sortOrder", .integer).notNull()
            }

            try db.create(table: "expense_meta") { t in
                t.column("key", .text).primaryKey()
                t.column("value", .text).notNull()
            }

            try db.create(index: "idx_expenses_date", on: "expenses", columns: ["date"])
            try db.create(index: "idx_expenses_hustle_date", on: "expenses", columns: ["hustleId", "date"])
            try db.create(index: "idx_expenses_updated", on: "expenses", columns: ["updatedAt"])
            try db.execute(sql: """
                CREATE UNIQUE INDEX IF NOT EXISTS idx_expenses_financekit_unique
                ON expenses(financeKitTransactionId)
                WHERE financeKitTransactionId IS NOT NULL
                """)
        }
        migrator.registerMigration("v2_wallet_pending") { db in
            try db.alter(table: "expenses") { t in
                t.add(column: "walletIsPending", .integer).notNull().defaults(to: 0)
            }
        }
        migrator.registerMigration("v3_income_role") { db in
            try db.alter(table: "expenses") { t in
                t.add(column: "incomeRole", .text)
            }
        }
        migrator.registerMigration("v4_wallet_account_id") { db in
            try db.alter(table: "expenses") { t in
                t.add(column: "walletAccountId", .text)
            }
        }
        migrator.registerMigration("v5_wallet_merchant_category_memory") { db in
            try db.create(table: "wallet_merchant_category_memory") { t in
                t.column("normalizedKey", .text).primaryKey()
                t.column("categoryRaw", .text).notNull()
                t.column("updatedAt", .double).notNull()
            }
        }
        migrator.registerMigration("v6_wallet_category_metadata") { db in
            try db.alter(table: "expenses") { t in
                t.add(column: "walletCategoryUserConfirmed", .integer).notNull().defaults(to: 0)
                t.add(column: "walletCategoryConfidence", .text)
            }
        }
        return migrator
    }

    private static func databaseURL() -> URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return support.appendingPathComponent(fileName)
    }

    private static func metaFlag(_ db: Database, key: String) throws -> Bool {
        let value = try String.fetchOne(db, sql: "SELECT value FROM expense_meta WHERE key = ?", arguments: [key])
        return value == "1"
    }

    private static func setMetaFlag(_ db: Database, key: String, value: Bool) throws {
        try db.execute(
            sql: "INSERT OR REPLACE INTO expense_meta (key, value) VALUES (?, ?)",
            arguments: [key, value ? "1" : "0"]
        )
    }

    private static func workspaceClause(
        hustleId: UUID?,
        includeUnassigned: Bool
    ) -> (sql: String, arguments: [DatabaseValueConvertible]) {
        guard let hustleId else { return ("", []) }
        if includeUnassigned {
            return (" AND (hustleId = ? OR hustleId IS NULL)", [hustleId.uuidString])
        }
        return (" AND hustleId = ?", [hustleId.uuidString])
    }

    private static func fetchArchiveMonthIndex(
        db: Database,
        before monthStart: Double,
        hustleId: UUID?,
        includeUnassigned: Bool
    ) throws -> [ArchiveMonthRow] {
        let workspace = workspaceClause(hustleId: hustleId, includeUnassigned: includeUnassigned)
        let rows = try Row.fetchAll(db, sql: """
            SELECT
                CAST(strftime('%s', strftime('%Y-%m-01', datetime(date, 'unixepoch'))) AS REAL) AS monthStart,
                COUNT(*) AS transactionCount
            FROM expenses
            WHERE date < ?\(workspace.sql)
            GROUP BY strftime('%Y-%m', datetime(date, 'unixepoch'))
            ORDER BY monthStart DESC
            """, arguments: StatementArguments([monthStart] + workspace.arguments))

        var archiveRows: [ArchiveMonthRow] = []
        archiveRows.reserveCapacity(rows.count)
        for row in rows {
            guard let start = row["monthStart"] as Double?,
                  let count = row["transactionCount"] as Int? else { continue }
            archiveRows.append(ArchiveMonthRow(monthStart: start, transactionCount: count))
        }
        return archiveRows
    }

    private static func fetchSplitRows(for expenseRows: [Row], db: Database) throws -> [Row] {
        guard !expenseRows.isEmpty else { return [] }
        let ids = expenseRows.compactMap { $0["id"] as String? }
        let placeholders = Array(repeating: "?", count: ids.count).joined(separator: ", ")
        return try Row.fetchAll(
            db,
            sql: "SELECT * FROM expense_split_lines WHERE expenseId IN (\(placeholders)) ORDER BY sortOrder ASC",
            arguments: StatementArguments(ids)
        )
    }

    private static func insertExpense(_ payload: ExpenseWritePayload, db: Database) throws {
        let args = payload.expenseArguments.map(\.asDatabaseValue)
        try db.execute(sql: payload.insertSQL, arguments: StatementArguments(args))
        try db.execute(sql: "DELETE FROM expense_split_lines WHERE expenseId = ?", arguments: [payload.expenseId])
        for line in payload.splitLines {
            try db.execute(
                sql: """
                INSERT OR REPLACE INTO expense_split_lines
                (id, expenseId, categoryId, categoryRaw, amountValue, sortOrder)
                VALUES (?, ?, ?, ?, ?, ?)
                """,
                arguments: [
                    line.id,
                    line.expenseId,
                    line.categoryId,
                    line.categoryRaw,
                    line.amountValue,
                    line.sortOrder
                ]
            )
        }
    }
}
