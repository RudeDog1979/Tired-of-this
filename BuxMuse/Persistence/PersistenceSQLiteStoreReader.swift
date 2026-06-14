//
//  PersistenceSQLiteStoreReader.swift
//  BuxMuse
//
//  Reads legacy SwiftData/Core Data SQLite stores without loading a ModelContainer.
//

import Foundation
import SQLite3

enum PersistenceSQLiteStoreReader {

    struct StoreCounts: Equatable {
        let expenses: Int
        let goals: Int
        let debts: Int
        let merchants: Int
        let categories: Int

        var totalFinancialRows: Int { expenses + goals + debts }
    }

    struct LegacyStoreCandidate: Equatable {
        let storeName: String
        let storeURL: URL
        let sqliteURL: URL
        let counts: StoreCounts
    }

    // MARK: - Discovery

    static func discoverLegacyCandidates(excludingStoreName: String) -> [LegacyStoreCandidate] {
        let supportURL = applicationSupportURL()
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: supportURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var names = Set<String>()
        for url in contents where url.lastPathComponent.hasSuffix(".store") {
            let base = url.lastPathComponent.replacingOccurrences(of: ".store", with: "")
            guard base.hasPrefix("BuxMuse_v"), base != excludingStoreName else { continue }
            names.insert(base)
        }

        return names
            .sorted { lhs, rhs in
                storeVersionNumber(lhs) > storeVersionNumber(rhs)
            }
            .compactMap { name in
                let storeURL = supportURL.appendingPathComponent("\(name).store")
                guard let sqliteURL = resolveSQLiteURL(for: storeURL) else { return nil }
                guard let counts = readCounts(sqliteURL: sqliteURL) else { return nil }
                guard counts.totalFinancialRows > 0 else { return nil }
                return LegacyStoreCandidate(storeName: name, storeURL: storeURL, sqliteURL: sqliteURL, counts: counts)
            }
    }

    static func resolveSQLiteURL(for storeURL: URL) -> URL? {
        let fm = FileManager.default
        var isDirectory: ObjCBool = false
        guard fm.fileExists(atPath: storeURL.path, isDirectory: &isDirectory) else { return nil }

        if !isDirectory.boolValue {
            return storeURL
        }

        if let enumerator = fm.enumerator(at: storeURL, includingPropertiesForKeys: [.isRegularFileKey]) {
            for case let fileURL as URL in enumerator where fileURL.pathExtension == "sqlite" {
                return fileURL
            }
        }

        let directCandidates = ["Data.sqlite", "Store.sqlite", "default.sqlite"]
        for name in directCandidates {
            let candidate = storeURL.appendingPathComponent(name)
            if fm.fileExists(atPath: candidate.path) { return candidate }
            let nested = storeURL.appendingPathComponent("Data/\(name)")
            if fm.fileExists(atPath: nested.path) { return nested }
        }
        return nil
    }

    static func readCounts(sqliteURL: URL) -> StoreCounts? {
        guard let db = openDatabase(sqliteURL) else { return nil }
        defer { sqlite3_close(db) }
        return StoreCounts(
            expenses: tableRowCount(db, table: "ZEXPENSEENTITY"),
            goals: tableRowCount(db, table: "ZGOALENTITY"),
            debts: tableRowCount(db, table: "ZDEBTENTITY"),
            merchants: tableRowCount(db, table: "ZMERCHANTENTITY"),
            categories: tableRowCount(db, table: "ZCATEGORYENTITY")
        )
    }

    // MARK: - Import payloads

    struct ImportedPayload {
        var expenses: [ExpenseRecord] = []
        var goals: [Goal] = []
        var debts: [Debt] = []
    }

    static func readPayload(from candidate: LegacyStoreCandidate) -> ImportedPayload? {
        guard let db = openDatabase(candidate.sqliteURL) else { return nil }
        defer { sqlite3_close(db) }

        var payload = ImportedPayload()
        payload.expenses = readExpenses(db)
        payload.goals = readGoals(db)
        payload.debts = readDebts(db)
        guard !payload.expenses.isEmpty || !payload.goals.isEmpty || !payload.debts.isEmpty else { return nil }
        return payload
    }

