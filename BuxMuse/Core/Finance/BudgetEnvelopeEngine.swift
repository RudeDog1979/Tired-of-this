//
//  BudgetEnvelopeEngine.swift
//  BuxMuse
//
//  Cash-stuffing envelope math: category-linked spend, pay-cycle windows, rollover.
//

import Foundation

public enum EnvelopeBudgetStatus: String, Equatable, Sendable {
    case ok
    case approaching
    case atLimit
    case over
}

public struct EnvelopeBudgetDisplay: Identifiable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var allocated: Decimal
    public var carryover: Decimal
    public var effectiveLimit: Decimal
    public var spent: Decimal
    public var remaining: Decimal
    public var percentUsed: Double
    public var status: EnvelopeBudgetStatus
    public var categoryId: UUID?
    public var systemCategoryRaw: String?

    public init(
        id: UUID,
        name: String,
        allocated: Decimal,
        carryover: Decimal = 0,
        effectiveLimit: Decimal,
        spent: Decimal,
        remaining: Decimal,
        percentUsed: Double,
        status: EnvelopeBudgetStatus,
        categoryId: UUID? = nil,
        systemCategoryRaw: String? = nil
    ) {
        self.id = id
        self.name = name
        self.allocated = allocated
        self.carryover = carryover
        self.effectiveLimit = effectiveLimit
        self.spent = spent
        self.remaining = remaining
        self.percentUsed = percentUsed
        self.status = status
        self.categoryId = categoryId
        self.systemCategoryRaw = systemCategoryRaw
    }
}

enum BudgetEnvelopeEngine {
    private static let rolloverStateKey = "buxmuse.budget.envelopeRolloverState"

    struct RolloverState: Codable, Equatable {
        var profileId: UUID
        var periodStart: Date
        var balances: [UUID: String]
    }

    // MARK: - Income

    static func isSalaryIncome(record: ExpenseRecord, locale: Locale = BuxInterfaceLocale.currentInterfaceLocale) -> Bool {
        guard record.amountValue > 0 else { return false }
        if SalaryPayrollMatcher.isSalaryTagged(record) { return true }
        if let pick = IncomeSourceQuickPick.matchingStoredLabel(record.name, locale: locale) {
            return pick == .salary || pick == .paycheck
        }
        return record.transactionCategory == .income
            && (record.name.localizedCaseInsensitiveContains("salary")
                || record.name.localizedCaseInsensitiveContains("paycheck"))
    }

    static func isOtherIncome(record: ExpenseRecord, locale: Locale = BuxInterfaceLocale.currentInterfaceLocale) -> Bool {
        guard record.amountValue > 0 else { return false }
        if isSalaryIncome(record: record, locale: locale) { return false }
        return record.transactionCategory == .income
            || IncomeSourceQuickPick.matchingStoredLabel(record.name, locale: locale) != nil
    }

    static func incomePool(
        records: [ExpenseRecord],
        fundingSource: IncomeFundingSource,
        period: DateInterval,
        locale: Locale = BuxInterfaceLocale.currentInterfaceLocale
    ) -> Decimal {
        let inPeriod = records.filter { $0.date >= period.start && $0.date < period.end }
        return inPeriod
            .filter { record in
                fundingSource == .salary
                    ? isSalaryIncome(record: record, locale: locale)
                    : isOtherIncome(record: record, locale: locale)
            }
            .reduce(Decimal(0)) { $0 + abs($1.amountValue) }
    }

    // MARK: - Category matching

    static func recordMatchesEnvelope(
        _ record: ExpenseRecord,
        envelope: CustomBudgetCategory,
        categoryRecords: [ExpenseCategoryRecord],
        locale: Locale = BuxInterfaceLocale.currentInterfaceLocale
    ) -> Bool {
        ExpenseBudgetAttribution.lines(for: record).contains {
            attributionLineMatchesEnvelope(
                $0,
                envelope: envelope,
                categoryRecords: categoryRecords,
                locale: locale
            )
        }
    }

