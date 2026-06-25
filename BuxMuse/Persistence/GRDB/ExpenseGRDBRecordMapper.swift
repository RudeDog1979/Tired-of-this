//
//  ExpenseGRDBRecordMapper.swift
//  BuxMuse
//
//  Maps ExpenseRecord ↔ GRDB row dictionaries.
//

import Foundation
import GRDB

enum ExpenseGRDBRecordMapper {
    private static let expenseColumns = [
        "id", "name", "merchantName", "amountValue", "currencyCode", "categoryId", "merchantId",
        "date", "notes", "isRecurring", "recurrenceType", "recurrenceConfidence", "nextExpectedDate",
        "isSubscriptionLike", "isTrial", "subscriptionStartDate", "trialEndDate", "renewalReminderDays",
        "heatZoneBucket", "emotion", "contextTag", "hustleId", "habitSignatureId",
        "subscriptionConfidence", "microCommitmentType", "microCommitmentValue",
        "futureImpact1Y", "futureImpact5Y", "createdAt", "updatedAt", "categoryRaw", "paymentMethod",
        "isBarterExchange", "barterGoodsGiven", "barterGoodsReceived", "barterEstimatedValue",
        "bridgeGroupId", "bridgeKind", "bridgeRole", "bridgeSharePercent", "bridgePeerExpenseId",
        "bridgeCounterpartyHustleId", "isCategorySplit", "householdScopeRaw", "financeKitTransactionId",
        "walletAccountId", "walletIsPending", "incomeRole", "walletCategoryUserConfirmed", "walletCategoryConfidence",
        "isExcludedFromSpending"
    ]

    static func expenseArguments(for record: ExpenseRecord) -> [DatabaseValueConvertible?] {
        [
            record.id.uuidString,
            record.name,
            record.merchantName,
            decimalString(record.amountValue),
            record.currencyCode,
            record.categoryId?.uuidString,
            record.merchantId?.uuidString,
            record.date.timeIntervalSince1970,
            record.notes,
            record.isRecurring ? 1 : 0,
            record.recurrenceType,
            record.recurrenceConfidence,
            optionalTimestamp(record.nextExpectedDate),
            record.isSubscriptionLike ? 1 : 0,
            record.isTrial ? 1 : 0,
            optionalTimestamp(record.subscriptionStartDate),
            optionalTimestamp(record.trialEndDate),
            record.renewalReminderDays,
            record.heatZoneBucket,
            record.emotion,
            record.contextTag,
            record.hustleId?.uuidString,
            record.habitSignatureId,
            record.subscriptionConfidence,
            record.microCommitmentType,
            record.microCommitmentValue,
            record.futureImpact1Y,
            record.futureImpact5Y,
            record.createdAt.timeIntervalSince1970,
            record.updatedAt.timeIntervalSince1970,
            record.categoryRaw,
            record.paymentMethod,
            record.isBarterExchange ? 1 : 0,
            record.barterGoodsGiven,
            record.barterGoodsReceived,
            optionalDecimalString(record.barterEstimatedValue),
            record.bridgeGroupId?.uuidString,
            record.bridgeKind,
            record.bridgeRole,
            record.bridgeSharePercent,
            record.bridgePeerExpenseId?.uuidString,
            record.bridgeCounterpartyHustleId?.uuidString,
            record.isCategorySplit ? 1 : 0,
            record.householdScope.rawValue,
            record.financeKitTransactionId,
            record.walletAccountId,
            record.walletIsPending ? 1 : 0,
            record.incomeRole,
            record.walletCategoryUserConfirmed ? 1 : 0,
            record.walletCategoryConfidence,
            record.isExcludedFromSpending ? 1 : 0
        ]
    }

    static func insertSQL() -> String {
        let placeholders = Array(repeating: "?", count: expenseColumns.count).joined(separator: ", ")
        return "INSERT OR REPLACE INTO expenses (\(expenseColumns.joined(separator: ", "))) VALUES (\(placeholders))"
    }