    // MARK: - SQLite helpers

    private static func applicationSupportURL() -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
    }

    private static func storeVersionNumber(_ name: String) -> Int {
        Int(name.replacingOccurrences(of: "BuxMuse_v", with: "")) ?? 0
    }

    private static func openDatabase(_ url: URL) -> OpaquePointer? {
        var db: OpaquePointer?
        guard sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            if let db { sqlite3_close(db) }
            return nil
        }
        return db
    }

    private static func tableExists(_ db: OpaquePointer, table: String) -> Bool {
        let sql = "SELECT 1 FROM sqlite_master WHERE type='table' AND name=? LIMIT 1"
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return false }
        sqlite3_bind_text(statement, 1, table, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        return sqlite3_step(statement) == SQLITE_ROW
    }

    private static func tableRowCount(_ db: OpaquePointer, table: String) -> Int {
        guard tableExists(db, table: table) else { return 0 }
        let sql = "SELECT COUNT(*) FROM \(table)"
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return 0 }
        guard sqlite3_step(statement) == SQLITE_ROW else { return 0 }
        return Int(sqlite3_column_int64(statement, 0))
    }

    private static func readExpenses(_ db: OpaquePointer) -> [ExpenseRecord] {
        guard tableExists(db, table: "ZEXPENSEENTITY") else { return [] }
        let sql = "SELECT * FROM ZEXPENSEENTITY"
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK,
              let stmt = statement else { return [] }

        let columns = columnNames(for: stmt)
        let splitLinesByExpensePK = readSplitLinesByExpensePK(db)
        var records: [ExpenseRecord] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let row = SQLiteRow(statement: stmt, columns: columns)
            guard let id = row.value("ZID")?.uuid else { continue }
            let expensePK = row.value("Z_PK")?.int
            let splitLines = expensePK.flatMap { splitLinesByExpensePK[$0] } ?? []
            let record = ExpenseRecord(
                id: id,
                name: row.value("ZNAME")?.string ?? row.value("ZMERCHANTNAME")?.string ?? "",
                amountValue: row.value("ZAMOUNTVALUE")?.decimal ?? 0,
                currencyCode: row.value("ZCURRENCYCODE")?.string ?? "USD",
                categoryId: row.value("ZCATEGORYID")?.uuid,
                merchantId: row.value("ZMERCHANTID")?.uuid,
                date: row.value("ZDATE")?.date ?? Date(),
                notes: row.value("ZNOTES")?.string,
                isRecurring: row.value("ZISRECURRING")?.bool ?? false,
                recurrenceType: row.value("ZRECURRENCETYPE")?.string,
                recurrenceConfidence: row.value("ZRECURRENCECONFIDENCE")?.double,
                nextExpectedDate: row.value("ZNEXTEXPECTEDDATE")?.date,
                isSubscriptionLike: row.value("ZISSUBSCRIPTIONLIKE")?.bool ?? false,
                isTrial: row.value("ZISTRIAL")?.bool ?? false,
                subscriptionStartDate: row.value("ZSUBSCRIPTIONSTARTDATE")?.date,
                trialEndDate: row.value("ZTRIALENDDATE")?.date,
                renewalReminderDays: row.value("ZRENEWALREMINDERDAYS")?.int,
                createdAt: row.value("ZCREATEDAT")?.date ?? row.value("ZDATE")?.date ?? Date(),
                updatedAt: row.value("ZUPDATEDAT")?.date ?? Date(),
                categoryRaw: row.value("ZCATEGORYRAW")?.string ?? TransactionCategory.other.rawValue,
                merchantName: row.value("ZMERCHANTNAME")?.string ?? "",
                hustleId: row.value("ZHUSTLEID")?.uuid,
                paymentMethod: row.value("ZPAYMENTMETHOD")?.string,
                isCategorySplit: row.value("ZISCATEGORYSPLIT")?.bool ?? !splitLines.isEmpty,
                splitLines: splitLines,
                householdScope: HouseholdScope(rawValue: row.value("ZHOUSEHOLDSCOPERAW")?.string ?? "") ?? .personal
            )
            records.append(record)
        }
        return records
    }

    private static func readGoals(_ db: OpaquePointer) -> [Goal] {
        guard tableExists(db, table: "ZGOALENTITY") else { return [] }
        let sql = "SELECT * FROM ZGOALENTITY"
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK,
              let stmt = statement else { return [] }

        let columns = columnNames(for: stmt)
        var goals: [Goal] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let row = SQLiteRow(statement: stmt, columns: columns)
            guard let id = row.value("ZID")?.uuid else { continue }
            goals.append(Goal(
                id: id,
                name: row.value("ZNAME")?.string ?? "Goal",
                targetAmount: row.value("ZTARGETAMOUNT")?.decimal ?? 0,
                currentAmount: row.value("ZCURRENTAMOUNT")?.decimal ?? 0,
                deadline: row.value("ZDEADLINE")?.date,
                priority: row.value("ZPRIORITY")?.int ?? 2,
                notes: row.value("ZNOTES")?.string,
                createdAt: row.value("ZCREATEDAT")?.date ?? Date(),
                contributions: []
            ))
        }
        return goals
    }

    private static func readDebts(_ db: OpaquePointer) -> [Debt] {
        guard tableExists(db, table: "ZDEBTENTITY") else { return [] }
        let sql = "SELECT * FROM ZDEBTENTITY"
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK,
              let stmt = statement else { return [] }

        let columns = columnNames(for: stmt)
        let paymentsByDebtPK = readDebtPaymentsByDebtPK(db)
        var debts: [Debt] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let row = SQLiteRow(statement: stmt, columns: columns)
            guard let id = row.value("ZID")?.uuid else { continue }
            let typeRaw = row.value("ZTYPERAW")?.string ?? DebtType.other.rawValue
            let debtPK = row.value("Z_PK")?.int
            let payments = debtPK.flatMap { paymentsByDebtPK[$0] } ?? []
            debts.append(Debt(
                id: id,
                name: row.value("ZNAME")?.string ?? "Debt",
                type: DebtType(rawValue: typeRaw) ?? .other,
                currentBalance: row.value("ZCURRENTBALANCE")?.decimal ?? 0,
                originalBalance: row.value("ZORIGINALBALANCE")?.decimal,
                aprPercent: row.value("ZAPRPERCENT")?.decimal,
                minimumPayment: row.value("ZMINIMUMPAYMENT")?.decimal,
                dueDayOfMonth: row.value("ZDUEDAYOFMONTH")?.int,
                lender: row.value("ZLENDER")?.string,
                notes: row.value("ZNOTES")?.string,
                isArchived: row.value("ZISARCHIVED")?.bool ?? false,
                createdAt: row.value("ZCREATEDAT")?.date ?? Date(),
                payments: payments
            ))
        }
        return debts
    }

    private static func columnNames(for statement: OpaquePointer) -> [String] {
        let columnCount = sqlite3_column_count(statement)
        return (0..<columnCount).compactMap { index in
            guard let name = sqlite3_column_name(statement, index) else { return nil }
            return String(cString: name)
        }
    }

    private static func readSplitLinesByExpensePK(_ db: OpaquePointer) -> [Int: [ExpenseSplitLineRecord]] {
        guard tableExists(db, table: "ZEXPENSESPLITLINEENTITY") else { return [:] }
        let sql = "SELECT * FROM ZEXPENSESPLITLINEENTITY"
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK,
              let stmt = statement else { return [:] }

        let columns = columnNames(for: stmt)
        var grouped: [Int: [ExpenseSplitLineRecord]] = [:]
        while sqlite3_step(stmt) == SQLITE_ROW {
            let row = SQLiteRow(statement: stmt, columns: columns)
            guard let expensePK = row.value("ZEXPENSE")?.int,
                  let id = row.value("ZID")?.uuid else { continue }
            let line = ExpenseSplitLineRecord(
                id: id,
                categoryId: row.value("ZCATEGORYID")?.uuid,
                categoryRaw: row.value("ZCATEGORYRAW")?.string ?? TransactionCategory.other.rawValue,
                amountValue: row.value("ZAMOUNTVALUE")?.decimal ?? 0,
                sortOrder: row.value("ZSORTORDER")?.int ?? 0
            )
            grouped[expensePK, default: []].append(line)
        }
        return grouped
    }

    private static func readDebtPaymentsByDebtPK(_ db: OpaquePointer) -> [Int: [DebtPayment]] {
        guard tableExists(db, table: "ZDEBTPAYMENTENTITY") else { return [:] }
        let sql = "SELECT * FROM ZDEBTPAYMENTENTITY"
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK,
              let stmt = statement else { return [:] }

        let columns = columnNames(for: stmt)
        var grouped: [Int: [DebtPayment]] = [:]
        while sqlite3_step(stmt) == SQLITE_ROW {
            let row = SQLiteRow(statement: stmt, columns: columns)
            guard let debtPK = row.value("ZDEBT")?.int,
                  let id = row.value("ZID")?.uuid else { continue }
            let payment = DebtPayment(
                id: id,
                amount: row.value("ZAMOUNT")?.decimal ?? 0,
                date: row.value("ZDATE")?.date ?? Date(),
                notes: row.value("ZNOTES")?.string,
                linkedExpenseId: row.value("ZLINKEDEXPENSEID")?.uuid
            )
            grouped[debtPK, default: []].append(payment)
        }
        return grouped
    }
}

