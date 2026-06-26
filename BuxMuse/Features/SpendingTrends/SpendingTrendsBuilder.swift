//
//  SpendingTrendsBuilder.swift
//  BuxMuse
//
//  Pure aggregation for spending trends — safe to run off the main thread.
//

import Foundation

enum SpendingTrendsBuilder {
    static func buildDisplay(
        period: SpendingTrendsPeriod,
        anchor: SpendingTrendsAnchor,
        currentRecords: [ExpenseRecord],
        priorRecords: [ExpenseRecord],
        categoriesById: [UUID: ExpenseCategoryRecord],
        locale: Locale,
        calendar: Calendar
    ) -> SpendingTrendsDisplay {
        let currentSpending = bookedOutflows(from: currentRecords)
        let priorSpending = bookedOutflows(from: priorRecords)

        let totalSpent = currentSpending.reduce(0) { $0 + $1.spendingAmountDouble }
        let priorTotalSpent = priorSpending.reduce(0) { $0 + $1.spendingAmountDouble }
        let changeAmount = totalSpent - priorTotalSpent

        let barBuckets = makeBarBuckets(
            period: period,
            anchorStart: anchor.start,
            anchorEnd: anchor.end,
            spending: currentSpending,
            calendar: calendar,
            locale: locale
        )

        let categoryRows = makeBreakdownRows(
            records: currentSpending,
            priorRecords: priorSpending,
            categoriesById: categoriesById,
            locale: locale,
            groupByCategory: true
        )

        let merchantRows = makeBreakdownRows(
            records: currentSpending,
            priorRecords: priorSpending,
            categoriesById: categoriesById,
            locale: locale,
            groupByCategory: false
        )

        let title = periodTitle(
            period: period,
            anchorStart: anchor.start,
            locale: locale,
            calendar: calendar
        )

        let comparisonCopy = comparisonSentence(
            period: period,
            changeAmount: changeAmount,
            locale: locale
        )

        return SpendingTrendsDisplay(
            period: period,
            anchor: anchor,
            title: title,
            totalSpent: totalSpent,
            priorTotalSpent: priorTotalSpent,
            changeAmount: changeAmount,
            comparisonCopy: comparisonCopy,
            barBuckets: barBuckets,
            categoryRows: categoryRows,
            merchantRows: merchantRows
        )
    }

    static func bookedOutflows(from records: [ExpenseRecord]) -> [ExpenseRecord] {
        records.filter { !$0.walletIsPending && $0.isSpendingOutflow }
    }

    static func priorAnchor(
        for anchor: SpendingTrendsAnchor,
        calendar: Calendar
    ) -> SpendingTrendsAnchor {
        switch anchor.period {
        case .month:
            let start = calendar.date(byAdding: .month, value: -1, to: anchor.start) ?? anchor.start
            let end = anchor.start
            return SpendingTrendsAnchor(period: .month, start: start, end: end)
        case .week:
            let start = calendar.date(byAdding: .weekOfYear, value: -1, to: anchor.start) ?? anchor.start
            let end = anchor.start
            return SpendingTrendsAnchor(period: .week, start: start, end: end)
        case .year:
            let start = calendar.date(byAdding: .year, value: -1, to: anchor.start) ?? anchor.start
            let end = anchor.start
            return SpendingTrendsAnchor(period: .year, start: start, end: end)
        }
    }

    static func makeMonthAnchors(
        monthStarts: [Date],
        calendar: Calendar
    ) -> [SpendingTrendsAnchor] {
        // Oldest left → newest/current right. Swipe right to reach previous months.
        monthStarts.sorted(by: <).map { start in
            let end = calendar.date(byAdding: .month, value: 1, to: start) ?? start
            return SpendingTrendsAnchor(period: .month, start: start, end: end)
        }
    }

    static func makeWeekAnchors(
        from earliest: Date,
        to latest: Date,
        calendar: Calendar
    ) -> [SpendingTrendsAnchor] {
        var anchors: [SpendingTrendsAnchor] = []
        var cursor = calendar.startOfDay(for: earliest)
        let endLimit = latest

        if let weekStart = calendar.dateInterval(of: .weekOfYear, for: cursor)?.start {
            cursor = weekStart
        }

        while cursor <= endLimit {
            guard let interval = calendar.dateInterval(of: .weekOfYear, for: cursor) else { break }
            anchors.append(SpendingTrendsAnchor(period: .week, start: interval.start, end: interval.end))
            guard let next = calendar.date(byAdding: .weekOfYear, value: 1, to: interval.start) else { break }
            cursor = next
        }

        return anchors.sorted { $0.start < $1.start }
    }

