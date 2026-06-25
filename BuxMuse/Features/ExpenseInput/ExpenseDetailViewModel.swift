//
//  ExpenseDetailViewModel.swift
//  BuxMuse
//
//  Detail modal state for a single expense.
//

import Foundation
import Combine

@MainActor
final class ExpenseDetailViewModel: ObservableObject {
    @Published private(set) var record: ExpenseRecord
    @Published private(set) var intelligence: ExpenseIntelligenceDisplay = .empty
    @Published var notesDraft: String

    private let brain: BuxMuseBrain
    private let settingsManager: AppSettingsManager

    init(record: ExpenseRecord, brain: BuxMuseBrain, settingsManager: AppSettingsManager) {
        self.record = record
        self.brain = brain
        self.settingsManager = settingsManager
        self.notesDraft = record.notes ?? ""
        reloadIntelligence()
    }

    func reloadIntelligence() {
        intelligence = brain.expenseIntelligenceDisplay(
            for: record.id,
            locale: settingsManager.interfaceLocale
        )
    }

    func reloadRecord() {
        if let latest = try? brain.fetchExpenseRecord(id: record.id) {
            record = latest
            notesDraft = latest.notes ?? ""
            reloadIntelligence()
        }
    }

    func formattedAmount() -> String {
        let currency = AppSettingsManager.currencySetting(for: record.currencyCode)
        return AppSettingsManager.format(amount: record.amountValue, currency: currency)
    }

    func saveNotes() throws {
        try brain.updateExpenseNotes(id: record.id, notes: notesDraft.isEmpty ? nil : notesDraft)
        reloadRecord()
    }

    func delete() throws {
        try brain.deleteExpense(id: record.id)
    }

    func changeCategory(_ category: TransactionCategory, categoryId: UUID? = nil) throws {
        try brain.changeExpenseCategory(id: record.id, category: category, categoryId: categoryId)
        reloadRecord()
    }

    func convertToSubscription() throws {
        try brain.convertExpenseToSubscription(id: record.id)
        reloadRecord()
    }

    func markRecurring(type: String = "monthly") throws {
        try brain.markExpenseRecurring(id: record.id, type: type)
        reloadRecord()
    }

    func setExcludedFromSpending(_ excluded: Bool) throws {
        var updated = record
        updated.isExcludedFromSpending = excluded
        updated.updatedAt = Date()
        _ = try brain.saveExpenseRecord(updated)
        reloadRecord()
    }
}
