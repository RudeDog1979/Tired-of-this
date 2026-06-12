//
//  StandardBudgetStudioBridge.swift
//  BuxMuse
//
//  Optional mirror of Studio money-in into the Standard budget pool.
//

import Foundation

struct StandardBudgetStudioSupplement: Equatable, Sendable {
    var counted: Decimal
    var excludedByDedup: Decimal
}

enum StandardBudgetStudioBridge {

    private static let syntheticInvoiceNotes = "TaxEnvelope synthetic"

    /// Sum of Simple Studio money-in entries in the pay period, minus amounts already logged in Add Income.
    static func supplementalIncome(
        period: DateInterval,
        entries: [SimpleStudioEntry],
        incomeRecords: [ExpenseRecord],
        fundingSource: IncomeFundingSource,
        studioEnabled: Bool,
        studioMode: StudioMode = .simple,
        includeInBudget: Bool,
        calendar: Calendar = .current,
        locale: Locale = BuxInterfaceLocale.currentInterfaceLocale
    ) -> StandardBudgetStudioSupplement {
        guard studioEnabled, studioMode == .simple, includeInBudget else {
            return .init(counted: 0, excludedByDedup: 0)
        }

        var unmatchedIncome = incomeFingerprints(
            records: incomeRecords,
            fundingSource: fundingSource,
            period: period,
            calendar: calendar,
            locale: locale
        )
        var counted: Decimal = 0
        var excluded: Decimal = 0

        for entry in entries where entry.createdAt >= period.start && entry.createdAt < period.end {
            let amount = TaxEnvelopeContextBridge.incomeAmount(for: entry)
            guard amount > 0 else { continue }
            let day = calendar.startOfDay(for: entry.createdAt)
            if consumeMatchingIncome(amount: amount, day: day, from: &unmatchedIncome) {
                excluded += amount
            } else {
                counted += amount
            }
        }

        return StandardBudgetStudioSupplement(counted: counted, excludedByDedup: excluded)
    }

    /// Sum of paid Pro Studio invoices in the pay period, minus amounts already logged in Add Income.
    static func proSupplementalIncome(
        period: DateInterval,
        invoices: [StudioInvoice],
        incomeRecords: [ExpenseRecord],
        fundingSource: IncomeFundingSource,
        studioEnabled: Bool,
        studioMode: StudioMode,
        includeInBudget: Bool,
        calendar: Calendar = .current,
        locale: Locale = BuxInterfaceLocale.currentInterfaceLocale
    ) -> StandardBudgetStudioSupplement {
        guard studioEnabled, studioMode == .pro, includeInBudget else {
            return .init(counted: 0, excludedByDedup: 0)
        }

        var unmatchedIncome = incomeFingerprints(
            records: incomeRecords,
            fundingSource: fundingSource,
            period: period,
            calendar: calendar,
            locale: locale
        )
        var counted: Decimal = 0
        var excluded: Decimal = 0

        for invoice in invoices {
            guard invoice.status == .paid,
                  let paymentDate = invoice.paymentDate,
                  paymentDate >= period.start,
                  paymentDate < period.end,
                  invoice.total > 0,
                  invoice.notes != syntheticInvoiceNotes else {
                continue
            }
            let day = calendar.startOfDay(for: paymentDate)
            if consumeMatchingIncome(amount: invoice.total, day: day, from: &unmatchedIncome) {
                excluded += invoice.total
            } else {
                counted += invoice.total
            }
        }

        return StandardBudgetStudioSupplement(counted: counted, excludedByDedup: excluded)
    }

    // MARK: - Dedup

    static func incomeFingerprints(
        records: [ExpenseRecord],
        fundingSource: IncomeFundingSource,
        period: DateInterval,
        calendar: Calendar,
        locale: Locale
    ) -> [(day: Date, amount: Decimal)] {
        records
            .filter { $0.date >= period.start && $0.date < period.end }
            .filter { record in
                fundingSource == .salary
                    ? BudgetEnvelopeEngine.isSalaryIncome(record: record, locale: locale)
                    : BudgetEnvelopeEngine.isOtherIncome(record: record, locale: locale)
            }
            .map { (day: calendar.startOfDay(for: $0.date), amount: abs($0.amountValue)) }
    }

    private static func consumeMatchingIncome(
        amount: Decimal,
        day: Date,
        from fingerprints: inout [(day: Date, amount: Decimal)]
    ) -> Bool {
        guard let index = fingerprints.firstIndex(where: { $0.day == day && $0.amount == amount }) else {
            return false
        }
        fingerprints.remove(at: index)
        return true
    }
}
