//
//  SalaryPayrollMatcher.swift
//  BuxMuse
//
//  Recognises repeat paycheck deposits from a user-linked anchor transaction.
//

import Foundation

enum SalaryPayrollMatcher {
    static let salaryRole = "salary"
    private static let paydayWindowDays = 3

    static func isSalaryTagged(_ record: ExpenseRecord) -> Bool {
        record.incomeRole == salaryRole
    }

    static func normalizeMatchKey(from label: String) -> String {
        MerchantLogoEngine.normalizeMerchantName(label)
    }

    static func suggestedPayCycle(for payday: Date, calendar: Calendar = .current) -> (SimpleBudgetCycle, Date) {
        let day = calendar.component(.day, from: payday)
        let anchor = calendar.startOfDay(for: payday)
        switch day {
        case 1: return (.monthFirst, anchor)
        case 15: return (.monthFifteenth, anchor)
        case 30, 31: return (.monthThirtieth, anchor)
        default: return (.custom, anchor)
        }
    }

    static func buildProfile(
        from record: ExpenseRecord,
        payCycle: SimpleBudgetCycle,
        payAnchorDate: Date
    ) -> SalaryPayProfile {
        SalaryPayProfile(
            isConfigured: true,
            payCycle: payCycle,
            payAnchorDate: calendar.startOfDay(for: payAnchorDate),
            anchorExpenseId: record.id,
            anchorFinanceKitId: record.financeKitTransactionId,
            matchMerchantKey: normalizeMatchKey(from: record.merchantName.isEmpty ? record.name : record.merchantName),
            expectedAmount: abs(record.amountValue),
            amountTolerancePercent: 0.05
        )
    }

    static func applySalaryTag(to record: inout ExpenseRecord) {
        record.incomeRole = salaryRole
        record.categoryRaw = TransactionCategory.income.rawValue
    }

    @discardableResult
    static func applyAutoTagIfMatched(
        _ record: inout ExpenseRecord,
        profile: SalaryPayProfile,
        weekStartDay: WeekStartDay,
        calendar: Calendar? = nil
    ) -> Bool {
        guard profile.isConfigured else { return false }
        guard record.amountValue > 0 else { return false }
        guard !isSalaryTagged(record) else { return false }
        if let anchorId = profile.anchorExpenseId, record.id == anchorId { return false }
        if let financeKitId = profile.anchorFinanceKitId,
           let recordFinanceKitId = record.financeKitTransactionId,
           financeKitId == recordFinanceKitId {
            return false
        }
        guard matches(record: record, profile: profile, weekStartDay: weekStartDay, calendar: calendar) else {
            return false
        }
        applySalaryTag(to: &record)
        return true
    }

    static func matches(
        record: ExpenseRecord,
        profile: SalaryPayProfile,
        weekStartDay: WeekStartDay,
        calendar: Calendar? = nil
    ) -> Bool {
        guard profile.isConfigured, record.amountValue > 0 else { return false }

        let cal = calendar ?? BuxBudgetPeriodCalculator.calendar(weekStartDay: weekStartDay)
        guard amountsMatch(abs(record.amountValue), profile.expectedAmount, tolerancePercent: profile.amountTolerancePercent) else {
            return false
        }
        guard merchantMatches(record: record, profileKey: profile.matchMerchantKey) else {
            return false
        }
        return isNearPayday(
            recordDate: record.date,
            profile: profile,
            weekStartDay: weekStartDay,
            calendar: cal
        )
    }

    private static var calendar: Calendar { Calendar.current }

    private static func amountsMatch(_ amount: Decimal, _ expected: Decimal, tolerancePercent: Double) -> Bool {
        guard expected > 0 else { return amount == expected }
        let amountDouble = abs(NSDecimalNumber(decimal: amount).doubleValue)
        let expectedDouble = abs(NSDecimalNumber(decimal: expected).doubleValue)
        let tolerance = max(0.01, tolerancePercent)
        return abs(amountDouble - expectedDouble) <= expectedDouble * tolerance
    }

    private static func merchantMatches(record: ExpenseRecord, profileKey: String) -> Bool {
        let key = normalizeMatchKey(from: profileKey)
        guard !key.isEmpty else { return true }
        let candidates = [record.name, record.merchantName].map { normalizeMatchKey(from: $0) }
        return candidates.contains { candidate in
            guard !candidate.isEmpty else { return false }
            return candidate == key || candidate.contains(key) || key.contains(candidate)
        }
    }

    private static func isNearPayday(
        recordDate: Date,
        profile: SalaryPayProfile,
        weekStartDay: WeekStartDay,
        calendar: Calendar
    ) -> Bool {
        let configuration = BuxBudgetPeriodCalculator.Configuration(
            cycle: profile.payCycle,
            weekStartDay: weekStartDay,
            anchorDate: profile.payAnchorDate
        )
        let recordDay = calendar.startOfDay(for: recordDate)
        let periodStart = calendar.startOfDay(
            for: BuxBudgetPeriodCalculator.periodStart(configuration: configuration, now: recordDate, calendar: calendar)
        )
        if dayDistance(from: periodStart, to: recordDay, calendar: calendar) <= paydayWindowDays {
            return true
        }

        let period = BuxBudgetPeriodCalculator.currentPeriod(
            configuration: configuration,
            now: recordDate,
            calendar: calendar
        )
        if let previousAnchor = previousPeriodStart(from: period.start, cycle: profile.payCycle, calendar: calendar) {
            let previousDay = calendar.startOfDay(for: previousAnchor)
            if dayDistance(from: previousDay, to: recordDay, calendar: calendar) <= paydayWindowDays {
                return true
            }
        }
        return false
    }

    private static func dayDistance(from start: Date, to end: Date, calendar: Calendar) -> Int {
        abs(calendar.dateComponents([.day], from: start, to: end).day ?? 99)
    }

    private static func previousPeriodStart(from currentStart: Date, cycle: SimpleBudgetCycle, calendar: Calendar) -> Date? {
        switch cycle {
        case .monthFirst, .monthFifteenth, .monthThirtieth, .custom:
            return calendar.date(byAdding: .month, value: -1, to: currentStart)
        case .weekly:
            return calendar.date(byAdding: .day, value: -7, to: currentStart)
        case .biweekly:
            return calendar.date(byAdding: .day, value: -14, to: currentStart)
        case .daily:
            return calendar.date(byAdding: .day, value: -1, to: currentStart)
        }
    }
}