    static func makeYearAnchors(
        from earliest: Date,
        to latest: Date,
        calendar: Calendar
    ) -> [SpendingTrendsAnchor] {
        let startYear = calendar.component(.year, from: earliest)
        let endYear = calendar.component(.year, from: latest)
        guard startYear <= endYear else { return [] }

        return (startYear...endYear).compactMap { year -> SpendingTrendsAnchor? in
            var components = DateComponents()
            components.year = year
            components.month = 1
            components.day = 1
            guard let start = calendar.date(from: components),
                  let end = calendar.date(byAdding: .year, value: 1, to: start) else { return nil }
            return SpendingTrendsAnchor(period: .year, start: start, end: end)
        }
    }

    // MARK: - Private

    private static func makeBarBuckets(
        period: SpendingTrendsPeriod,
        anchorStart: Date,
        anchorEnd: Date,
        spending: [ExpenseRecord],
        calendar: Calendar,
        locale: Locale
    ) -> [SpendingTrendBarBucket] {
        switch period {
        case .month:
            return weekBucketsInMonth(
                monthStart: anchorStart,
                monthEnd: anchorEnd,
                spending: spending,
                calendar: calendar,
                locale: locale
            )
        case .week:
            return dayBucketsInWeek(
                weekStart: anchorStart,
                weekEnd: anchorEnd,
                spending: spending,
                calendar: calendar,
                locale: locale
            )
        case .year:
            return monthBucketsInYear(
                yearStart: anchorStart,
                yearEnd: anchorEnd,
                spending: spending,
                calendar: calendar,
                locale: locale
            )
        }
    }

    private static func weekBucketsInMonth(
        monthStart: Date,
        monthEnd: Date,
        spending: [ExpenseRecord],
        calendar: Calendar,
        locale: Locale
    ) -> [SpendingTrendBarBucket] {
        var intervals: [DateInterval] = []
        var cursor = monthStart

        while cursor < monthEnd {
            guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: cursor) else { break }
            let start = max(weekInterval.start, monthStart)
            let end = min(weekInterval.end, monthEnd)
            if start < end {
                intervals.append(DateInterval(start: start, end: end))
            }
            guard let nextWeekStart = calendar.date(byAdding: .weekOfYear, value: 1, to: weekInterval.start) else { break }
            if nextWeekStart >= monthEnd { break }
            cursor = nextWeekStart
        }