    static func record(from row: Row, splitLines: [ExpenseSplitLineRecord]) -> ExpenseRecord {
        var record = ExpenseRecord(
            id: uuid(row, "id") ?? UUID(),
            name: row["name"] as String? ?? "",
            amountValue: decimal(row, "amountValue") ?? 0,
            currencyCode: row["currencyCode"] as String? ?? "USD",
            categoryId: uuid(row, "categoryId"),
            merchantId: uuid(row, "merchantId"),
            date: timestamp(row, "date") ?? Date(),
            notes: row["notes"] as String?,
            isRecurring: bool(row, "isRecurring"),
            recurrenceType: row["recurrenceType"] as String?,
            recurrenceConfidence: row["recurrenceConfidence"] as Double?,
            nextExpectedDate: optionalDate(row, "nextExpectedDate"),
            isSubscriptionLike: bool(row, "isSubscriptionLike"),
            isTrial: bool(row, "isTrial"),
            subscriptionStartDate: optionalDate(row, "subscriptionStartDate"),
            trialEndDate: optionalDate(row, "trialEndDate"),
            renewalReminderDays: row["renewalReminderDays"] as Int?,
            heatZoneBucket: row["heatZoneBucket"] as String?,
            emotion: row["emotion"] as String?,
            contextTag: row["contextTag"] as String?,
            habitSignatureId: row["habitSignatureId"] as String?,
            subscriptionConfidence: row["subscriptionConfidence"] as Double?,
            microCommitmentType: row["microCommitmentType"] as String?,
            microCommitmentValue: row["microCommitmentValue"] as Double?,
            futureImpact1Y: row["futureImpact1Y"] as Double?,
            futureImpact5Y: row["futureImpact5Y"] as Double?,
            createdAt: timestamp(row, "createdAt") ?? Date(),
            updatedAt: timestamp(row, "updatedAt") ?? Date(),
            categoryRaw: row["categoryRaw"] as String? ?? TransactionCategory.other.rawValue,
            merchantName: row["merchantName"] as String? ?? "",
            hustleId: uuid(row, "hustleId"),
            paymentMethod: row["paymentMethod"] as String?,
            isBarterExchange: bool(row, "isBarterExchange"),
            barterGoodsGiven: row["barterGoodsGiven"] as String?,
            barterGoodsReceived: row["barterGoodsReceived"] as String?,
            barterEstimatedValue: optionalDecimal(row, "barterEstimatedValue"),
            bridgeGroupId: uuid(row, "bridgeGroupId"),
            bridgeKind: row["bridgeKind"] as String?,
            bridgeRole: row["bridgeRole"] as String?,
            bridgeSharePercent: row["bridgeSharePercent"] as Double?,
            bridgePeerExpenseId: uuid(row, "bridgePeerExpenseId"),
            bridgeCounterpartyHustleId: uuid(row, "bridgeCounterpartyHustleId"),
            isCategorySplit: bool(row, "isCategorySplit"),
            splitLines: splitLines,
            householdScope: HouseholdScope(rawValue: row["householdScopeRaw"] as String? ?? "") ?? .personal,
            isExcludedFromSpending: bool(row, "isExcludedFromSpending")
        )
        record.financeKitTransactionId = row["financeKitTransactionId"] as String?
        record.walletAccountId = row["walletAccountId"] as String?
        record.walletIsPending = bool(row, "walletIsPending")
        record.incomeRole = row["incomeRole"] as String?
        record.walletCategoryUserConfirmed = bool(row, "walletCategoryUserConfirmed")
        record.walletCategoryConfidence = row["walletCategoryConfidence"] as String?
        return record
    }

    static func splitLine(from row: Row) -> ExpenseSplitLineRecord {
        ExpenseSplitLineRecord(
            id: uuid(row, "id") ?? UUID(),
            categoryId: uuid(row, "categoryId"),
            categoryRaw: row["categoryRaw"] as String? ?? TransactionCategory.other.rawValue,
            amountValue: decimal(row, "amountValue") ?? 0,
            sortOrder: row["sortOrder"] as Int? ?? 0
        )
    }

    private static func decimalString(_ value: Decimal) -> String {
        NSDecimalNumber(decimal: value).stringValue
    }

    private static func optionalDecimalString(_ value: Decimal?) -> String? {
        value.map { NSDecimalNumber(decimal: $0).stringValue }
    }

    private static func optionalTimestamp(_ date: Date?) -> Double? {
        date?.timeIntervalSince1970
    }

