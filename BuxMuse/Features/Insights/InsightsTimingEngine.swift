//
//  InsightsTimingEngine.swift
//  BuxMuse
//  Features/Insights/
//
//  Insights Timing Engine managing user view intervals and repetition suppression.
//

import Foundation

public final class InsightsTimingEngine {
    public init() {}
    
    public func filterByTiming(insights: [FinancialInsight]) -> [FinancialInsight] {
        var curated: [FinancialInsight] = []
        let calendar = Calendar.current
        let now = Date()
        
        for insight in insights {
            // Repetitive or fatigue rule suppression
            // For example, we suppress Payday Splurge warning unless today is within 7 days of payday.
            if insight.title.contains("Payday") {
                if let dataBehind = insight.dataBehind.components(separatedBy: "Last Payday: ").last?.components(separatedBy: ".").first,
                   let paydayDate = parseDate(dataBehind) {
                    let daysSincePayday = calendar.dateComponents([.day], from: paydayDate, to: now).day ?? 30
                    if daysSincePayday > 7 {
                        // Suppress, too far past payday to be actionable!
                        continue
                    }
                }
            }
            
            // Limit high severity alerts to not flood the UI
            if insight.severity == .high && curated.filter({ $0.severity == .high }).count >= 3 {
                // Suppress high fatigue items
                continue
            }
            
            curated.append(insight)
        }
        
        return curated
    }
    
    private func parseDate(_ string: String) -> Date? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.dateFormat = "yyyy-MM-dd"
        if let date = fmt.date(from: trimmed) { return date }
        fmt.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
        return fmt.date(from: trimmed)
    }
}