private struct SQLiteRow {
    let statement: OpaquePointer
    let columns: [String]

    func value(_ name: String) -> SQLiteValue? {
        guard let idx = columns.firstIndex(of: name) else { return nil }
        return SQLiteValue(statement: statement, index: Int32(idx))
    }
}

// MARK: - SQLite value parsing

private struct SQLiteValue {
    let statement: OpaquePointer
    let index: Int32

    var type: Int32 { sqlite3_column_type(statement, index) }

    var string: String? {
        guard let cString = sqlite3_column_text(statement, index) else { return nil }
        return String(cString: cString)
    }

    var double: Double? {
        guard type != SQLITE_NULL else { return nil }
        return sqlite3_column_double(statement, index)
    }

    var int: Int? {
        guard type != SQLITE_NULL else { return nil }
        return Int(sqlite3_column_int64(statement, index))
    }

    var bool: Bool {
        if let int { return int != 0 }
        if let string {
            switch string.lowercased() {
            case "1", "true", "yes": return true
            default: return false
            }
        }
        return false
    }

    var decimal: Decimal? {
        if let string, let decimal = Decimal(string: string) { return decimal }
        if let double { return Decimal(double) }
        return nil
    }

    var date: Date? {
        guard let seconds = double else { return nil }
        // Core Data reference date (2001-01-01).
        if seconds > 1_000_000_000 {
            return Date(timeIntervalSince1970: seconds)
        }
        return Date(timeIntervalSinceReferenceDate: seconds)
    }

    var uuid: UUID? {
        guard type == SQLITE_BLOB else {
            if let string, let uuid = UUID(uuidString: string) { return uuid }
            return nil
        }
        let bytes = sqlite3_column_blob(statement, index)
        let length = Int(sqlite3_column_bytes(statement, index))
        guard let bytes, length == 16 else { return nil }
        let data = Data(bytes: bytes, count: length)
        return data.withUnsafeBytes { raw in
            let tuple = raw.bindMemory(to: UInt8.self)
            guard tuple.count == 16 else { return nil }
            return UUID(uuid: (
                tuple[0], tuple[1], tuple[2], tuple[3],
                tuple[4], tuple[5], tuple[6], tuple[7],
                tuple[8], tuple[9], tuple[10], tuple[11],
                tuple[12], tuple[13], tuple[14], tuple[15]
            ))
        }
    }
}