    private static func uuid(_ row: Row, _ column: String) -> UUID? {
        guard let raw = row[column] as String? else { return nil }
        return UUID(uuidString: raw)
    }

    private static func timestamp(_ row: Row, _ column: String) -> Date? {
        guard let value = row[column] as Double? else { return nil }
        return Date(timeIntervalSince1970: value)
    }

    private static func optionalDate(_ row: Row, _ column: String) -> Date? {
        timestamp(row, column)
    }

    private static func decimal(_ row: Row, _ column: String) -> Decimal? {
        if let string = row[column] as String?, let value = Decimal(string: string) {
            return value
        }
        if let double = row[column] as Double? {
            return Decimal(double)
        }
        return nil
    }

    private static func optionalDecimal(_ row: Row, _ column: String) -> Decimal? {
        decimal(row, column)
    }

    private static func bool(_ row: Row, _ column: String) -> Bool {
        (row[column] as Int? ?? 0) != 0
    }

    // MARK: - Batch mapping (MainActor only)

    @MainActor
    static func makeRecords(from payload: ExpenseRowPayload) -> [ExpenseRecord] {
        mapRecords(from: payload.expenses, splitRows: payload.splits)
    }

    @MainActor
    static func makeLedgerScopePack(from raw: LedgerScopeRaw) -> ExpenseLedgerScopePack {
        ExpenseLedgerScopePack(
            currentMonth: mapRecords(from: raw.current, splitRows: raw.splits),
            lastMonth: mapRecords(from: raw.last, splitRows: raw.splits),
            pendingWallet: mapRecords(from: raw.pending, splitRows: raw.splits),
            archiveMonths: mapArchiveMonths(from: raw.archive)
        )
    }

    @MainActor
    static func writePayload(for record: ExpenseRecord) -> ExpenseWritePayload {
        let args = expenseArguments(for: record)
        var sqlValues: [ExpenseSQLValue] = []
        sqlValues.reserveCapacity(args.count)
        for arg in args {
            sqlValues.append(ExpenseSQLValue(databaseValue: arg))
        }
        var splitLines: [ExpenseSplitWritePayload] = []
        splitLines.reserveCapacity(record.splitLines.count)
        for (index, line) in record.splitLines.enumerated() {
            splitLines.append(
                ExpenseSplitWritePayload(
                    id: line.id.uuidString,
                    expenseId: record.id.uuidString,
                    categoryId: line.categoryId?.uuidString,
                    categoryRaw: line.categoryRaw,
                    amountValue: NSDecimalNumber(decimal: line.amountValue).stringValue,
                    sortOrder: line.sortOrder == 0 ? index : line.sortOrder
                )
            )
        }
        return ExpenseWritePayload(
            expenseArguments: sqlValues,
            insertSQL: insertSQL(),
            expenseId: record.id.uuidString,
            splitLines: splitLines
        )
    }

    @MainActor
    static func writePayloads(for records: [ExpenseRecord]) -> [ExpenseWritePayload] {
        var payloads: [ExpenseWritePayload] = []
        payloads.reserveCapacity(records.count)
        for record in records {
            payloads.append(writePayload(for: record))
        }
        return payloads
    }

    private static func mapRecords(from expenseRows: [Row], splitRows: [Row]) -> [ExpenseRecord] {
        guard !expenseRows.isEmpty else { return [] }
        let splitsByExpense = Dictionary(grouping: splitRows, by: { $0["expenseId"] as String? ?? "" })
        var records: [ExpenseRecord] = []
        records.reserveCapacity(expenseRows.count)
        for row in expenseRows {
            let expenseId = row["id"] as String? ?? ""
            var lines: [ExpenseSplitLineRecord] = []
            for splitRow in splitsByExpense[expenseId] ?? [] {
                lines.append(splitLine(from: splitRow))
            }
            records.append(record(from: row, splitLines: lines))
        }
        return records
    }

    private static func mapArchiveMonths(from rows: [ArchiveMonthRow]) -> [ExpenseArchiveMonthIndex] {
        var months: [ExpenseArchiveMonthIndex] = []
        months.reserveCapacity(rows.count)
        for row in rows {
            months.append(ExpenseArchiveMonthIndex(
                monthStart: Date(timeIntervalSince1970: row.monthStart),
                transactionCount: row.transactionCount
            ))
        }
        return months
    }
}
