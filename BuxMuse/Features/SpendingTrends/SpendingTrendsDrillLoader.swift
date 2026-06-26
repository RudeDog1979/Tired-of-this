//
//  SpendingTrendsDrillLoader.swift
//  BuxMuse
//

import Foundation

enum SpendingTrendsDrillLoader {
    static func loadRecords(
        context: SpendingTrendsDrillContext,
        brain: BuxMuseBrain,
        locale: Locale
    ) async -> [ExpenseRecord] {
        let fetched = await brain.fetchSpendingTrendsRecords(from: context.start, to: context.end)
        let spending = SpendingTrendsBuilder.bookedOutflows(from: fetched)
        let categoriesById = Dictionary(uniqueKeysWithValues: brain.categoryRecords.map { ($0.id, $0) })

        let filtered = spending.filter { record in
            if let categoryName = context.categoryName {
                let label = record.resolvedCategoryLabel(categoriesById: categoriesById, locale: locale)
                guard label == categoryName else { return false }
            }
            if let merchantName = context.merchantName {
                let merchant = record.merchantName.trimmingCharacters(in: .whitespacesAndNewlines)
                let target = merchantName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard merchant.caseInsensitiveCompare(target) == .orderedSame else { return false }
            }
            return true
        }

        return filtered.sorted { $0.date > $1.date }
    }

    static func dominantCategory(
        for records: [ExpenseRecord],
        brain: BuxMuseBrain,
        locale: Locale
    ) -> String? {
        guard !records.isEmpty else { return nil }
        let categoriesById = Dictionary(uniqueKeysWithValues: brain.categoryRecords.map { ($0.id, $0) })
        let grouped = Dictionary(grouping: records) {
            $0.resolvedCategoryLabel(categoriesById: categoriesById, locale: locale)
        }
        return grouped.max(by: { $0.value.count < $1.value.count })?.key
    }
}
