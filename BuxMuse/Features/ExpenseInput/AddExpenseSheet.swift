//
//  AddExpenseSheet.swift
//  BuxMuse
//  Features/ExpenseInput/
//
//  Premium bottom sheet for entering expenses with predictive smart suggestions.
//

import SwiftUI

struct AddExpenseSheet: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var appSettingsManager: AppSettingsManager
    @EnvironmentObject var brain: BuxMuseBrain

    @StateObject private var viewModel: AddExpenseViewModel
    @State private var actionNoticeDismissTask: Task<Void, Never>?

    let mode: ExpenseSheetMode

    init(brain: BuxMuseBrain, settingsManager: AppSettingsManager, mode: ExpenseSheetMode) {
        self.mode = mode
        let editing: Transaction? = {
            if case .edit(let tx) = mode { return tx }
            return nil
        }()
        let preset: TransactionCategory? = {
            switch mode {
            case .addIncome: return .income
            default: return nil
            }
        }()
        _viewModel = StateObject(wrappedValue: AddExpenseViewModel(
            brain: brain,
            settingsManager: settingsManager,
            editing: editing,
            presetCategory: preset
        ))
    }

    private var sheetTitle: String {
        if viewModel.isEditing { return "Edit Expense" }
        return mode == .addIncome ? "Log Income" : "Add Expense"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.screenBackground(for: colorScheme).ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: BuxLayout.section) {
                        amountCard
                        merchantCard
                        categoryCard

                        if viewModel.isEditing {
                            editActionsSection
                        }

                        subscriptionCard
                        dateCard
                        notesCard
                        emotionalCard

                        if let hint = viewModel.smartHint {
                            Text(hint)
                                .font(.system(size: 13, weight: .medium))
                                .buxLabelSecondary()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(BuxLayout.section)
                                .expensesThemedCardChrome(cornerRadius: 20)
                        }

                        if let error = viewModel.saveError {
                            Text(error)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(BuxLayout.section)
                                .expensesThemedCardChrome(cornerRadius: 20)
                        }
                    }
                    .buxScreenContentMargins()
                    .padding(.top, BuxLayout.tight)
                    .padding(.bottom, 48)
                }
                .buxDetailScrollChrome()
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle(sheetTitle)
            .navigationBarTitleDisplayMode(.inline)
            .buxThemedSheetContent()
            .onDisappear {
                actionNoticeDismissTask?.cancel()
            }
            .onChange(of: viewModel.actionNotice) { _, notice in
                guard notice != nil else { return }
                actionNoticeDismissTask?.cancel()
                actionNoticeDismissTask = Task { @MainActor in
                    try? await Task.sleep(for: .seconds(3))
                    guard !Task.isCancelled else { return }
                    viewModel.actionNotice = nil
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    BuxToolbarCancelButton { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    BuxToolbarConfirmButton(
                        accessibilityLabel: viewModel.isEditing ? "Update" : "Save",
                        isEnabled: !viewModel.amountString.isEmpty
                            && !viewModel.merchantName.trimmingCharacters(in: .whitespaces).isEmpty
                    ) {
                        if viewModel.saveTransaction() {
                            dismiss()
                        }
                    }
                }
            }
            .sheet(isPresented: $viewModel.showMerchantPickSheet) {
                merchantPickSheet
                    .buxThemedSheetContent()
            }
            .overlay(alignment: .bottom) {
                if let notice = viewModel.actionNotice {
                    Text(notice)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(themeManager.cardFill(for: colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .shadow(color: .black.opacity(colorScheme == .dark ? 0.35 : 0.12), radius: 10, y: 3)
                        .padding(.horizontal, BuxLayout.marginHorizontal)
                        .padding(.bottom, 16)
                        .allowsHitTesting(false)
                }
            }
        }
    }

    private func deleteWithUndo() {
        guard let snapshot = viewModel.expenseSnapshotForUndo() else { return }
        do {
            try viewModel.deleteExpense()
            brain.offerExpenseUndo(snapshot)
            dismiss()
        } catch {
            viewModel.saveError = "Could not delete expense."
        }
    }

    private var editActionsSection: some View {
        VStack(spacing: 12) {
            editPrimaryAction(
                viewModel.isSubscription ? "Remove subscription" : "Convert to subscription",
                icon: viewModel.isSubscription ? "xmark.circle" : "arrow.triangle.2.circlepath"
            ) {
                viewModel.convertToSubscription()
            }
            editPrimaryAction(
                viewModel.isRecurring ? "Remove recurring" : "Mark as recurring",
                icon: viewModel.isRecurring ? "xmark.circle" : "calendar.badge.clock"
            ) {
                viewModel.markRecurring()
            }

            BuxButton(
                title: "Delete expense",
                systemImage: "trash.fill",
                role: .destructive,
                expands: true
            ) {
                deleteWithUndo()
            }
        }
        .transaction { $0.animation = nil }
    }

    private func editPrimaryAction(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.gray)
            }
            .foregroundColor(themeManager.labelPrimary(for: colorScheme))
            .padding(16)
            .expensesThemedCardChrome(cornerRadius: 18)
        }
        .buttonStyle(BuxMicroShrinkStyle())
    }

    // MARK: - Form sections

    private var amountCard: some View {
        AmountField(amountString: $viewModel.amountString)
            .environmentObject(themeManager)
            .environmentObject(appSettingsManager)
    }

    private var merchantCard: some View {
        VStack(alignment: .leading, spacing: BuxLayout.tight) {
            Text("Merchant")
                .buxSectionLabelStyle(color: themeManager.sectionHeaderColor(for: colorScheme))

            VStack(alignment: .leading, spacing: BuxLayout.tight) {
                HStack(spacing: 10) {
                    if !viewModel.merchantName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        AsyncMerchantLogoView(merchantName: viewModel.merchantName, size: 28)
                    }
                    TextField("Merchant name", text: $viewModel.merchantName)
                        .autocapitalization(.words)
                        .disableAutocorrection(true)
                }

                if let hint = viewModel.mergeHintCandidate,
                   viewModel.selectedCandidateId == nil,
                   viewModel.candidates.filter({ $0.matchKind != .newMerchant && $0.matchKind != .aliasVariant }).count <= 1 {
                    Button(action: { viewModel.applyMergeHint() }) {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 12, weight: .semibold))
                            Text("Use \(hint.displayName)?")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(themeManager.current.accentColor)
                    }
                    .buttonStyle(.plain)
                }

                if viewModel.needsDisambiguatorLabel {
                    TextField("Label (e.g. Food, Clothes)", text: $viewModel.merchantDisambiguator)
                        .font(.system(size: 14, weight: .medium))
                }

                if !viewModel.candidates.isEmpty {
                    MerchantAutocompleteView(candidates: viewModel.candidates) { candidate in
                        viewModel.selectCandidate(candidate)
                    }
                    .environmentObject(themeManager)
                }
            }
            .padding(BuxLayout.section)
            .expensesThemedCardChrome(cornerRadius: 20)
        }
    }

    private var categoryCard: some View {
        ExpenseCategoryPickerView(
            selectedCategoryId: $viewModel.selectedCategoryId,
            selectedCategory: $viewModel.selectedCategory,
            emphasizeOnAppear: mode == .addWithCategoryFocus,
            includesIncome: mode == .addIncome
        )
        .environmentObject(brain)
    }

    private var subscriptionCard: some View {
        VStack(alignment: .leading, spacing: BuxLayout.tight) {
            Text("Subscription")
                .buxSectionLabelStyle(color: themeManager.sectionHeaderColor(for: colorScheme))

            ExpenseSubscriptionFieldsView(
                isSubscription: $viewModel.isSubscription,
                isTrial: $viewModel.isTrial,
                subscriptionStartDate: $viewModel.subscriptionStartDate,
                trialEndDate: $viewModel.trialEndDate,
                renewalReminderDays: $viewModel.renewalReminderDays
            )
            .padding(BuxLayout.section)
            .expensesThemedCardChrome(cornerRadius: 20)
        }
    }

    private var dateCard: some View {
        VStack(alignment: .leading, spacing: BuxLayout.tight) {
            Text("Date")
                .buxSectionLabelStyle(color: themeManager.sectionHeaderColor(for: colorScheme))

            DatePicker("", selection: $viewModel.date, displayedComponents: .date)
                .labelsHidden()
                .tint(themeManager.current.accentColor)
                .padding(BuxLayout.section)
                .expensesThemedCardChrome(cornerRadius: 20)
        }
    }

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: BuxLayout.tight) {
            TextField("Notes (optional)", text: $viewModel.notes, axis: .vertical)
                .lineLimit(2...5)
        }
        .padding(BuxLayout.section)
        .expensesThemedCardChrome(cornerRadius: 20)
    }

    private var emotionalCard: some View {
        VStack(alignment: .leading, spacing: BuxLayout.tight) {
            Text("How did this feel?")
                .buxSectionLabelStyle(color: themeManager.sectionHeaderColor(for: colorScheme))

            EmotionalTagPickerView(selection: $viewModel.emotionTag)
                .environmentObject(themeManager)
                .padding(BuxLayout.section)
                .expensesThemedCardChrome(cornerRadius: 20)
        }
    }

    private var merchantPickSheet: some View {
        NavigationStack {
            List {
                ForEach(viewModel.candidates.filter { $0.matchKind != .newMerchant }) { candidate in
                    Button {
                        viewModel.selectCandidate(candidate)
                        viewModel.showMerchantPickSheet = false
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(candidate.displayName)
                                .font(.system(size: 16, weight: .semibold))
                            Text(candidate.subtitle)
                                .font(.system(size: 12, weight: .medium))
                                .buxLabelSecondary()
                        }
                    }
                }
            }
            .navigationTitle("Choose merchant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    BuxToolbarCancelButton { viewModel.showMerchantPickSheet = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
