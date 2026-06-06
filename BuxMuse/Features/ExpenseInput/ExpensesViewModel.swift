//
//  ExpensesViewModel.swift
//  BuxMuse
//
//  Lightweight filtering and timeline grouping for the expenses list.
//

import Foundation
import Combine

@MainActor
final class ExpensesViewModel: ObservableObject {
    @Published var filters = ExpenseFilterState()
    @Published var searchScope: ExpenseSearchScope = .all
    @Published private(set) var categories: [ExpenseCategoryRecord] = []
    @Published private(set) var merchants: [ExpenseMerchantRecord] = []

    func reloadCatalog(brain: BuxMuseBrain) {
        categories = (try? brain.fetchAllCategoryRecords()) ?? []
        merchants = (try? brain.fetchAllMerchantRecords()) ?? []
    }

    func applySearchScope() {
        switch searchScope {
        case .all:
            filters.recurringOnly = false
            filters.subscriptionLikeOnly = false
            filters.refundsOnly = false
        case .recurring:
            filters.recurringOnly = true
            filters.subscriptionLikeOnly = false
            filters.refundsOnly = false
        case .subscriptions:
            filters.recurringOnly = false
            filters.subscriptionLikeOnly = true
            filters.refundsOnly = false
        case .refunds:
            filters.recurringOnly = false
            filters.subscriptionLikeOnly = false
            filters.refundsOnly = true
        }
    }

    func filteredRecords(from records: [ExpenseRecord]) -> [ExpenseRecord] {
        let query = filters.searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return records.filter { record in
            if !query.isEmpty {
                let haystack = [
                    record.name,
                    record.merchantName,
                    record.notes ?? ""
                ].joined(separator: " ").lowercased()
                guard haystack.contains(query) else { return false }
            }
            if let categoryId = filters.categoryId, record.categoryId != categoryId { return false }
            if let systemRaw = filters.systemCategoryRaw {
                var matches = record.transactionCategory.rawValue == systemRaw
                if !matches,
                   let recordCategoryId = record.categoryId,
                   let custom = categories.first(where: { $0.id == recordCategoryId }),
                   custom.systemCategoryRaw == systemRaw {
                    matches = true
                }
                guard matches else { return false }
            }
            if let merchantId = filters.merchantId, record.merchantId != merchantId { return false }
            if let from = filters.dateFrom, record.date < from { return false }
            if let to = filters.dateTo, record.date > to { return false }
            if let min = filters.minAmount, abs(record.amountValue) < min { return false }
            if let max = filters.maxAmount, abs(record.amountValue) > max { return false }
            if filters.recurringOnly, !record.isRecurring { return false }
            if filters.subscriptionLikeOnly, !record.isSubscriptionLike { return false }
            if filters.refundsOnly, !record.isRefund { return false }
            if let heat = filters.heatZoneBucket, record.heatZoneBucket != heat { return false }
            return true
        }
    }

    func timelineGroups(from records: [ExpenseRecord]) -> [ExpenseTimelineGroup] {
        ExpenseTimelineGrouper.group(records)
    }

    func categoryName(for record: ExpenseRecord) -> String {
        if let id = record.categoryId,
           let match = categories.first(where: { $0.id == id }) {
            return match.name
        }
        return record.transactionCategory.displayName
    }

    var availableHeatZones: [String] {
        ["late_night", "weekend", "payday", "category_spike", "merchant_spike"]
    }
}
