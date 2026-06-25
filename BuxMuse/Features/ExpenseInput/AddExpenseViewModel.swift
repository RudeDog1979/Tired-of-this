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

    private var locale: Locale { settingsManager.interfaceLocale }

    private func loc(_ key: String) -> String {
        BuxCatalogLabel.string(key, locale: locale)
    }

    @Published public var merchantName = "" {
        didSet {
            guard !skipMerchantSuggestionRefresh else { return }
            if merchantName != oldValue {
                refreshMerchantSuggestions(resetSelection: false)
            }
        }
    }

    /// After picking a merchant, collapse the field until the user taps to edit again.
    @Published public var isMerchantFieldExpanded = true
    private var skipMerchantSuggestionRefresh = false

    @Published public var amountString = "" {
        didSet { refreshEnvelopeWarning() }
    }
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
    /// Optional store link when logging income (Amazon refund, employer portal, etc.).
    @Published public var optionalStoreName = ""
    @Published var incomeStoreCandidates: [MerchantCandidate] = []
    @Published public var showIncomeStorePickSheet = false
    @Published public var saveError: String?
    @Published public var actionNotice: String?
    @Published public var smartHint: String?
    @Published public var categorySuggestionNotice: String?
    @Published public var envelopeWarning: String?
    @Published public var shouldAutoTriggerScanner = false

    @Published public var isSubscription = false
    @Published public var isRecurring = false
    @Published public var isExcludedFromSpending = false
    @Published public var isTrial = false
    @Published public var subscriptionStartDate = Date()
    @Published public var trialEndDate = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    @Published public var renewalReminderDays = 3
    @Published public var emotionTag = ""
    @Published public var selectedHustleId: UUID? = nil
    @Published public var bridgeEntryMode: SynergyBridgeEntryMode = .standard
    @Published public var bridgeSecondaryHustleId: UUID?
    @Published public var bridgeSplitSharePercent: Double = 50
    @Published public var paymentMethod: String? = nil
    @Published public var isCategorySplitEnabled = false
    @Published public var categorySplitDraftLines: [ExpenseCategorySplitLine] = []
    @Published public var categorySplitValidationMessage: String?
    @Published var householdScope: HouseholdScope = .personal
    // MARK: - Barter Logger Fields
    @Published public var isBarterExchange: Bool = false
    @Published public var barterGoodsGiven: String = ""
    @Published public var barterGoodsReceived: String = ""
    @Published public var barterEstimatedValue: String = ""

    private var categoryBeforeSubscription: TransactionCategory?
    private var categoryIdBeforeSubscription: UUID?

    public var isEditing: Bool { editingId != nil }

    public var isHouseholdActive: Bool {
        SettingsStore.shared.householdCloudRecordName != nil
    }

    public var showsWorkspaceBridgeSplit: Bool {
        SettingsStore.shared.sideHustleMatrixEnabled && bridgeEntryMode == .split
    }

    public var showsCategorySplitEditor: Bool {
        !isIncomeEntry && !showsWorkspaceBridgeSplit
    }

    public var workspaceAutoRoutePreviewName: String? {
        guard SettingsStore.shared.sideHustleMatrixEnabled,
              !isEditing,
              bridgeEntryMode == .standard,
              selectedHustleId == nil else { return nil }
        let merchant = merchantName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !merchant.isEmpty else { return nil }
        guard let id = HustleManager.shared.routeHustleId(
            merchantName: merchant,
            notes: notes.isEmpty ? nil : notes,
            paymentMethod: paymentMethod
        ) else { return nil }
        return HustleManager.shared.hustles.first(where: { $0.id == id })?.name
    }
    /// Logging income (Home → Log income), not an outflow expense.
    public let isIncomeEntry: Bool

    public var isSubscriptionsCategorySelected: Bool {
        selectedCategory == .subscriptions
    }

    public var needsDisambiguatorLabel: Bool {
        brain.merchantBrain.needsDisambiguatorLabel(
            for: merchantName,
            disambiguator: merchantDisambiguator.isEmpty ? nil : merchantDisambiguator
        )
    }

    public init(
        brain: BuxMuseBrain,
        settingsManager: AppSettingsManager,
        editing: Transaction? = nil,
        presetCategory: TransactionCategory? = nil,
        autoScan: Bool = false,
        focusCategorySplit: Bool = false
    ) {
        self.brain = brain
        self.settingsManager = settingsManager
        self.editingId = editing?.id
        self.isIncomeEntry = presetCategory == .income
            || (editing?.category == .income)
        self.shouldAutoTriggerScanner = autoScan

        if let tx = editing {
            merchantName = tx.merchantName
            selectedCategory = tx.category
            date = tx.date
            notes = tx.notes ?? ""
            let absAmount = abs(tx.amount.value)
            amountString = String(format: "%.2f", NSDecimalNumber(decimal: absAmount).doubleValue)
            selectedHustleId = tx.hustleId
            paymentMethod = tx.paymentMethod
            isBarterExchange = tx.isBarterExchange
            barterGoodsGiven = tx.barterGoodsGiven ?? ""
            barterGoodsReceived = tx.barterGoodsReceived ?? ""
            barterEstimatedValue = tx.barterEstimatedValue.map { String(format: "%.2f", NSDecimalNumber(decimal: $0).doubleValue) } ?? ""
            if let record = try? brain.fetchExpenseRecord(id: tx.id) {
                selectedCategoryId = record.categoryId
                selectedMerchantId = record.merchantId
                isSubscription = record.isSubscriptionLike
                isRecurring = record.isRecurring && (record.recurrenceConfidence ?? 0) >= 0.85
                isTrial = record.isTrial
                if let start = record.subscriptionStartDate { subscriptionStartDate = start }
                if let end = record.trialEndDate { trialEndDate = end }
                renewalReminderDays = record.renewalReminderDays ?? 3
                emotionTag = record.emotion ?? ""
                paymentMethod = record.paymentMethod
                if record.isCategorySplit, !record.splitLines.isEmpty {
                    isCategorySplitEnabled = true
                    categorySplitDraftLines = record.splitLines.map { ExpenseCategorySplitLine.from($0) }
                }
                householdScope = record.householdScope
                isExcludedFromSpending = record.isExcludedFromSpending
            }
        } else if let preset = presetCategory {
            selectedCategory = preset
            selectedCategoryId = try? brain.categoryId(for: preset)
            selectedHustleId = SettingsStore.shared.sideHustleMatrixEnabled
                ? HustleManager.shared.selectedHustleId
                : nil
        } else {
            selectedCategoryId = try? brain.categoryId(for: .other)
            selectedHustleId = SettingsStore.shared.sideHustleMatrixEnabled
                ? HustleManager.shared.selectedHustleId
                : nil
        }

        if paymentMethod?.isEmpty == true {
            paymentMethod = nil
        }

        if isIncomeEntry {
            refreshOptionalStoreSuggestions(resetSelection: true)
        } else {
            refreshMerchantSuggestions(resetSelection: true)
            let hasMerchant = !merchantName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            isMerchantFieldExpanded = !(hasMerchant && editing != nil)
            if selectedCategory == .subscriptions {
                categorySelectionDidChange()
            } else if isSubscription {
                syncSubscriptionStartFromExpenseDate()
            }
        }

        if focusCategorySplit, !isIncomeEntry {
            isCategorySplitEnabled = true
            if categorySplitDraftLines.count < 2 {
                let groceriesId = try? brain.categoryId(for: .groceries)
                let otherId = try? brain.categoryId(for: .other)
                categorySplitDraftLines = [
                    ExpenseCategorySplitLine(
                        categoryId: selectedCategoryId ?? groceriesId,
                        categoryRaw: selectedCategory.rawValue
                    ),
                    ExpenseCategorySplitLine(categoryId: otherId, categoryRaw: TransactionCategory.other.rawValue)
                ]
            }
        }
    }

    public func categorySelectionDidChange() {
        guard !isIncomeEntry else { return }
        categorySuggestionNotice = nil
        if isCategorySplitEnabled { return }
        if selectedCategory == .subscriptions {
            isSubscription = true
            syncSubscriptionStartFromExpenseDate()
        } else if isSubscription {
            isSubscription = false
            isTrial = false
        }
        refreshEnvelopeWarning()
    }

    public func refreshEnvelopeWarning() {
        guard !isIncomeEntry else {
            envelopeWarning = nil
            return
        }
        let store = SettingsStore.shared
        guard store.showBudgetWarnings else {
            envelopeWarning = nil
            return
        }
        let cleaned = amountString.replacingOccurrences(of: ",", with: ".")
        guard let amount = Decimal(string: cleaned), amount > 0 else {
            envelopeWarning = nil
            return
        }

        let categoryRecords = (try? brain.fetchAllCategoryRecords()) ?? []
        let period = BuxBudgetPeriodCalculator.currentPeriod(
            configuration: .fromSettings,
            calendar: {
                var cal = Calendar.current
                cal.firstWeekday = store.weekStartDay.calendarWeekday
                return cal
            }()
        )
        let records = (try? brain.fetchAllExpenseRecords()) ?? []

        switch store.budgetingMode {
        case .envelope:
            refreshEnvelopeCategoryWarning(
                amount: amount,
                categoryRecords: categoryRecords,
                records: records,
                period: period,
                store: store
            )
        case .simple, .custom:
            let preview = ExpenseRecord(
                name: merchantName,
                amountValue: -amount,
                currencyCode: settingsManager.selectedCurrency.id,
                categoryId: selectedCategoryId,
                date: date,
                categoryRaw: selectedCategory.rawValue,
                merchantName: merchantName
            )
            let isEssential = BudgetPeriodEngine.isEssentialLivingExpense(
                preview,
                categoryRecords: categoryRecords
            )
            if let result = BudgetPeriodEngine.projectedStandardBudgetWarning(
                records: records,
                fundingSource: store.incomeFundingSource,
                period: period,
                spendingCap: brain.resolvedStandardSpendingCap(),
                categoryRecords: categoryRecords,
                additionalAmount: amount,
                additionalIsEssential: isEssential,
                supplementalEarned: brain.resolvedStandardStudioIncomeSupplement(period: period, records: records),
                approachingThresholdPercent: store.budgetApproachingThresholdPercent,
                locale: locale
            ) {
                envelopeWarning = BuxLocalizedString.string(result.messageKey, locale: locale)
            } else {
                envelopeWarning = nil
            }
        }
    }

    private func refreshEnvelopeCategoryWarning(
        amount: Decimal,
        categoryRecords: [ExpenseCategoryRecord],
        records: [ExpenseRecord],
        period: DateInterval,
        store: SettingsStore
    ) {
        guard let profile = store.customBudgetProfiles.first(where: { $0.isActive }) else {
            envelopeWarning = nil
            return
        }
        let preview = ExpenseRecord(
            name: merchantName,
            amountValue: -amount,
            currencyCode: settingsManager.selectedCurrency.id,
            categoryId: selectedCategoryId,
            date: date,
            categoryRaw: selectedCategory.rawValue,
            merchantName: merchantName
        )
        guard let envelope = profile.categories.first(where: {
            BudgetEnvelopeEngine.recordMatchesEnvelope(
                preview,
                envelope: $0,
                categoryRecords: categoryRecords,
                locale: locale
            )
        }) else {
            envelopeWarning = nil
            return
        }
        if let result = BudgetEnvelopeEngine.projectedEnvelopeStatus(
            envelope: envelope,
            profile: profile,
            records: records,
            categoryRecords: categoryRecords,
            period: period,
            additionalAmount: amount,
            locale: locale
        ) {
            envelopeWarning = BuxLocalizedString.format(
                result.messageKey,
                locale: locale,
                envelope.name
            )
        } else {
            envelopeWarning = nil
        }
    }

    public func expenseDateDidChange() {
        guard isSubscription else { return }
        syncSubscriptionStartFromExpenseDate()
    }

    private func syncSubscriptionStartFromExpenseDate() {
        guard isSubscription, !isTrial else { return }
        subscriptionStartDate = date
    }

    public func prefillFromScan(merchant: String, amount: Decimal, date: Date, details: String?) {
        let absAmount = abs(amount)
        self.amountString = String(format: "%.2f", NSDecimalNumber(decimal: absAmount).doubleValue)
        self.merchantName = merchant
        self.date = date
        if let details = details, !details.isEmpty {
            self.notes = details
        }
        refreshMerchantSuggestions(resetSelection: true)
        expenseDateDidChange()
    }

    public func expandMerchantFieldForEditing() {
        isMerchantFieldExpanded = true
    }

    public func collapseMerchantFieldAfterSelection() {
        isMerchantFieldExpanded = false
        candidates = []
        mergeHintCandidate = nil
    }

    public func refreshOptionalStoreSuggestions(resetSelection: Bool) {
        candidates = []
        mergeHintCandidate = nil
        smartHint = nil

        let clean = optionalStoreName.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.isEmpty {
            incomeStoreCandidates = []
            if resetSelection {
                clearOptionalStoreLink()
            }
            return
        }

        let records = (try? brain.fetchAllExpenseRecords()) ?? []
        incomeStoreCandidates = brain.merchantBrain.candidates(for: clean, expenseRecords: records, locale: locale)

        if resetSelection {
            selectedCandidateId = nil
            pendingMerchantSelection = nil
            selectedMerchantId = nil
        }
    }

    public func clearOptionalStoreLink() {
        optionalStoreName = ""
        incomeStoreCandidates = []
        selectedMerchantId = nil
        selectedCandidateId = nil
        pendingMerchantSelection = nil
    }

    func selectOptionalStoreCandidate(_ candidate: MerchantCandidate) {
        optionalStoreName = candidate.historyLabel ?? candidate.displayName
        selectedCandidateId = candidate.id
        selectedMerchantId = candidate.merchantId
        pendingMerchantSelection = brain.merchantBrain.selection(from: candidate)
        incomeStoreCandidates = []
        showIncomeStorePickSheet = false
    }

    public func refreshMerchantSuggestions(resetSelection: Bool) {
        if isIncomeEntry { return }

        let records = (try? brain.fetchAllExpenseRecords()) ?? []
        let cleanName = merchantName.trimmingCharacters(in: .whitespacesAndNewlines)

        if cleanName.isEmpty {
            candidates = []
            mergeHintCandidate = nil
            categorySuggestionNotice = nil
            if resetSelection {
                selectedCandidateId = nil
            }
            return
        }

        let next = brain.merchantBrain.candidates(for: cleanName, expenseRecords: records, locale: locale)
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
        skipMerchantSuggestionRefresh = true
        merchantName = candidate.historyLabel ?? candidate.displayName
        skipMerchantSuggestionRefresh = false
        selectedCandidateId = candidate.id
        selectedMerchantId = candidate.merchantId
        var selection = brain.merchantBrain.selection(from: candidate)
        let trimmedLabel = merchantDisambiguator.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedLabel.isEmpty {
            selection.disambiguator = trimmedLabel
        }
        pendingMerchantSelection = selection
        showMerchantPickSheet = false
        collapseMerchantFieldAfterSelection()

        if candidate.matchKind != .newMerchant {
            applySmartDefaults(for: candidate)
        }
    }

    public func applyMergeHint() {
        guard let hint = mergeHintCandidate else { return }
        selectCandidate(hint)
    }

    public func convertToSubscription() {
        guard let editingId else { return }
        saveError = nil
        actionNotice = nil
        do {
            if isSubscription {
                let restoreCategory = categoryBeforeSubscription ?? (selectedCategory == .subscriptions ? .other : selectedCategory)
                let restoreCategoryId = categoryIdBeforeSubscription ?? (try? brain.categoryId(for: restoreCategory))
                try brain.clearExpenseSubscription(
                    id: editingId,
                    restoreCategory: restoreCategory,
                    categoryId: restoreCategoryId
                )
                categoryBeforeSubscription = nil
                categoryIdBeforeSubscription = nil
                reloadEditingRecord()
                actionNotice = loc("Subscription removed.")
            } else {
                categoryBeforeSubscription = selectedCategory
                categoryIdBeforeSubscription = selectedCategoryId
                try brain.convertExpenseToSubscription(id: editingId)
                reloadEditingRecord()
                actionNotice = loc("Converted to subscription. Start date uses the expense date.")
            }
        } catch {
            saveError = isSubscription ? loc("Could not remove subscription.") : loc("Could not convert to subscription.")
        }
    }

    public func markRecurring(type: String = "monthly") {
        guard let editingId else { return }
        saveError = nil
        actionNotice = nil
        do {
            if isRecurring {
                try brain.unmarkExpenseRecurring(id: editingId)
                reloadEditingRecord()
                actionNotice = loc("Recurring removed.")
            } else {
                try brain.markExpenseRecurring(id: editingId, type: type)
                reloadEditingRecord()
                actionNotice = loc("Marked as recurring monthly. Expense date stays the same.")
            }
        } catch {
            saveError = isRecurring ? loc("Could not remove recurring.") : loc("Could not mark as recurring.")
        }
    }

    func expenseSnapshotForUndo() -> ExpenseRecord? {
        guard let editingId else { return nil }
        return try? brain.fetchExpenseRecord(id: editingId)
    }

    func restoreDeletedExpense(_ record: ExpenseRecord) {
        saveError = nil
        do {
            try brain.restoreExpenseRecord(record)
        } catch {
            saveError = loc("Could not restore expense.")
        }
    }

    public func deleteExpense() throws {
        guard let editingId else { return }
        if let record = try? brain.fetchExpenseRecord(id: editingId) {
            if let pm = record.paymentMethod {
                let store = SettingsStore.shared
                let doubleAmt = NSDecimalNumber(decimal: record.amountValue).doubleValue
                if pm == "Cash (\(store.primaryLocalCurrency))" {
                    store.cashLocalBalanceValue -= doubleAmt
                } else if pm == "Cash (\(store.secondaryTradingCurrency))" {
                    store.cashSecondaryBalanceValue -= doubleAmt
                }
            }
        }
        try brain.deleteExpense(id: editingId)
    }

    public func saveTransaction() -> Bool {
        saveError = nil
        let cleanName = merchantName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else {
            saveError = isIncomeEntry
                ? BuxCatalogLabel.string("Add a short label for this income.", locale: settingsManager.interfaceLocale)
                : BuxCatalogLabel.string("Enter a merchant name.", locale: settingsManager.interfaceLocale)
            return false
        }

        if isIncomeEntry {
            let storeQuery = optionalStoreName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !storeQuery.isEmpty {
                let pickCandidates = incomeStoreCandidates.isEmpty
                    ? brain.merchantBrain.candidates(for: storeQuery, expenseRecords: (try? brain.fetchAllExpenseRecords()) ?? [], locale: locale)
                    : incomeStoreCandidates
                let mustPick = brain.merchantBrain.isAmbiguous(
                    query: storeQuery,
                    candidates: pickCandidates,
                    selectedCandidateId: selectedCandidateId,
                    selectedMerchantId: selectedMerchantId
                ) || (
                    selectedCandidateId == nil
                        && selectedMerchantId == nil
                        && brain.merchantBrain.shouldOfferExplicitPick(for: storeQuery, candidates: pickCandidates)
                )
                if mustPick {
                    incomeStoreCandidates = pickCandidates
                    showIncomeStorePickSheet = true
                    saveError = loc("Choose which store to link (optional).")
                    return false
                }
            }
        } else {
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
                saveError = loc("Choose which merchant name to use.")
                return false
            }
        }

        if isSubscription && isTrial && trialEndDate <= Date() {
            saveError = loc("Trial end date must be in the future.")
            return false
        }

        if isCategorySplitEnabled {
            guard validateCategorySplitDraft() else { return false }
        }

        let cleanedAmountStr = amountString.replacingOccurrences(of: ",", with: ".")
        guard let doubleVal = Double(cleanedAmountStr) else {
            saveError = loc("Enter a valid amount.")
            return false
        }
        let decimalValue = Decimal(doubleVal)
        let treatsAsIncome = isIncomeEntry || selectedCategory == .income
        let finalValue = treatsAsIncome ? abs(decimalValue) : -abs(decimalValue)
        let amount = MoneyAmount(value: finalValue, currencyCode: resolvedCurrencyCodeForSave())

        // Adjust Cash Drawer Balances if needed
        let oldRecord = editingId.flatMap { try? brain.fetchExpenseRecord(id: $0) }
        let oldPaymentMethod = oldRecord?.paymentMethod
        
        if paymentMethod != oldPaymentMethod {
            let store = SettingsStore.shared
            // Reverse old cash transaction if any
            if let oldPm = oldPaymentMethod, let oldAmt = oldRecord?.amountValue {
                let doubleAmt = NSDecimalNumber(decimal: oldAmt).doubleValue
                if oldPm == "Cash (\(store.primaryLocalCurrency))" {
                    store.cashLocalBalanceValue -= doubleAmt
                } else if oldPm == "Cash (\(store.secondaryTradingCurrency))" {
                    store.cashSecondaryBalanceValue -= doubleAmt
                }
            }
            // Apply new cash transaction
            if let newPm = paymentMethod {
                let doubleAmt = NSDecimalNumber(decimal: finalValue).doubleValue
                if newPm == "Cash (\(store.primaryLocalCurrency))" {
                    store.cashLocalBalanceValue += doubleAmt
                } else if newPm == "Cash (\(store.secondaryTradingCurrency))" {
                    store.cashSecondaryBalanceValue += doubleAmt
                }
            }
        } else if oldRecord != nil, let oldAmt = oldRecord?.amountValue, oldAmt != finalValue {
            // Same cash payment method but amount changed
            let store = SettingsStore.shared
            if let pm = paymentMethod {
                let diff = NSDecimalNumber(decimal: finalValue - oldAmt).doubleValue
                if pm == "Cash (\(store.primaryLocalCurrency))" {
                    store.cashLocalBalanceValue += diff
                } else if pm == "Cash (\(store.secondaryTradingCurrency))" {
                    store.cashSecondaryBalanceValue += diff
                }
            }
        }

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
            subscriptionStartDate: isSubscription && !isTrial ? date : nil,
            trialEndDate: isSubscription && isTrial ? trialEndDate : nil,
            renewalReminderDays: isSubscription ? renewalReminderDays : nil,
            categoryRaw: isSubscription ? TransactionCategory.subscriptions.rawValue : selectedCategory.rawValue,
            merchantName: persistedMerchantNameField(label: cleanName),
            hustleId: resolvedHustleIdForSave(),
            paymentMethod: normalizedPaymentMethod(),
            isBarterExchange: isBarterExchange,
            barterGoodsGiven: isBarterExchange && !barterGoodsGiven.isEmpty ? barterGoodsGiven : nil,
            barterGoodsReceived: isBarterExchange && !barterGoodsReceived.isEmpty ? barterGoodsReceived : nil,
            barterEstimatedValue: isBarterExchange ? Decimal(Double(barterEstimatedValue) ?? 0) : nil
        )

        if let editingId, let existing = try? brain.fetchExpenseRecord(id: editingId) {
            record.merchantId = selectedMerchantId ?? (isIncomeEntry ? nil : existing.merchantId)
            record.createdAt = existing.createdAt
            record.financeKitTransactionId = existing.financeKitTransactionId
            record.walletAccountId = existing.walletAccountId
            record.walletIsPending = existing.walletIsPending
            record.walletCategoryUserConfirmed = existing.walletCategoryUserConfirmed
            record.walletCategoryConfidence = existing.walletCategoryConfidence
            if record.incomeRole == nil {
                record.incomeRole = existing.incomeRole
            }
        }

        record.isExcludedFromSpending = !treatsAsIncome && isExcludedFromSpending

        record.emotion = emotionTag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : emotionTag

        if let categoryId = selectedCategoryId {
            record.categoryId = categoryId
        } else {
            record.categoryId = try? brain.categoryId(for: record.transactionCategory)
        }

        if treatsAsIncome,
           let pick = IncomeSourceQuickPick.matchingStoredLabel(cleanName, locale: locale),
           pick == .salary || pick == .paycheck {
            record.incomeRole = SalaryPayrollMatcher.salaryRole
        }

        if isSubscription {
            record.nextExpectedDate = isTrial
                ? trialEndDate
                : Calendar.current.date(byAdding: .month, value: 1, to: date)
        }

        if isRecurring, !isSubscription {
            record.isRecurring = true
            record.recurrenceType = "monthly"
            record.recurrenceConfidence = 0.9
        }

        if isCategorySplitEnabled {
            let drafts = normalizedCategorySplitLines()
            record.isCategorySplit = true
            record.splitLines = drafts.enumerated().compactMap { index, line in
                line.toSplitLineRecord(sortOrder: index)
            }
            if let primary = record.splitLines.first {
                record.categoryId = primary.categoryId
                record.categoryRaw = primary.categoryRaw
                selectedCategory = primary.transactionCategory
                selectedCategoryId = primary.categoryId
            }
        } else {
            record.isCategorySplit = false
            record.splitLines = []
        }

        if isHouseholdActive {
            record.householdScope = householdScope
        }

        let selection: MerchantSelection? = {
            if isIncomeEntry {
                guard selectedMerchantId != nil || pendingMerchantSelection != nil else { return nil }
                return buildIncomeStoreSelection()
            }
            return buildMerchantSelection(for: cleanName)
        }()

        do {
            if !isEditing,
               SettingsStore.shared.sideHustleMatrixEnabled,
               bridgeEntryMode != .standard {
                try saveBridgeTransaction(record: record, selection: selection, cleanName: cleanName, amount: decimalValue)
            } else {
                _ = try brain.saveExpenseRecord(record, merchantSelection: selection)
            }
            if record.householdScope == .shared {
                Task { await HouseholdSyncEngine.shared.pushSharedExpenseIfNeeded(record) }
            }
            return true
        } catch is BridgeSaveError {
            return false
        } catch {
            saveError = loc("Could not save. Try again.")
            print("Expense save failed: \(error)")
            return false
        }
    }

    private func saveBridgeTransaction(
        record: ExpenseRecord,
        selection: MerchantSelection?,
        cleanName: String,
        amount: Decimal
    ) throws {
        switch bridgeEntryMode {
        case .standard:
            _ = try brain.saveExpenseRecord(record, merchantSelection: selection)
        case .split:
            guard !isIncomeEntry else {
                saveError = loc("Splits are only available for expenses.")
                throw BridgeSaveError.invalidMode
            }
            let primaryId = record.hustleId ?? HustleManager.shared.routeHustleId(
                merchantName: record.merchantName,
                notes: record.notes,
                paymentMethod: record.paymentMethod
            )
            guard let primaryId,
                  let secondaryId = bridgeSecondaryHustleId,
                  primaryId != secondaryId else {
                saveError = loc("Choose two different workspaces for a split.")
                throw BridgeSaveError.missingWorkspaces
            }
            let pair = SynergyBridgeEngine.makeSplitPair(
                base: record,
                primaryHustleId: primaryId,
                secondaryHustleId: secondaryId,
                secondarySharePercent: bridgeSplitSharePercent
            )
            _ = try brain.saveBridgeRecords(pair, merchantSelection: selection)
        case .dividendTransfer:
            guard let sourceId = selectedHustleId,
                  let targetId = bridgeSecondaryHustleId,
                  sourceId != targetId else {
                saveError = loc("Choose source and target workspaces for the transfer.")
                throw BridgeSaveError.missingWorkspaces
            }
            let pair = SynergyBridgeEngine.makeDividendTransferPair(
                amount: amount,
                currencyCode: record.currencyCode,
                date: record.date,
                label: cleanName,
                sourceHustleId: sourceId,
                targetHustleId: targetId,
                notes: record.notes
            )
            _ = try brain.saveBridgeRecords(pair)
        }
    }

    private enum BridgeSaveError: Error {
        case invalidMode
        case missingWorkspaces
    }

    public func validateCategorySplitDraft() -> Bool {
        categorySplitValidationMessage = nil
        guard isCategorySplitEnabled else { return true }
        guard categorySplitDraftLines.count >= 2, categorySplitDraftLines.count <= 5 else {
            categorySplitValidationMessage = loc("Use 2 to 5 category lines.")
            saveError = categorySplitValidationMessage
            return false
        }
        let amounts = categorySplitDraftLines.compactMap(\.amountDecimal)
        guard amounts.count == categorySplitDraftLines.count else {
            categorySplitValidationMessage = loc("Enter a valid amount for each line.")
            saveError = categorySplitValidationMessage
            return false
        }
        let cleanedAmountStr = amountString.replacingOccurrences(of: ",", with: ".")
        guard let total = Decimal(string: cleanedAmountStr), total > 0 else {
            categorySplitValidationMessage = loc("Enter a valid amount.")
            saveError = categorySplitValidationMessage
            return false
        }
        let allocated = amounts.reduce(0, +)
        let delta = abs(NSDecimalNumber(decimal: total - allocated).doubleValue)
        guard delta < 0.01 else {
            categorySplitValidationMessage = loc("Split amounts must equal the expense total.")
            saveError = categorySplitValidationMessage
            return false
        }
        return true
    }

    private func normalizedCategorySplitLines() -> [ExpenseCategorySplitLine] {
        categorySplitDraftLines.map { line in
            var normalized = line
            if normalized.categoryId == nil {
                normalized.categoryId = try? brain.categoryId(for: normalized.transactionCategory)
            }
            return normalized
        }
    }

    // MARK: - Private

    private func normalizedPaymentMethod() -> String? {
        guard let paymentMethod else { return nil }
        let trimmed = paymentMethod.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func resolvedHustleIdForSave() -> UUID? {
        guard SettingsStore.shared.sideHustleMatrixEnabled else {
            if let editingId, let record = try? brain.fetchExpenseRecord(id: editingId) {
                return record.hustleId
            }
            return nil
        }
        return selectedHustleId
    }

    private func resolvedCurrencyCodeForSave() -> String {
        if let editingId, let record = try? brain.fetchExpenseRecord(id: editingId) {
            return record.currencyCode
        }
        return WorkspaceCurrencyContext.activeDisplayCurrency(global: settingsManager.selectedCurrency).id
    }

    private func reloadEditingRecord() {
        guard let editingId, let record = try? brain.fetchExpenseRecord(id: editingId) else { return }
        merchantName = record.name
        selectedCategory = record.transactionCategory
        selectedCategoryId = record.categoryId
        selectedMerchantId = record.merchantId
        if isIncomeEntry, record.merchantId != nil {
            let merchants = (try? brain.fetchAllMerchantRecords()) ?? []
            optionalStoreName = merchants.first(where: { $0.id == record.merchantId })?.name ?? ""
        }
        date = record.date
        notes = record.notes ?? ""
        let absAmount = abs(record.amountValue)
        amountString = String(format: "%.2f", NSDecimalNumber(decimal: absAmount).doubleValue)
        isSubscription = record.isSubscriptionLike
        paymentMethod = record.paymentMethod
        isRecurring = record.isRecurring && (record.recurrenceConfidence ?? 0) >= 0.85
        isTrial = record.isTrial
        if let start = record.subscriptionStartDate { subscriptionStartDate = start }
        if let end = record.trialEndDate { trialEndDate = end }
        renewalReminderDays = record.renewalReminderDays ?? 3
        emotionTag = record.emotion ?? ""
        if selectedCategory == .subscriptions {
            isSubscription = true
            syncSubscriptionStartFromExpenseDate()
        } else if isSubscription {
            syncSubscriptionStartFromExpenseDate()
        }
        if record.isCategorySplit, !record.splitLines.isEmpty {
            isCategorySplitEnabled = true
            categorySplitDraftLines = record.splitLines.map { ExpenseCategorySplitLine.from($0) }
        } else {
            isCategorySplitEnabled = false
            categorySplitDraftLines = []
        }
        householdScope = record.householdScope
    }

    /// `name` stays the user label; `merchantName` holds the linked store brand for logos when applicable.
    private func persistedMerchantNameField(label: String) -> String {
        guard isIncomeEntry, selectedMerchantId != nil else { return label }
        let store = optionalStoreName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !store.isEmpty { return store }
        if let id = selectedMerchantId,
           let merchant = try? brain.fetchMerchantRecord(id: id) {
            return merchant.name
        }
        return label
    }

    private func buildIncomeStoreSelection() -> MerchantSelection? {
        if let selection = pendingMerchantSelection {
            return selection
        }
        if let selectedMerchantId,
           let merchant = try? brain.fetchMerchantRecord(id: selectedMerchantId),
           !merchant.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return MerchantSelection(
                merchantId: merchant.id,
                displayName: merchant.name,
                disambiguator: merchant.disambiguator.isEmpty ? nil : merchant.disambiguator,
                createNew: false
            )
        }
        let store = optionalStoreName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !store.isEmpty else { return nil }
        if let selectedMerchantId,
           let merchant = try? brain.fetchMerchantRecord(id: selectedMerchantId) {
            return MerchantSelection(
                merchantId: merchant.id,
                displayName: merchant.name,
                disambiguator: merchant.disambiguator.isEmpty ? nil : merchant.disambiguator,
                createNew: false
            )
        }
        return MerchantSelection(displayName: store, createNew: false, historyLabel: store)
    }

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
           let merchant = try? brain.fetchMerchantRecord(id: selectedMerchantId) {
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
        let records = (try? brain.fetchAllExpenseRecords()) ?? []

        if let suggestion = brain.merchantBrain.suggestedCategory(
            for: label,
            merchantId: candidate.merchantId,
            expenseRecords: records
        ) {
            selectedCategory = suggestion.category
            selectedCategoryId = try? brain.categoryId(for: suggestion.category)
            categorySuggestionNotice = loc("Suggested from past visits")
        } else {
            categorySuggestionNotice = nil
        }

        let pastTx = brain.financialEngine.allTransactions()
        let matches = pastTx.filter {
            MerchantLogoEngine.normalizeMerchantName($0.merchantName)
                == MerchantLogoEngine.normalizeMerchantName(label)
        }
        guard !matches.isEmpty else { return }

        let amounts = Set(matches.map { $0.amount.value })
        if amounts.count == 1, let recurringAmount = amounts.first, amountString.isEmpty {
            let absAmount = abs(recurringAmount)
            amountString = String(format: "%.2f", NSDecimalNumber(decimal: absAmount).doubleValue)
        }
        if let note = matches.compactMap(\.notes).first(where: { !$0.isEmpty }), notes.isEmpty {
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
        let categoryRecords = (try? brain.fetchAllCategoryRecords()) ?? []
        let categoriesById = Dictionary(uniqueKeysWithValues: categoryRecords.map { ($0.id, $0) })
        let analysis = ExpenseIntelligenceEngine.analyze(
            record: preview,
            allRecords: records,
            activeSubscriptions: brain.financialEngine.activeSubscriptions(),
            categoriesById: categoriesById,
            locale: settingsManager.interfaceLocale
        )
        var hints: [String] = []
        if let recurrence = analysis.display.recurrenceSummary { hints.append(recurrence) }
        if let sub = analysis.display.subscriptionSummary { hints.append(sub) }
        smartHint = hints.isEmpty ? nil : hints.joined(separator: " · ")
    }

    deinit {
        // Stabilize object lifecycle for unit tests deallocation
    }
}
