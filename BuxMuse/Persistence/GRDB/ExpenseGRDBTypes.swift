//
//  ExpenseGRDBTypes.swift
//  BuxMuse
//
//  Value types for the GRDB expense ledger.
//

import Foundation
import GRDB

public struct ExpenseArchiveMonthIndex: Hashable, Identifiable, Sendable {
    public var id: Date { monthStart }
    public let monthStart: Date
    public let transactionCount: Int
}

nonisolated struct ArchiveMonthRow: Sendable {
    let monthStart: Double
    let transactionCount: Int
}

struct ExpenseLedgerScopePack {
    let currentMonth: [ExpenseRecord]
    let lastMonth: [ExpenseRecord]
    let pendingWallet: [ExpenseRecord]
    let archiveMonths: [ExpenseArchiveMonthIndex]
}

/// Read-only GRDB rows fetched on `ExpenseDatabaseSQL`'s queue; immutable before handoff to MainActor.
nonisolated struct ExpenseRowPayload: @unchecked Sendable {
    let expenses: [Row]
    let splits: [Row]
}

nonisolated struct LedgerScopeRaw: @unchecked Sendable {
    let current: [Row]
    let last: [Row]
    let pending: [Row]
    let splits: [Row]
    let archive: [ArchiveMonthRow]
}

nonisolated struct MonthlyOutflowTotal: Sendable {
    let monthStart: Double
    let total: Double
}

nonisolated enum ExpenseSQLValue: Sendable {
    case null
    case text(String)
    case int(Int)
    case double(Double)

    nonisolated init(databaseValue: DatabaseValueConvertible?) {
        switch databaseValue {
        case nil:
            self = .null
        case let value as String:
            self = .text(value)
        case let value as Int:
            self = .int(value)
        case let value as Double:
            self = .double(value)
        default:
            self = .text(String(describing: databaseValue!))
        }
    }

    nonisolated var asDatabaseValue: DatabaseValueConvertible? {
        switch self {
        case .null: return nil
        case .text(let value): return value
        case .int(let value): return value
        case .double(let value): return value
        }
    }
}

nonisolated struct ExpenseSplitWritePayload: Sendable {
    let id: String
    let expenseId: String
    let categoryId: String?
    let categoryRaw: String?
    let amountValue: String
    let sortOrder: Int
}

nonisolated struct ExpenseWritePayload: Sendable {
    let expenseArguments: [ExpenseSQLValue]
    let insertSQL: String
    let expenseId: String
    let splitLines: [ExpenseSplitWritePayload]
}

struct ExpenseGRDBMigrationManifest: Codable, Equatable, Sendable {
    var importedExpenseCount: Int
    var importedSplitLineCount: Int
    var completedAt: Date
    var success: Bool
}
