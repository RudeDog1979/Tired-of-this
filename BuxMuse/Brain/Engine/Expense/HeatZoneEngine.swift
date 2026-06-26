//
//  HeatZoneEngine.swift
//  BuxMuse
//
//  Standalone engine for heat zone bucket calculations.
//

import Foundation

struct HeatZoneEngine {
    static func analyze(
        record: ExpenseRecord,
        allRecords: [ExpenseRecord],
        locale: Locale = BuxInterfaceLocale.currentInterfaceLocale
    ) -> (bucket: String, summary: String?) {
        let cal = Calendar.current
        let hour = cal.component(.hour, from: record.date)

        var bucket = ""
        var summary: String?

        if hour >= 22 || hour < 5 {
            bucket = "late_night"
            summary = BuxLocalizedString.string(
                "This expense falls into your high-spend late-night zone.",
                locale: locale
            )
        } else {
            let weekday = cal.component(.weekday, from: record.date)
            if weekday == 1 || weekday == 7 {
                bucket = "weekend"
                summary = BuxLocalizedString.string(
                    "Your spending spikes on weekends — this fits that window.",
                    locale: locale
                )
            } else {
                let day = cal.component(.day, from: record.date)
                if day <= 3 || day >= 28 {
                    bucket = "payday"
                    summary = BuxLocalizedString.string(
                        "Payday window spend — watch impulse purchases here.",
                        locale: locale
                    )
                } else {
                    let bucketHour = hour < 12 ? "morning" : (hour < 17 ? "afternoon" : "evening")
                    let dayName = cal.weekdaySymbols[weekday - 1].lowercased()
                    bucket = "\(dayName)_\(bucketHour)"
                }
            }
        }
        return (bucket, summary)
    }
}