        return intervals.enumerated().map { index, interval in
            let amount = sum(spending, from: interval.start, to: interval.end)
            let startDay = calendar.component(.day, from: interval.start)
            let endDay = calendar.component(.day, from: calendar.date(byAdding: .day, value: -1, to: interval.end) ?? interval.end)
            let label = "\(startDay)–\(endDay)"
            return SpendingTrendBarBucket(
                id: "week-\(interval.start.timeIntervalSince1970)",
                label: label,
                shortLabel: label,
                start: interval.start,
                end: interval.end,
                amount: amount,
                gradientIndex: index
            )
        }
    }

    private static func dayBucketsInWeek(
        weekStart: Date,
        weekEnd: Date,
        spending: [ExpenseRecord],
        calendar: Calendar,
        locale: Locale
    ) -> [SpendingTrendBarBucket] {
        return (0..<7).compactMap { offset -> SpendingTrendBarBucket? in
            guard let start = calendar.date(byAdding: .day, value: offset, to: weekStart),
                  let end = calendar.date(byAdding: .day, value: 1, to: start),
                  start < weekEnd else { return nil }
            let clippedEnd = min(end, weekEnd)
            let amount = sum(spending, from: start, to: clippedEnd)
            let short = BuxDisplayDate.shortWeekday(from: start, locale: locale, calendar: calendar)
            return SpendingTrendBarBucket(
                id: "day-\(start.timeIntervalSince1970)",
                label: short,
                shortLabel: short,
                start: start,
                end: clippedEnd,
                amount: amount,
                gradientIndex: offset
            )
        }
    }

    private static func monthBucketsInYear(
        yearStart: Date,
        yearEnd: Date,
        spending: [ExpenseRecord],
        calendar: Calendar,
        locale: Locale
    ) -> [SpendingTrendBarBucket] {
        return (0..<12).compactMap { offset -> SpendingTrendBarBucket? in
            guard let start = calendar.date(byAdding: .month, value: offset, to: yearStart),
                  let end = calendar.date(byAdding: .month, value: 1, to: start),
                  start < yearEnd else { return nil }
            let amount = sum(spending, from: start, to: min(end, yearEnd))
            let label = BuxDisplayDate.shortMonth(from: start, locale: locale, calendar: calendar)
            return SpendingTrendBarBucket(
                id: "month-\(start.timeIntervalSince1970)",
                label: label,
                shortLabel: label,
                start: start,
                end: min(end, yearEnd),
                amount: amount,
                gradientIndex: offset
            )
        }
    }

    private static func sum(_ records: [ExpenseRecord], from start: Date, to end: Date) -> Double {
        records.filter { $0.date >= start && $0.date < end }
            .reduce(0) { $0 + $1.spendingAmountDouble }
    }

    private static func makeBreakdownRows(
        records: [ExpenseRecord],
        priorRecords: [ExpenseRecord],
        categoriesById: [UUID: ExpenseCategoryRecord],
        locale: Locale,
        groupByCategory: Bool
    ) -> [SpendingTrendBreakdownRow] {
        let grouped = Dictionary(grouping: records) { record -> String in
            if groupByCategory {
                return record.resolvedCategoryLabel(categoriesById: categoriesById, locale: locale)
            }
            let merchant = record.merchantName.trimmingCharacters(in: .whitespacesAndNewlines)
            return merchant.isEmpty
                ? BuxLocalizedString.string("Unknown merchant", locale: locale)
                : merchant
        }

        let priorGrouped = Dictionary(grouping: priorRecords) { record -> String in
            if groupByCategory {
                return record.resolvedCategoryLabel(categoriesById: categoriesById, locale: locale)
            }
            let merchant = record.merchantName.trimmingCharacters(in: .whitespacesAndNewlines)
            return merchant.isEmpty
                ? BuxLocalizedString.string("Unknown merchant", locale: locale)
                : merchant
        }

        return grouped.map { name, items in
            let amount = items.reduce(0) { $0 + $1.spendingAmountDouble }
            let priorAmount = (priorGrouped[name] ?? []).reduce(0) { $0 + $1.spendingAmountDouble }
            return SpendingTrendBreakdownRow(
                id: name,
                name: name,
                transactionCount: items.count,
                amount: amount,
                priorAmount: priorAmount
            )
        }
        .sorted { $0.amount > $1.amount }
    }

    private static func periodTitle(
        period: SpendingTrendsPeriod,
        anchorStart: Date,
        locale: Locale,
        calendar: Calendar
    ) -> String {
        switch period {
        case .month:
            return BuxDisplayDate.monthYear(from: anchorStart, locale: locale, calendar: calendar)
        case .week:
            let weekEnd = calendar.date(byAdding: .day, value: -1, to: calendar.date(byAdding: .weekOfYear, value: 1, to: anchorStart) ?? anchorStart) ?? anchorStart
            return BuxDisplayDate.monthDayRange(from: anchorStart, to: weekEnd, locale: locale, calendar: calendar)
        case .year:
            return BuxDisplayDate.year(from: anchorStart, locale: locale, calendar: calendar)
        }
    }

    private static func comparisonSentence(
        period: SpendingTrendsPeriod,
        changeAmount: Double,
        locale: Locale
    ) -> String {
        let priorLabel: String
        switch period {
        case .month:
            priorLabel = BuxLocalizedString.string("last month", locale: locale)
        case .week:
            priorLabel = BuxLocalizedString.string("last week", locale: locale)
        case .year:
            priorLabel = BuxLocalizedString.string("last year", locale: locale)
        }

        if abs(changeAmount) < 0.005 {
            return BuxLocalizedString.format(
                "Same as %@.",
                locale: locale,
                priorLabel
            )
        }

        if changeAmount > 0 {
            return BuxLocalizedString.format(
                "You spent more than %@.",
                locale: locale,
                priorLabel
            )
        }

        return BuxLocalizedString.format(
            "You spent less than %@.",
            locale: locale,
            priorLabel
        )
    }
}
