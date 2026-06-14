//
//  BudgetPeriodEngine.swift
//  BuxMuse
//
//  Pay-period budget math — earned income, optional cap, discretionary vs essential spend.
//

import Foundation

struct StandardBudgetResult: Equatable, Sendable {
    var earnedThisPeriod: Decimal
    var spendingCapThisPeriod: Decimal?
    var effectiveLimit: Decimal
    var discretionarySpent: Decimal
    var essentialSpent: Decimal
    var remaining: Decimal

    init(
        earnedThisPeriod: Decimal,
        spendingCapThisPeriod: Decimal?,
        effectiveLimit: Decimal,
        discretionarySpent: Decimal,
        essentialSpent: Decimal,
        remaining: Decimal
    ) {
        self.earnedThisPeriod = earnedThisPeriod
        self.spendingCapThisPeriod = spendingCapThisPeriod
        self.effectiveLimit = effectiveLimit
        self.discretionarySpent = discretionarySpent
        self.essentialSpent = essentialSpent
        self.remaining = remaining
    }
}

enum BudgetPeriodEngine {

    /// Housing and utilities — essential living costs excluded from Standard budget progress.
    static let essentialLivingCategories: Set<TransactionCategory> = [.housing, .utilities]

    // MARK: - Standard (merged income + optional cap)

    static func computeStandardBudget(
        records: [ExpenseRecord],
        fundingSource: IncomeFundingSource,
        period: DateInterval,
        spendingCap: Decimal,
        categoryRecords: [ExpenseCategoryRecord],
        supplementalEarned: Decimal = 0,
        locale: Locale = BuxInterfaceLocale.currentInterfaceLocale
    ) -> StandardBudgetResult {
        let earned = BudgetEnvelopeEngine.incomePool(
            records: records,
            fundingSource: fundingSource,
            period: period,
            locale: locale
        ) + supplementalEarned
        let cap = spendingCap > 0 ? spendingCap : nil
        let effectiveLimit = resolveEffectiveLimit(earned: earned, cap: cap)

        let periodExpenses = records.filter {
            $0.amountValue < 0 && $0.date >= period.start && $0.date < period.end
        }
        var essential: Decimal = 0
        var discretionary: Decimal = 0
        for line in ExpenseBudgetAttribution.lines(for: periodExpenses) {
            if isEssentialLivingAttribution(line, categoryRecords: categoryRecords) {
                essential += line.amount
            } else {
                discretionary += line.amount
            }
        }

        return StandardBudgetResult(
            earnedThisPeriod: earned,
            spendingCapThisPeriod: cap,
            effectiveLimit: effectiveLimit,
            discretionarySpent: discretionary,
            essentialSpent: essential,
            remaining: effectiveLimit - discretionary
        )
    }

    /// Earned income is primary; optional cap tightens the limit. Cap alone applies when no income logged yet.
    static func resolveEffectiveLimit(earned: Decimal, cap: Decimal?) -> Decimal {
        let activeCap = cap.flatMap { $0 > 0 ? $0 : nil }
        if earned > 0 {
            if let activeCap { return min(earned, activeCap) }
            return earned
        }
        return activeCap ?? 0
    }

    static func isEssentialLivingExpense(
        _ record: ExpenseRecord,
        categoryRecords: [ExpenseCategoryRecord]
    ) -> Bool {
        ExpenseBudgetAttribution.lines(for: record).contains {
            isEssentialLivingAttribution($0, categoryRecords: categoryRecords)
        }
    }

    static func isEssentialLivingAttribution(
        _ line: ExpenseBudgetAttributionLine,
        categoryRecords: [ExpenseCategoryRecord]
    ) -> Bool {
        if essentialLivingCategories.contains(line.transactionCategory) {
            return true
        }
        if let categoryId = line.categoryId,
           let custom = categoryRecords.first(where: { $0.id == categoryId }),
           let raw = custom.systemCategoryRaw,
           let system = TransactionCategory(rawValue: raw),
           essentialLivingCategories.contains(system) {
            return true
        }
        if let system = TransactionCategory(rawValue: line.categoryRaw),
           essentialLivingCategories.contains(system) {
            return true
        }
        return false
    }

    // MARK: - Expense entry warnings (Standard budget)

    static func projectedStandardBudgetWarning(
        records: [ExpenseRecord],
        fundingSource: IncomeFundingSource,
        period: DateInterval,
        spendingCap: Decimal,
        categoryRecords: [ExpenseCategoryRecord],
        additionalAmount: Decimal,
        additionalIsEssential: Bool,
        supplementalEarned: Decimal = 0,
        approachingThresholdPercent: Int,
        locale: Locale = BuxInterfaceLocale.currentInterfaceLocale
    ) -> (status: EnvelopeBudgetStatus, messageKey: String)? {
        guard !additionalIsEssential, additionalAmount > 0 else { return nil }

        let current = computeStandardBudget(
            records: records,
            fundingSource: fundingSource,
            period: period,
            spendingCap: spendingCap,
            categoryRecords: categoryRecords,
            supplementalEarned: supplementalEarned,
            locale: locale
        )
        let limit = current.effectiveLimit
        let projectedSpent = current.discretionarySpent + additionalAmount

        if limit <= 0 {
            guard projectedSpent > 0 else { return nil }
            return (.over, "This expense exceeds your discretionary budget — log income to set a limit.")
        }

        let threshold = Double(max(1, min(100, approachingThresholdPercent))) / 100.0
        let currentRatio = NSDecimalNumber(decimal: current.discretionarySpent / limit).doubleValue
        let projectedRatio = NSDecimalNumber(decimal: projectedSpent / limit).doubleValue

        let currentStatus: EnvelopeBudgetStatus
        if current.discretionarySpent > limit {
            currentStatus = .over
        } else if current.discretionarySpent >= limit {
            currentStatus = .atLimit
        } else if currentRatio >= threshold {
            currentStatus = .approaching
        } else {
            currentStatus = .ok
        }

        if projectedSpent > limit {
            return (.over, "This expense puts you over your discretionary budget for this period.")
        }
        if projectedSpent >= limit {
            return (.atLimit, "This expense uses the rest of your discretionary budget for this period.")
        }
        if projectedRatio >= threshold, currentStatus == .ok {
            return (.approaching, "This expense brings you close to your discretionary budget limit.")
        }
        return nil
    }
}
