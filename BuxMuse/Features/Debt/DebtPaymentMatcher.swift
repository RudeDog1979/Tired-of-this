//
//  DebtPaymentMatcher.swift
//  BuxMuse
//
//  Suggests which consumer debt an expense payment likely belongs to.
//

import Foundation

struct DebtPaymentSuggestion: Identifiable, Equatable {
    let debt: Debt
    let score: Int
    let reasonKeys: [String]

    var id: UUID { debt.id }
}

enum DebtPaymentMatcher {
    private static let dueWindowDays = 7
    private static let amountTolerance = 0.15

    static func suggestions(
        for record: ExpenseRecord,
        debts: [Debt]
    ) -> [DebtPaymentSuggestion] {
        guard record.isSpendingOutflow else { return [] }

        let paymentAmount = abs(record.amountDouble)
        guard paymentAmount > 0 else { return [] }

        let candidates = debts.filter { !$0.isArchived && $0.currentBalance > 0 }
        guard !candidates.isEmpty else { return [] }

        let expenseKey = normalizeMatchKey(from: record.merchantName.isEmpty ? record.name : record.merchantName)
        let expenseNameKey = normalizeMatchKey(from: record.name)

        return candidates.compactMap { debt in
            var score = 0
            var reasons: [String] = []

            if merchantMatches(expenseKey: expenseKey, expenseNameKey: expenseNameKey, debt: debt) {
                score += 50
                reasons.append("Merchant matches lender")
            }

            if let minimum = debt.minimumPayment, minimum > 0,
               amountsMatch(paymentAmount, NSDecimalNumber(decimal: minimum).doubleValue) {
                score += 35
                reasons.append("Matches minimum payment")
            }

            if amountsMatch(
                paymentAmount,
                NSDecimalNumber(decimal: debt.currentBalance).doubleValue
            ) {
                score += 25
                reasons.append("Matches current balance")
            }

            if let days = debt.daysUntilDue, days >= 0, days <= dueWindowDays {
                score += 20
                reasons.append("Due soon")
            }

            if debt.paidThisMonth == 0 {
                score += 10
                reasons.append("No payment logged this month")
            }

            guard score > 0 else { return nil }
            return DebtPaymentSuggestion(debt: debt, score: score, reasonKeys: reasons)
        }
        .sorted { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score > rhs.score }
            return lhs.debt.name.localizedCaseInsensitiveCompare(rhs.debt.name) == .orderedAscending
        }
    }

    static func bestMatch(for record: ExpenseRecord, debts: [Debt]) -> Debt? {
        suggestions(for: record, debts: debts).first?.debt
    }

    private static func normalizeMatchKey(from label: String) -> String {
        MerchantLogoEngine.normalizeMerchantName(label)
    }

    private static func merchantMatches(expenseKey: String, expenseNameKey: String, debt: Debt) -> Bool {
        let debtKeys = [debt.name, debt.lender ?? "", debt.logoMerchantName]
            .map { normalizeMatchKey(from: $0) }
            .filter { !$0.isEmpty }

        guard !debtKeys.isEmpty else { return false }

        let expenseKeys = [expenseKey, expenseNameKey].filter { !$0.isEmpty }
        guard !expenseKeys.isEmpty else { return false }

        return debtKeys.contains { debtKey in
            expenseKeys.contains { expenseKey in
                expenseKey == debtKey
                    || expenseKey.contains(debtKey)
                    || debtKey.contains(expenseKey)
            }
        }
    }

    private static func amountsMatch(_ amount: Double, _ target: Double) -> Bool {
        guard target > 0 else { return false }
        return abs(amount - target) <= max(0.01, target * amountTolerance)
    }
}
