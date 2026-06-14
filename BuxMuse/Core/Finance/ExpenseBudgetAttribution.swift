//
//  ExpenseBudgetAttribution.swift
//  BuxMuse
//
//  Expands expenses into per-category budget lines (supports category splits).
//

import Foundation

struct ExpenseBudgetAttributionLine: Equatable, Sendable {
    var expenseId: UUID
    var categoryId: UUID?
    var categoryRaw: String
    var amount: Decimal
    var householdScope: HouseholdScope
    var date: Date

    var transactionCategory: TransactionCategory {
        TransactionCategory(rawValue: categoryRaw) ?? .other
    }
}

enum ExpenseBudgetAttribution {
    static func lines(for record: ExpenseRecord) -> [ExpenseBudgetAttributionLine] {
        guard record.amountValue < 0 else { return [] }

        if record.isCategorySplit, !record.splitLines.isEmpty {
            return record.splitLines
                .sorted { $0.sortOrder < $1.sortOrder }
                .map { line in
                    ExpenseBudgetAttributionLine(
                        expenseId: record.id,
                        categoryId: line.categoryId,
                        categoryRaw: line.categoryRaw,
                        amount: abs(line.amountValue),
                        householdScope: record.householdScope,
                        date: record.date
                    )
                }
        }

        return [
            ExpenseBudgetAttributionLine(
                expenseId: record.id,
                categoryId: record.categoryId,
                categoryRaw: record.categoryRaw,
                amount: abs(record.amountValue),
                householdScope: record.householdScope,
                date: record.date
            )
        ]
    }

    static func lines(for records: [ExpenseRecord]) -> [ExpenseBudgetAttributionLine] {
        records.flatMap { lines(for: $0) }
    }
}
