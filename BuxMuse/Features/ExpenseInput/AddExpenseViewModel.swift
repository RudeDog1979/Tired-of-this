//
//  AddExpenseViewModel.swift
//  BuxMuse
//  Features/ExpenseInput/
//
//  ViewModel mediating between BuxMuseBrain and AddExpense UI.
//

import SwiftUI
import Combine

public final class AddExpenseViewModel: ObservableObject {
    private let brain: BuxMuseBrain
    private let settingsManager: AppSettingsManager
    private let autocompleteEngine: MerchantAutocompleteEngine
    private let editingId: UUID?

    public var merchantName = "" {
        didSet {
            updateSuggestionsAndDefaults(for: merchantName)
            objectWillChange.send()
        }
    }

    @Published public var amountString = ""
    @Published public var selectedCategory: TransactionCategory = .other
    @Published public var selectedCategoryId: UUID?
    @Published public var date = Date()
    @Published public var notes = ""
    @Published public var suggestions: [String] = []
    @Published public var saveError: String?
    @Published public var smartHint: String?

    @Published public var isSubscription = false
    @Published public var isTrial = false
    @Published public var subscriptionStartDate = Date()
    @Published public var trialEndDate = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    @Published public var renewalReminderDays = 3

    public var isEditing: Bool { editingId != nil }

    public init(brain: BuxMuseBrain, settingsManager: AppSettingsManager, editing: Transaction? = nil) {
        self.brain = brain
        self.settingsManager = settingsManager
        self.autocompleteEngine = MerchantAutocompleteEngine(engine: brain.financialEngine)
        self.editingId = editing?.id

        if let tx = editing {
            merchantName = tx.merchantName
            selectedCategory = tx.category
            date = tx.date
            notes = tx.notes ?? ""
            let absAmount = abs(tx.amount.value)
            amountString = String(format: "%.2f", NSDecimalNumber(decimal: absAmount).doubleValue)
            if let record = try? brain.fetchExpenseRecord(id: tx.id) {
                selectedCategoryId = record.categoryId
                isSubscription = record.isSubscriptionLike
                isTrial = record.isTrial
                if let start = record.subscriptionStartDate { subscriptionStartDate = start }
                if let end = record.trialEndDate { trialEndDate = end }
                renewalReminderDays = record.renewalReminderDays ?? 3
            }
        } else {
            selectedCategoryId = try? brain.categoryId(for: .other)
        }
    }

    func updateSuggestionsAndDefaults(for name: String) {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else {
            suggestions = []
            return
        }

        suggestions = autocompleteEngine.suggestions(for: cleanName)

        guard editingId == nil else { return }

        let pastTx = brain.financialEngine.allTransactions()
        let matches = pastTx.filter {
            MerchantLogoEngine.normalizeMerchantName($0.merchantName) == MerchantLogoEngine.normalizeMerchantName(cleanName)
        }

        if let firstMatch = matches.first {
            selectedCategory = firstMatch.category
            selectedCategoryId = try? brain.categoryId(for: firstMatch.category)
            let amounts = Set(matches.map { $0.amount.value })
            if amounts.count == 1, let recurringAmount = amounts.first, amountString.isEmpty {
                let absAmount = abs(recurringAmount)
                amountString = String(format: "%.2f", NSDecimalNumber(decimal: absAmount).doubleValue)
            }
            if let note = firstMatch.notes, !note.isEmpty, notes.isEmpty {
                notes = note
            }
        }

        if editingId == nil {
            let preview = ExpenseRecord(
                name: cleanName,
                amountValue: -1,
                currencyCode: settingsManager.selectedCurrency.id,
                date: date,
                categoryRaw: selectedCategory.rawValue,
                merchantName: cleanName
            )
            let all = (try? brain.fetchAllExpenseRecords()) ?? []
            let analysis = ExpenseIntelligenceEngine.analyze(
                record: preview,
                allRecords: all,
                activeSubscriptions: brain.financialEngine.activeSubscriptions()
            )
            var hints: [String] = []
            if let recurrence = analysis.display.recurrenceSummary { hints.append(recurrence) }
            if let sub = analysis.display.subscriptionSummary { hints.append(sub) }
            smartHint = hints.isEmpty ? nil : hints.joined(separator: " · ")
        }
    }

    public func selectSuggestion(_ suggestion: String) {
        merchantName = suggestion
        suggestions = []
    }

    public func saveTransaction() -> Bool {
        saveError = nil
        let cleanName = merchantName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else {
            saveError = "Enter a merchant name."
            return false
        }

        if isSubscription && isTrial && trialEndDate <= Date() {
            saveError = "Trial end date must be in the future."
            return false
        }

        let cleanedAmountStr = amountString.replacingOccurrences(of: ",", with: ".")
        guard let doubleVal = Double(cleanedAmountStr) else {
            saveError = "Enter a valid amount."
            return false
        }
        let decimalValue = Decimal(doubleVal)
        let finalValue = selectedCategory == .income ? abs(decimalValue) : -abs(decimalValue)
        let amount = MoneyAmount(value: finalValue, currencyCode: settingsManager.selectedCurrency.id)

        let normalized = MerchantLogoEngine.normalizeMerchantName(cleanName)
        let canonicalName = normalized.capitalized

        var record = ExpenseRecord(
            id: editingId ?? UUID(),
            name: canonicalName,
            amountValue: amount.value,
            currencyCode: amount.currencyCode,
            date: date,
            notes: notes.isEmpty ? nil : notes,
            isSubscriptionLike: isSubscription,
            isTrial: isSubscription && isTrial,
            subscriptionStartDate: isSubscription && !isTrial ? subscriptionStartDate : nil,
            trialEndDate: isSubscription && isTrial ? trialEndDate : nil,
            renewalReminderDays: isSubscription ? renewalReminderDays : nil,
            categoryRaw: isSubscription ? TransactionCategory.subscriptions.rawValue : selectedCategory.rawValue,
            merchantName: canonicalName
        )

        if let editingId, let existing = try? brain.fetchExpenseRecord(id: editingId) {
            record.merchantId = existing.merchantId
            record.createdAt = existing.createdAt
        }

        if let categoryId = selectedCategoryId {
            record.categoryId = categoryId
        } else {
            record.categoryId = try? brain.categoryId(for: record.transactionCategory)
        }

        if isSubscription {
            record.nextExpectedDate = isTrial
                ? trialEndDate
                : Calendar.current.date(byAdding: .month, value: 1, to: subscriptionStartDate)
        }

        do {
            _ = try brain.saveExpenseRecord(record)
            return true
        } catch {
            saveError = "Could not save. Try again."
            print("Expense save failed: \(error)")
            return false
        }
    }
}
