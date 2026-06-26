//
//  SpendingTrendsModels.swift
//  BuxMuse
//
//  Precomputed display for the full-screen spending trends experience.
//

import Foundation

enum SpendingTrendsPeriod: String, CaseIterable, Identifiable, Sendable {
    case week
    case month
    case year

    var id: String { rawValue }

    func catalogTitle(locale: Locale) -> String {
        switch self {
        case .week:
            return BuxLocalizedString.string("Week", locale: locale)
        case .month:
            return BuxLocalizedString.string("Month", locale: locale)
        case .year:
            return BuxLocalizedString.string("Year", locale: locale)
        }
    }
}

enum SpendingTrendsBreakdownMode: String, CaseIterable, Identifiable {
    case category
    case merchant

    var id: String { rawValue }

    func catalogTitle(locale: Locale) -> String {
        switch self {
        case .category:
            return BuxLocalizedString.string("By Category", locale: locale)
        case .merchant:
            return BuxLocalizedString.string("By Merchant", locale: locale)
        }
    }
}

struct SpendingTrendsAnchor: Identifiable, Hashable, Sendable {
    let id: String
    let period: SpendingTrendsPeriod
    let start: Date
    let end: Date

    init(period: SpendingTrendsPeriod, start: Date, end: Date) {
        self.period = period
        self.start = start
        self.end = end
        self.id = "\(period.rawValue)-\(start.timeIntervalSince1970)"
    }
}

struct SpendingTrendBarBucket: Identifiable, Equatable, Hashable, Sendable {
    let id: String
    let label: String
    let shortLabel: String
    let start: Date
    let end: Date
    let amount: Double
    let gradientIndex: Int
}

struct SpendingTrendBreakdownRow: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let transactionCount: Int
    let amount: Double
    let priorAmount: Double

    var changeAmount: Double { amount - priorAmount }
}

struct SpendingTrendsDisplay: Equatable, Sendable {
    let period: SpendingTrendsPeriod
    let anchor: SpendingTrendsAnchor
    let title: String
    let totalSpent: Double
    let priorTotalSpent: Double
    let changeAmount: Double
    let comparisonCopy: String
    let barBuckets: [SpendingTrendBarBucket]
    let categoryRows: [SpendingTrendBreakdownRow]
    let merchantRows: [SpendingTrendBreakdownRow]

    var isEmptyShell: Bool {
        barBuckets.isEmpty && categoryRows.isEmpty && merchantRows.isEmpty && totalSpent == 0
    }

    static func shell(for anchor: SpendingTrendsAnchor, locale: Locale, calendar: Calendar) -> SpendingTrendsDisplay {
        let title: String
        switch anchor.period {
        case .month:
            title = BuxDisplayDate.monthYear(from: anchor.start, locale: locale, calendar: calendar)
        case .week:
            let weekEnd = calendar.date(byAdding: .day, value: -1, to: anchor.end) ?? anchor.end
            title = BuxDisplayDate.monthDayRange(from: anchor.start, to: weekEnd, locale: locale, calendar: calendar)
        case .year:
            title = BuxDisplayDate.year(from: anchor.start, locale: locale, calendar: calendar)
        }

        return SpendingTrendsDisplay(
            period: anchor.period,
            anchor: anchor,
            title: title,
            totalSpent: 0,
            priorTotalSpent: 0,
            changeAmount: 0,
            comparisonCopy: "",
            barBuckets: [],
            categoryRows: [],
            merchantRows: []
        )
    }
}

struct SpendingTrendsDrillContext: Hashable, Identifiable {
    let id: String
    let title: String
    let start: Date
    let end: Date
    let period: SpendingTrendsPeriod?
    let categoryName: String?
    let merchantName: String?

    var isMerchantDrill: Bool { merchantName != nil && categoryName == nil }
}