    static func attributionLineMatchesEnvelope(
        _ line: ExpenseBudgetAttributionLine,
        envelope: CustomBudgetCategory,
        categoryRecords: [ExpenseCategoryRecord],
        locale: Locale = BuxInterfaceLocale.currentInterfaceLocale
    ) -> Bool {
        if let envelopeCategoryId = envelope.categoryId, line.categoryId == envelopeCategoryId {
            return true
        }

        if let systemRaw = envelope.systemCategoryRaw,
           line.transactionCategory.rawValue == systemRaw {
            return true
        }

        if let recordCategoryId = line.categoryId,
           let custom = categoryRecords.first(where: { $0.id == recordCategoryId }) {
            if let envelopeCategoryId = envelope.categoryId, custom.id == envelopeCategoryId {
                return true
            }
            if let systemRaw = envelope.systemCategoryRaw,
               let customSystem = custom.systemCategoryRaw,
               customSystem == systemRaw {
                return true
            }
            if custom.localizedDisplayName(locale: locale).localizedCaseInsensitiveCompare(envelope.name) == .orderedSame {
                return true
            }
        }

        if line.transactionCategory.displayName.localizedCaseInsensitiveCompare(envelope.name) == .orderedSame {
            return true
        }
        if let raw = envelope.systemCategoryRaw,
           let system = TransactionCategory(rawValue: raw),
           envelope.name.localizedCaseInsensitiveCompare(system.localizedDisplayName(locale: locale)) == .orderedSame {
            return true
        }

        return false
    }

    static func spent(
        for envelope: CustomBudgetCategory,
        records: [ExpenseRecord],
        categoryRecords: [ExpenseCategoryRecord],
        period: DateInterval,
        locale: Locale = BuxInterfaceLocale.currentInterfaceLocale
    ) -> Decimal {
        ExpenseBudgetAttribution.lines(for: records)
            .filter { $0.date >= period.start && $0.date < period.end }
            .filter {
                attributionLineMatchesEnvelope(
                    $0,
                    envelope: envelope,
                    categoryRecords: categoryRecords,
                    locale: locale
                )
            }
            .reduce(Decimal(0)) { $0 + $1.amount }
    }

    // MARK: - Rollover

    static func loadRollover(profileId: UUID) -> [UUID: Decimal] {
        let states = loadAllRolloverStates()
        guard let state = states.first(where: { $0.profileId == profileId }) else {
            return [:]
        }
        return state.balances.reduce(into: [:]) { result, pair in
            if let value = Decimal(string: pair.value) {
                result[pair.key] = value
            }
        }
    }

    static func syncRollover(
        profile: CustomBudgetProfile,
        period: DateInterval,
        records: [ExpenseRecord],
        categoryRecords: [ExpenseCategoryRecord],
        locale: Locale = BuxInterfaceLocale.currentInterfaceLocale
    ) -> [UUID: Decimal] {
        var states = loadAllRolloverStates()
        let periodStart = period.start
        var carryover = loadRollover(profileId: profile.id)

        if let index = states.firstIndex(where: { $0.profileId == profile.id }) {
            let stored = states[index]
            if stored.periodStart != periodStart {
                if profile.rolloverEnabled {
                    var nextBalances: [UUID: String] = [:]
                    for envelope in profile.categories {
                        let priorSpent = spent(
                            for: envelope,
                            records: records,
                            categoryRecords: categoryRecords,
                            period: DateInterval(start: stored.periodStart, end: periodStart),
                            locale: locale
                        )
                        let priorCarry = carryover[envelope.id] ?? 0
                        let priorLimit = envelope.targetAmount + priorCarry
                        let remaining = max(0, priorLimit - priorSpent)
                        if remaining > 0 {
                            nextBalances[envelope.id] = NSDecimalNumber(decimal: remaining).stringValue
                        }
                    }
                    carryover = nextBalances.reduce(into: [:]) { $0[$1.key] = Decimal(string: $1.value) ?? 0 }
                } else {
                    carryover = [:]
                }
                states[index] = RolloverState(profileId: profile.id, periodStart: periodStart, balances: encodeBalances(carryover))
            } else {
                carryover = decodeBalances(stored.balances)
            }
        } else {
            states.append(RolloverState(profileId: profile.id, periodStart: periodStart, balances: [:]))
        }

        saveAllRolloverStates(states)
        return carryover
    }

    // MARK: - Envelope display

