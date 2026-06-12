//
//  TaxEnvelopePaymentSchedule.swift
//  BuxMuse
//
//  Catalog-backed payment due dates — monthly JSON updates drive worldwide coach.
//

import Foundation

public enum TaxEnvelopePaymentSchedule {

    public static func nextPaymentDate(
        countryCode: String,
        regionCode: String?,
        schedule: String,
        reference: Date = Date(),
        calendar: Calendar = .current
    ) -> Date? {
        let normalized = TaxManager.normalizeCountryCode(countryCode)
        if let entry = TaxComputeCatalogStore.shared.entry(for: normalized) {
            let block = entry.mergedBlock(forRegion: regionCode)
            if let calendarSpec = block.paymentCalendar {
                if let date = nextDate(from: calendarSpec, reference: reference, calendar: calendar) {
                    return date
                }
            }
            let resolvedSchedule = block.paymentSchedule ?? schedule
            return scheduleHeuristic(
                schedule: resolvedSchedule,
                entry: entry,
                reference: reference,
                calendar: calendar
            )
        }
        return scheduleHeuristic(
            schedule: schedule,
            entry: nil,
            reference: reference,
            calendar: calendar
        )
    }

    public static func periodKey(
        countryCode: String,
        reference: Date = Date(),
        calendar: Calendar = .current
    ) -> String {
        let label = WorldTaxEngine.quarterLabel(
            countryCode: countryCode,
            reference: reference,
            calendar: calendar
        )
        return label.replacingOccurrences(of: " ", with: "-")
    }

    public static func paymentScheduleLabel(
        countryCode: String,
        regionCode: String?,
        profileSchedule: String
    ) -> String {
        guard let entry = TaxComputeCatalogStore.shared.entry(for: countryCode) else {
            return profileSchedule.capitalized
        }
        let block = entry.mergedBlock(forRegion: regionCode)
        return (block.paymentSchedule ?? profileSchedule).capitalized
    }

    public static let userSelectableSchedules = ["quarterly", "annually", "monthly"]

    public static func localizedScheduleName(_ schedule: String, locale: Locale) -> String {
        switch schedule.lowercased() {
        case "monthly": return BuxCatalogLabel.string("Monthly", locale: locale)
        case "annually", "annual", "yearly": return BuxCatalogLabel.string("Yearly", locale: locale)
        default: return BuxCatalogLabel.string("Quarterly", locale: locale)
        }
    }

    public static func dueAmountTitle(schedule: String, locale: Locale) -> String {
        switch schedule.lowercased() {
        case "monthly":
            return BuxCatalogLabel.string("Estimated tax this month", locale: locale)
        case "annually", "annual", "yearly":
            return BuxCatalogLabel.string("Estimated tax this year", locale: locale)
        default:
            return BuxCatalogLabel.string("Estimated tax this quarter", locale: locale)
        }
    }

    public static func periodTitle(schedule: String, locale: Locale) -> String {
        switch schedule.lowercased() {
        case "monthly":
            return BuxCatalogLabel.string("Month", locale: locale)
        case "annually", "annual", "yearly":
            return BuxCatalogLabel.string("Tax year", locale: locale)
        default:
            return BuxCatalogLabel.string("Quarter", locale: locale)
        }
    }

    public static func yearSummaryDueRowTitle(schedule: String, locale: Locale) -> String {
        switch schedule.lowercased() {
        case "monthly":
            return BuxCatalogLabel.string("Current month due", locale: locale)
        case "annually", "annual", "yearly":
            return BuxCatalogLabel.string("Current year due", locale: locale)
        default:
            return BuxCatalogLabel.string("Current quarter due", locale: locale)
        }
    }

    // MARK: - Catalog calendar

    private static func nextDate(
        from spec: TaxComputePaymentCalendar,
        reference: Date,
        calendar: Calendar
    ) -> Date? {
        let startOfToday = calendar.startOfDay(for: reference)
        let baseYear = calendar.component(.year, from: reference)
        var candidates: [Date] = []
        for yearOffset in 0...1 {
            let year = baseYear + yearOffset
            for dueMonth in spec.dueMonths {
                var comps = DateComponents()
                comps.year = year
                comps.month = dueMonth
                comps.day = spec.dueDay
                if let date = calendar.date(from: comps), date >= startOfToday {
                    candidates.append(date)
                }
            }
        }
        return candidates.sorted().first
    }

    private static func scheduleHeuristic(
        schedule: String,
        entry: TaxCountryComputeEntry?,
        reference: Date,
        calendar: Calendar
    ) -> Date? {
        switch schedule.lowercased() {
        case "monthly":
            var comps = calendar.dateComponents([.year, .month], from: reference)
            comps.month = (comps.month ?? 1) + 1
            comps.day = entry?.meta.fiscalYearStartDay ?? 15
            return calendar.date(from: comps)
        case "quarterly":
            if let entry {
                let startMonth = entry.meta.fiscalYearStartMonth
                let startDay = entry.meta.fiscalYearStartDay
                let (_, end, _) = WorldTaxEngine.fiscalQuarterBounds(
                    reference: reference,
                    fiscalStartMonth: startMonth,
                    fiscalStartDay: startDay,
                    calendar: calendar
                )
                var comps = calendar.dateComponents([.year, .month, .day], from: end)
                comps.month = (comps.month ?? 1) + 1
                comps.day = 15
                if let due = calendar.date(from: comps), due > reference {
                    return due
                }
                comps.month = (comps.month ?? 1) + 3
                return calendar.date(from: comps)
            }
            let month = calendar.component(.month, from: reference)
            let qEndMonth = ((month - 1) / 3 + 1) * 3
            var comps = calendar.dateComponents([.year], from: reference)
            comps.month = qEndMonth + 1
            comps.day = 15
            return calendar.date(from: comps)
        default:
            if let entry {
                var comps = DateComponents()
                comps.year = calendar.component(.year, from: reference)
                comps.month = entry.meta.fiscalYearStartMonth
                comps.day = entry.meta.fiscalYearStartDay
                if let start = calendar.date(from: comps) {
                    var annual = calendar.date(byAdding: .year, value: 1, to: start) ?? start
                    annual = calendar.date(byAdding: .day, value: 90, to: annual) ?? annual
                    if annual > reference { return annual }
                }
            }
            var comps = calendar.dateComponents([.year], from: reference)
            comps.month = 4
            comps.day = 15
            if let d = calendar.date(from: comps), d > reference { return d }
            comps.year = (comps.year ?? 2026) + 1
            return calendar.date(from: comps)
        }
    }
}
