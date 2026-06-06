//
//  BuxBudgetPeriod.swift
//  BuxMuse
//
//  Rolling budget windows for Simple mode (pay-cycle aware, not always calendar month).
//

import Foundation

public enum BuxBudgetPeriodCalculator {
    public struct Configuration: Equatable {
        public var cycle: SimpleBudgetCycle
        public var weekStartDay: WeekStartDay
        public var anchorDate: Date

        public init(
            cycle: SimpleBudgetCycle = .monthFirst,
            weekStartDay: WeekStartDay = .monday,
            anchorDate: Date = Date()
        ) {
            self.cycle = cycle
            self.weekStartDay = weekStartDay
            self.anchorDate = anchorDate
        }

        @MainActor public static var fromSettings: Configuration {
            let store = SettingsStore.shared
            return Configuration(
                cycle: store.simpleBudgetCycle,
                weekStartDay: store.weekStartDay,
                anchorDate: store.simpleBudgetPeriodAnchor
            )
        }
    }

    public static func calendar(weekStartDay: WeekStartDay) -> Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = weekStartDay.calendarWeekday
        return calendar
    }

    /// Inclusive start, exclusive end — matches expense `date >= start` filtering elsewhere.
    public static func currentPeriod(
        configuration: Configuration,
        now: Date = Date(),
        calendar: Calendar? = nil
    ) -> DateInterval {
        let cal = calendar ?? Self.calendar(weekStartDay: configuration.weekStartDay)
        let start = periodStart(configuration: configuration, now: now, calendar: cal)
        let end = periodEnd(configuration: configuration, periodStart: start, calendar: cal)
        return DateInterval(start: start, end: end)
    }

    public static func periodStart(
        configuration: Configuration,
        now: Date = Date(),
        calendar: Calendar
    ) -> Date {
        let today = calendar.startOfDay(for: now)
        switch configuration.cycle {
        case .monthFirst:
            return monthAlignedStart(day: 1, now: today, calendar: calendar)
        case .monthFifteenth:
            return monthAlignedStart(day: 15, now: today, calendar: calendar)
        case .monthThirtieth:
            return monthAlignedStart(day: 30, now: today, calendar: calendar)
        case .weekly:
            return weekAlignedStart(now: today, calendar: calendar)
        case .biweekly:
            return biweeklyAlignedStart(anchor: configuration.anchorDate, now: today, calendar: calendar)
        case .daily:
            return today
        case .custom:
            return customAlignedStart(anchor: configuration.anchorDate, now: today, calendar: calendar)
        }
    }

    private static func periodEnd(
        configuration: Configuration,
        periodStart: Date,
        calendar: Calendar
    ) -> Date {
        switch configuration.cycle {
        case .monthFirst, .monthFifteenth, .monthThirtieth, .custom:
            return calendar.date(byAdding: .month, value: 1, to: periodStart) ?? periodStart.addingTimeInterval(86_400 * 30)
        case .weekly:
            return calendar.date(byAdding: .day, value: 7, to: periodStart) ?? periodStart.addingTimeInterval(86_400 * 7)
        case .biweekly:
            return calendar.date(byAdding: .day, value: 14, to: periodStart) ?? periodStart.addingTimeInterval(86_400 * 14)
        case .daily:
            return calendar.date(byAdding: .day, value: 1, to: periodStart) ?? periodStart.addingTimeInterval(86_400)
        }
    }

    private static func monthAlignedStart(day: Int, now: Date, calendar: Calendar) -> Date {
        let clampedDay = { (date: Date) -> Int in
            let maxDay = calendar.range(of: .day, in: .month, for: date)?.count ?? day
            return min(day, maxDay)
        }

        var components = calendar.dateComponents([.year, .month], from: now)
        components.day = clampedDay(now)
        guard var candidate = calendar.date(from: components) else { return now }
        candidate = calendar.startOfDay(for: candidate)
        if candidate > now,
           let previousMonth = calendar.date(byAdding: .month, value: -1, to: candidate) {
            var prev = calendar.dateComponents([.year, .month], from: previousMonth)
            prev.day = clampedDay(previousMonth)
            if let shifted = calendar.date(from: prev) {
                candidate = calendar.startOfDay(for: shifted)
            }
        }
        return candidate
    }

    private static func weekAlignedStart(now: Date, calendar: Calendar) -> Date {
        let weekday = calendar.component(.weekday, from: now)
        let delta = (weekday - calendar.firstWeekday + 7) % 7
        return calendar.date(byAdding: .day, value: -delta, to: now) ?? now
    }

    private static func biweeklyAlignedStart(anchor: Date, now: Date, calendar: Calendar) -> Date {
        let anchorDay = calendar.startOfDay(for: anchor)
        let days = calendar.dateComponents([.day], from: anchorDay, to: now).day ?? 0
        let periods = max(0, days / 14)
        return calendar.date(byAdding: .day, value: periods * 14, to: anchorDay) ?? anchorDay
    }

    /// Repeats monthly from the anchor's day-of-month (pay-day style).
    private static func customAlignedStart(anchor: Date, now: Date, calendar: Calendar) -> Date {
        let anchorDay = calendar.component(.day, from: anchor)
        return monthAlignedStart(day: anchorDay, now: now, calendar: calendar)
    }
}