    static func computeEnvelopes(
        profile: CustomBudgetProfile,
        records: [ExpenseRecord],
        categoryRecords: [ExpenseCategoryRecord],
        period: DateInterval,
        locale: Locale = BuxInterfaceLocale.currentInterfaceLocale
    ) -> [EnvelopeBudgetDisplay] {
        let carryover = syncRollover(
            profile: profile,
            period: period,
            records: records,
            categoryRecords: categoryRecords,
            locale: locale
        )
        let threshold = Double(max(1, min(100, profile.approachingThresholdPercent))) / 100.0

        return profile.categories.map { envelope in
            let spentAmount = spent(
                for: envelope,
                records: records,
                categoryRecords: categoryRecords,
                period: period,
                locale: locale
            )
            let roll = profile.rolloverEnabled ? (carryover[envelope.id] ?? 0) : 0
            let limit = envelope.targetAmount + roll
            let remaining = limit - spentAmount
            let ratio = limit > 0
                ? min(1.5, max(0, NSDecimalNumber(decimal: spentAmount / limit).doubleValue))
                : 0
            let status: EnvelopeBudgetStatus
            if spentAmount > limit, limit > 0 {
                status = .over
            } else if spentAmount >= limit, limit > 0 {
                status = .atLimit
            } else if ratio >= threshold, limit > 0 {
                status = .approaching
            } else {
                status = .ok
            }

            return EnvelopeBudgetDisplay(
                id: envelope.id,
                name: envelope.localizedDisplayName(categoryRecords: categoryRecords, locale: locale),
                allocated: envelope.targetAmount,
                carryover: roll,
                effectiveLimit: limit,
                spent: spentAmount,
                remaining: remaining,
                percentUsed: ratio,
                status: status,
                categoryId: envelope.categoryId,
                systemCategoryRaw: envelope.systemCategoryRaw
            )
        }
    }

    static func projectedEnvelopeStatus(
        envelope: CustomBudgetCategory,
        profile: CustomBudgetProfile,
        records: [ExpenseRecord],
        categoryRecords: [ExpenseCategoryRecord],
        period: DateInterval,
        additionalAmount: Decimal,
        locale: Locale = BuxInterfaceLocale.currentInterfaceLocale
    ) -> (status: EnvelopeBudgetStatus, messageKey: String)? {
        guard SettingsStore.shared.budgetingMode == .envelope,
              SettingsStore.shared.showBudgetWarnings,
              let active = SettingsStore.shared.customBudgetProfiles.first(where: { $0.isActive }),
              active.id == profile.id else {
            return nil
        }

        let displays = computeEnvelopes(
            profile: profile,
            records: records,
            categoryRecords: categoryRecords,
            period: period,
            locale: locale
        )
        guard let current = displays.first(where: { $0.id == envelope.id }) else { return nil }

        let projectedSpent = current.spent + additionalAmount
        let limit = current.effectiveLimit
        guard limit > 0 else { return nil }

        let threshold = Double(max(1, min(100, profile.approachingThresholdPercent))) / 100.0
        let projectedRatio = NSDecimalNumber(decimal: projectedSpent / limit).doubleValue

        if projectedSpent > limit {
            return (.over, "This expense puts you over your %@ envelope.")
        }
        if projectedSpent >= limit {
            return (.atLimit, "This expense fills your %@ envelope for this period.")
        }
        if projectedRatio >= threshold, current.status == .ok {
            return (.approaching, "This expense brings %@ close to your envelope limit.")
        }
        return nil
    }

    // MARK: - Persistence helpers

    private static func loadAllRolloverStates() -> [RolloverState] {
        guard let data = UserDefaults.standard.data(forKey: rolloverStateKey),
              let states = try? JSONDecoder().decode([RolloverState].self, from: data) else {
            return []
        }
        return states
    }

    private static func saveAllRolloverStates(_ states: [RolloverState]) {
        guard let data = try? JSONEncoder().encode(states) else { return }
        UserDefaults.standard.set(data, forKey: rolloverStateKey)
    }

    private static func encodeBalances(_ balances: [UUID: Decimal]) -> [UUID: String] {
        balances.reduce(into: [:]) { $0[$1.key] = NSDecimalNumber(decimal: $1.value).stringValue }
    }

    private static func decodeBalances(_ balances: [UUID: String]) -> [UUID: Decimal] {
        balances.reduce(into: [:]) { result, pair in
            if let value = Decimal(string: pair.value) {
                result[pair.key] = value
            }
        }
    }
}
