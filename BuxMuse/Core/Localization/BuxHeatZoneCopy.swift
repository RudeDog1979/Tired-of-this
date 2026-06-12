//
//  BuxHeatZoneCopy.swift
//  BuxMuse
//
//  Localized labels for expense heat-zone filter buckets (Settings → Country).
//

import Foundation

enum BuxHeatZoneCopy {
    static func displayName(for bucket: String, locale: Locale) -> String {
        switch bucket {
        case "late_night":
            return BuxLocalizedString.string("Late night", locale: locale)
        case "weekend":
            return BuxLocalizedString.string("Weekend", locale: locale)
        case "payday":
            return BuxLocalizedString.string("Payday", locale: locale)
        default:
            break
        }

        let parts = bucket.split(separator: "_", omittingEmptySubsequences: true)
        guard parts.count == 2 else {
            return bucket.replacingOccurrences(of: "_", with: " ")
        }

        let dayToken = String(parts[0])
        let timeToken = String(parts[1])
        let weekday = localizedWeekday(token: dayToken, locale: locale)
        let timeLabel = localizedDaypart(token: timeToken, locale: locale)
        return BuxLocalizedString.format("%@ %@", locale: locale, weekday, timeLabel)
    }

    private static func localizedWeekday(token: String, locale: Locale) -> String {
        let map: [String: Int] = [
            "sunday": 1, "monday": 2, "tuesday": 3, "wednesday": 4,
            "thursday": 5, "friday": 6, "saturday": 7,
        ]
        guard let weekday = map[token.lowercased()] else {
            return token.capitalized
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        let symbols = calendar.weekdaySymbols
        guard weekday >= 1, weekday <= symbols.count else { return token.capitalized }
        return symbols[weekday - 1]
    }

    private static func localizedDaypart(token: String, locale: Locale) -> String {
        switch token.lowercased() {
        case "morning":
            return BuxLocalizedString.string("Morning", locale: locale)
        case "afternoon":
            return BuxLocalizedString.string("Afternoon", locale: locale)
        case "evening":
            return BuxLocalizedString.string("Evening", locale: locale)
        default:
            return token.capitalized
        }
    }
}
