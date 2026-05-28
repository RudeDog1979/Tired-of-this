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
    private let editingId: UUID?

    @Published public var merchantName = "" {
        didSet {
            if merchantName != oldValue {
                refreshMerchantSuggestions(resetSelection: false)
            }
        }
    }

    @Published public var amountString = ""
    @Published public var selectedCategory: TransactionCategory = .other
    @Published public var selectedCategoryId: UUID?
    @Published public var date = Date()
    @Published public var notes = ""
    @Published var candidates: [MerchantCandidate] = []
    @Published var mergeHintCandidate: MerchantCandidate?
    @Published public var selectedCandidateId: String?
    @Published public var selectedMerchantId: UUID?
    @Published private var pendingMerchantSelection: MerchantSelection?
    @Published public var merchantDisambiguator = ""
    @Published public var showMerchantPickSheet = false
    @Published public var saveError: String?
    @Published public var smartHint: String?

    @Published public var isSubscription = false
    @Published public var isTrial = false
    @Published public var subscriptionStartDate = Date()
    @Published public var trialEndDate = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    @Published public var renewalReminderDays = 3
    @Published public var emotionTag = ""

    public var isEditing: Bool { editingId != nil }

    public var needsDisambiguatorLabel: Bool {
        brain.merchantBrain.needsDisambiguatorLabel(
            for: merchantName,
            disambiguator: merchantDisambiguator.isEmpty ? nil : merchantDisambiguator
        )
    }

    public init(brain: BuxMuseBrain, settingsManager: AppSettingsManager, editing: Transaction? = nil, presetCategory: TransactionCategory? = nil) {
        self.brain = brain
        self.settingsManager = settingsManager
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
                selectedMerchantId = record.merchantId
                isSubscription = record.isSubscriptionLike
                isTrial = record.isTrial
                if let start = record.subscriptionStartDate { subscriptionStartDate = start }
                if let end = record.trialEndDate { trialEndDate = end }
                renewalReminderDays = record.renewalReminderDays ?? 3
                emotionTag = record.emotion ?? ""
            }
        } else if let preset = presetCategory {
            selectedCategory = preset
            selectedCategoryId = try? brain.categoryId(for: preset)
        } else {
            selectedCategoryId = try? brain.categoryId(for: .other)
        }

        refreshMerchantSuggestions(resetSelection: true)
    }

    public func refreshMerchantSuggestions(resetSelection: Bool) {
        let cleanName = merchantName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else {
            candidates = []
            mergeHintCandidate = nil
            if resetSelection {
                selectedCandidateId = nil
            }
            return
        }

        let records = (try? brain.fetchAllExpenseRecords()) ?? []
        let next = brain.merchantBrain.candidates(for: cleanName, expenseRecords: records)
        candidates = next
        let choosable = next.filter { $0.matchKind != .newMerchant }
        let nonAliasChoosable = choosable.filter { $0.matchKind != .aliasVariant }
        mergeHintCandidate = nonAliasChoosable.count == 1
            ? brain.merchantBrain.mergeHintCandidate(from: next)
            : nil

        if resetSelection {
            selectedCandidateId = nil
            pendingMerchantSelection = nil
            if editingId == nil {
                selectedMerchantId = nil
            }
        }

        applySmartDefaultsIfAppropriate(for: cleanName)
        refreshSmartHint(cleanName: cleanName, records: records)
    }

    func selectCandidate(_ candidate: MerchantCandidate) {
        merchantName = candidate.historyLabel ?? candidate.displayName
        selectedCandidateId = candidate.id
        selectedMerchantId = candidate.merchantId
        var selection = brain.merchantBrain.selection(from: candidate)
        let trimmedLabel = merchantDisambiguator.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedLabel.isEmpty {
            selection.disambiguator = trimmedLabel
        }
        pendingMerchantSelection = selection
        candidates = []
        mergeHintCandidate = nil
        showMerchantPickSheet = false

        if candidate.matchKind != .newMerchant {
            applySmartDefaults(for: candidate)
        }
    }

    public func applyMergeHint() {
        guard let hint = mergeHintCandidate else { return }
        selectCandidate(hint)
    }

    public func saveTransaction() -> Bool {
        saveError = nil
        let cleanName = merchantName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else {
            saveError = "Enter a merchant name."
            return false
        }

        let pickCandidates = brain.merchantBrain.candidates(
            for: cleanName,
            expenseRecords: (try? brain.fetchAllExpenseRecords()) ?? []
        )
        let mustPick = brain.merchantBrain.isAmbiguous(
            query: cleanName,
            candidates: pickCandidates,
            selectedCandidateId: selectedCandidateId,
            selectedMerchantId: selectedMerchantId
        ) || (
            selectedCandidateId == nil
                && selectedMerchantId == nil
                && brain.merchantBrain.shouldOfferExplicitPick(for: cleanName, candidates: pickCandidates)
        )
        if mustPick {
            candidates = pickCandidates
            showMerchantPickSheet = true
            saveError = "Choose which merchant name to use."
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

        var record = ExpenseRecord(
            id: editingId ?? UUID(),
            name: cleanName,
            amountValue: amount.value,
            currencyCode: amount.currencyCode,
            merchantId: selectedMerchantId,
            date: date,
            notes: notes.isEmpty ? nil : notes,
            isSubscriptionLike: isSubscription,
            isTrial: isSubscription && isTrial,
            subscriptionStartDate: isSubscription && !isTrial ? subscriptionStartDate : nil,
            trialEndDate: isSubscription && isTrial ? trialEndDate : nil,
            renewalReminderDays: isSubscription ? renewalReminderDays : nil,
            categoryRaw: isSubscription ? TransactionCategory.subscriptions.rawValue : selectedCategory.rawValue,
            merchantName: cleanName
        )

        if let editingId, let existing = try? brain.fetchExpenseRecord(id: editingId) {
            record.merchantId = selectedMerchantId ?? existing.merchantId
            record.createdAt = existing.createdAt
        }

        record.emotion = emotionTag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : emotionTag

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

        let selection = buildMerchantSelection(for: cleanName)

        do {
            _ = try brain.saveExpenseRecord(record, merchantSelection: selection)
            return true
        } catch {
            saveError = "Could not save. Try again."
            print("Expense save failed: \(error)")
            return false
        }
    }

    // MARK: - Private

    private func buildMerchantSelection(for cleanName: String) -> MerchantSelection? {
        if var selection = pendingMerchantSelection {
            if needsDisambiguatorLabel {
                let trimmed = merchantDisambiguator.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    selection.disambiguator = trimmed
                }
            }
            return selection
        }

        if let selectedMerchantId,
           let merchant = try? brain.fetchAllMerchantRecords().first(where: { $0.id == selectedMerchantId }) {
            return MerchantSelection(
                merchantId: merchant.id,
                displayName: cleanName,
                disambiguator: merchant.disambiguator.isEmpty ? nil : merchant.disambiguator,
                createNew: false
            )
        }

        if let hint = mergeHintCandidate, selectedCandidateId == nil, selectedMerchantId == nil {
            return brain.merchantBrain.selection(from: hint)
        }

        let trimmedDisambiguator = merchantDisambiguator.trimmingCharacters(in: .whitespacesAndNewlines)
        if needsDisambiguatorLabel && !trimmedDisambiguator.isEmpty {
            return MerchantSelection(
                displayName: cleanName,
                disambiguator: trimmedDisambiguator,
                createNew: true,
                historyLabel: cleanName
            )
        }

        return MerchantSelection(displayName: cleanName, createNew: false, historyLabel: cleanName)
    }

    private func applySmartDefaultsIfAppropriate(for cleanName: String) {
        guard editingId == nil else { return }
        guard selectedCandidateId == nil, selectedMerchantId == nil else { return }
        guard let hint = mergeHintCandidate else { return }
        applySmartDefaults(for: hint)
    }

    private func applySmartDefaults(for candidate: MerchantCandidate) {
        guard editingId == nil else { return }
        let label = candidate.historyLabel ?? candidate.displayName
        let pastTx = brain.financialEngine.allTransactions()
        let matches = pastTx.filter {
            MerchantLogoEngine.normalizeMerchantName($0.merchantName)
                == MerchantLogoEngine.normalizeMerchantName(label)
        }
        guard let firstMatch = matches.first else { return }

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

    private func refreshSmartHint(cleanName: String, records: [ExpenseRecord]) {
        guard editingId == nil else {
            smartHint = nil
            return
        }
        let preview = ExpenseRecord(
            name: cleanName,
            amountValue: -1,
            currencyCode: settingsManager.selectedCurrency.id,
            date: date,
            categoryRaw: selectedCategory.rawValue,
            merchantName: cleanName
        )
        let analysis = ExpenseIntelligenceEngine.analyze(
            record: preview,
            allRecords: records,
            activeSubscriptions: brain.financialEngine.activeSubscriptions()
        )
        var hints: [String] = []
        if let recurrence = analysis.display.recurrenceSummary { hints.append(recurrence) }
        if let sub = analysis.display.subscriptionSummary { hints.append(sub) }
        smartHint = hints.isEmpty ? nil : hints.joined(separator: " · ")
    }
}
