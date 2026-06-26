//
//  BuxDisplayDate.swift
//  BuxMuse
//
//  Locale-aware dates for UI headings and rows (Settings → App language).
//  Month + year uses "Junio 2026" / "June 2026" — never "Junio de 2026".
//

import Foundation

enum BuxDisplayDate {
    /// Month/year period titles (hero heading, month pager).
    static func monthYear(from date: Date, locale: Locale, calendar: Calendar = .current) -> String {
        let month = formatted(date, template: "MMMM", locale: locale, calendar: calendar, heading: true)
        let year = formatted(date, template: "yyyy", locale: locale, calendar: calendar, heading: false)
        return "\(month) \(year)"
    }

    /// Week range for period pager (e.g. Jun 16 – Jun 22 / 16 Jun – 22 Jun).
    static func monthDayRange(from start: Date, to end: Date, locale: Locale, calendar: Calendar = .current) -> String {
        let left = shortMonthDay(from: start, locale: locale, calendar: calendar)
        let right = shortMonthDay(from: end, locale: locale, calendar: calendar)
        return "\(left) – \(right)"
    }

    static func year(from date: Date, locale: Locale, calendar: Calendar = .current) -> String {
        formatted(date, template: "yyyy", locale: locale, calendar: calendar, heading: false)
    }

    /// Short month for chart axis labels.
    static func shortMonth(from date: Date, locale: Locale, calendar: Calendar = .current) -> String {
        formatted(date, template: "MMM", locale: locale, calendar: calendar, heading: true)
    }

    /// Short weekday for chart axis labels.
    static func shortWeekday(from date: Date, locale: Locale, calendar: Calendar = .current) -> String {
        formatted(date, template: "EEE", locale: locale, calendar: calendar, heading: true)
    }

    /// Transaction list row date.
    static func transactionDay(from date: Date, locale: Locale, calendar: Calendar = .current) -> String {
        shortMonthDay(from: date, locale: locale, calendar: calendar)
    }

    /// Expense detail overview timestamp.
    static func dateAndTime(from date: Date, locale: Locale, calendar: Calendar = .current) -> String {
        let datePart = shortMonthDay(from: date, locale: locale, calendar: calendar)
        let timeFormatter = makeFormatter(locale: locale, calendar: calendar)
        timeFormatter.dateStyle = .none
        timeFormatter.timeStyle = .short
        let time = timeFormatter.string(from: date)
        return "\(datePart), \(time)"
    }

    /// Month + day without year (renewal rows, etc.).
    static func monthDay(from date: Date, locale: Locale, calendar: Calendar = .current) -> String {
        shortMonthDay(from: date, locale: locale, calendar: calendar)
    }

    /// Month + day + year without locale "de" glue.
    static func monthDayYear(from date: Date, locale: Locale, calendar: Calendar = .current) -> String {
        let monthDayPart = shortMonthDay(from: date, locale: locale, calendar: calendar)
        let year = formatted(date, template: "yyyy", locale: locale, calendar: calendar, heading: false)
        return "\(monthDayPart), \(year)"
    }

    private static func shortMonthDay(from date: Date, locale: Locale, calendar: Calendar) -> String {
        let day = formatted(date, template: "d", locale: locale, calendar: calendar, heading: false)
        let month = formatted(date, template: "MMM", locale: locale, calendar: calendar, heading: true)
        if isSpanish(locale) {
            return "\(day) \(month)"
        }
        return "\(month) \(day)"
    }

    private static func formatted(
        _ date: Date,
        template: String,
        locale: Locale,
        calendar: Calendar,
        heading: Bool
    ) -> String {
        let formatter = makeFormatter(locale: locale, calendar: calendar)
        formatter.setLocalizedDateFormatFromTemplate(template)
        let value = formatter.string(from: date)
        return heading ? periodHeading(value, locale: locale) : value
    }

    private static func makeFormatter(locale: Locale, calendar: Calendar) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        return formatter
    }

    /// Spanish month/day headings need a leading cap; English formatter output is already correct.
    private static func periodHeading(_ formatted: String, locale: Locale) -> String {
        guard isSpanish(locale), let first = formatted.first else { return formatted }
        return String(first).uppercased(with: locale) + formatted.dropFirst()
    }

    private static func isSpanish(_ locale: Locale) -> Bool {
        locale.language.languageCode?.identifier == "es"
    }
}
