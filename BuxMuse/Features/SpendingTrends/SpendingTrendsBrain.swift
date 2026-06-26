//
//  SpendingTrendsBrain.swift
//  BuxMuse
//
//  Brain fetch + anchor discovery for spending trends.
//

import Foundation

extension BuxMuseBrain {
    func fetchSpendingTrendsDisplay(
        anchor: SpendingTrendsAnchor,
        locale: Locale
    ) async -> SpendingTrendsDisplay? {
        let store = SettingsStore.shared
        let calendar = BuxBudgetPeriodCalculator.calendar(weekStartDay: store.weekStartDay)
        let hustleId = HustleWorkspaceFilter.selectedHustleId
        let includeUnassigned = HustleWorkspaceFilter.showUnassignedWhenFiltered
        let priorAnchor = SpendingTrendsBuilder.priorAnchor(for: anchor, calendar: calendar)
        let categoryRecords = categoryRecords
        let categoriesById = Dictionary(uniqueKeysWithValues: categoryRecords.map { ($0.id, $0) })
        let sql = persistence.expenseDatabase.sql

        let payloads: (current: ExpenseRowPayload, prior: ExpenseRowPayload)
        do {
            payloads = try await Task.detached(priority: .userInitiated) {
                let current = try sql.fetchRecordsRaw(
                    from: anchor.start,
                    to: anchor.end,
                    hustleId: hustleId,
                    includeUnassigned: includeUnassigned
                )
                let prior = try sql.fetchRecordsRaw(
                    from: priorAnchor.start,
                    to: priorAnchor.end,
                    hustleId: hustleId,
                    includeUnassigned: includeUnassigned
                )
                return (current, prior)
            }.value
        } catch {
            print("fetchSpendingTrendsDisplay failed: \(error)")
            return nil
        }

        let currentRecords = ExpenseGRDBRecordMapper.makeRecords(from: payloads.current)
        let priorRecords = ExpenseGRDBRecordMapper.makeRecords(from: payloads.prior)

        return SpendingTrendsBuilder.buildDisplay(
            period: anchor.period,
            anchor: anchor,
            currentRecords: currentRecords,
            priorRecords: priorRecords,
            categoriesById: categoriesById,
            locale: locale,
            calendar: calendar
        )
    }

    func fetchSpendingTrendsRecords(
        from start: Date,
        to end: Date
    ) async -> [ExpenseRecord] {
        let hustleId = HustleWorkspaceFilter.selectedHustleId
        let includeUnassigned = HustleWorkspaceFilter.showUnassignedWhenFiltered
        let sql = persistence.expenseDatabase.sql
        do {
            let payload = try await Task.detached(priority: .userInitiated) {
                try sql.fetchRecordsRaw(
                    from: start,
                    to: end,
                    hustleId: hustleId,
                    includeUnassigned: includeUnassigned
                )
            }.value
            return ExpenseGRDBRecordMapper.makeRecords(from: payload)
        } catch {
            print("fetchSpendingTrendsRecords failed: \(error)")
            return []
        }
    }

    func discoverSpendingTrendsAnchors(
        period: SpendingTrendsPeriod
    ) async -> [SpendingTrendsAnchor] {
        let store = SettingsStore.shared
        let calendar = BuxBudgetPeriodCalculator.calendar(weekStartDay: store.weekStartDay)
        let hustleId = HustleWorkspaceFilter.selectedHustleId
        let includeUnassigned = HustleWorkspaceFilter.showUnassignedWhenFiltered
        let sql = persistence.expenseDatabase.sql
        let now = Date()

        let monthStarts: [Date]
        do {
            let rows = try await Task.detached(priority: .userInitiated) {
                try sql.fetchAllExpenseMonthIndex(
                    hustleId: hustleId,
                    includeUnassigned: includeUnassigned
                )
            }.value
            monthStarts = rows.map { Date(timeIntervalSince1970: $0.monthStart) }
        } catch {
            print("discoverSpendingTrendsAnchors failed: \(error)")
            monthStarts = []
        }

        let normalizedMonthStarts: [Date] = {
            var months = monthStarts
            let currentMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
            if !months.contains(where: { calendar.isDate($0, equalTo: currentMonth, toGranularity: .month) }) {
                months.append(currentMonth)
            }
            return months.sorted(by: <)
        }()

        guard let earliest = normalizedMonthStarts.min() else {
            let currentMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
            let end = calendar.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
            switch period {
            case .month:
                return [SpendingTrendsAnchor(period: .month, start: currentMonth, end: end)]
            case .week:
                let interval = calendar.dateInterval(of: .weekOfYear, for: now) ?? DateInterval(start: now, end: now)
                return [SpendingTrendsAnchor(period: .week, start: interval.start, end: interval.end)]
            case .year:
                var components = calendar.dateComponents([.year], from: now)
                components.month = 1
                components.day = 1
                let start = calendar.date(from: components) ?? now
                let yearEnd = calendar.date(byAdding: .year, value: 1, to: start) ?? start
                return [SpendingTrendsAnchor(period: .year, start: start, end: yearEnd)]
            }
        }

        switch period {
        case .month:
            return SpendingTrendsBuilder.makeMonthAnchors(monthStarts: normalizedMonthStarts, calendar: calendar)
        case .week:
            return SpendingTrendsBuilder.makeWeekAnchors(from: earliest, to: now, calendar: calendar)
        case .year:
            return SpendingTrendsBuilder.makeYearAnchors(from: earliest, to: now, calendar: calendar)
        }
    }
}
