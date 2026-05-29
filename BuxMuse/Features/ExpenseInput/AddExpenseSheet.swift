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
    /// Holds last mood id while the sheet background fades out.
    @State private var moodBackdropTag: String = ""
    @State private var moodBackdropOpacity: Double = 0

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

                BuxHeroMeshBackground()

                EmotionalTagAppearance.background(
                    for: moodBackdropTag,
                    colorScheme: colorScheme
                )
                .ignoresSafeArea()
                .opacity(moodBackdropOpacity)

                Form {
                    Section("Amount & Merchant") {
                        HStack {
                            Text(appSettingsManager.selectedCurrency.symbol)
                                .foregroundColor(themeManager.current.accentColor)
                                .font(.headline)
                            TextField("Amount", text: $viewModel.amountString)
                                .keyboardType(.decimalPad)
                                .font(.headline)
                        }
                        
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

                    Section("Category") {
                        ExpenseCategoryPickerView(
                            selectedCategoryId: $viewModel.selectedCategoryId,
                            selectedCategory: $viewModel.selectedCategory,
                            emphasizeOnAppear: mode == .addWithCategoryFocus
                        )
                        .environmentObject(brain)
                    }

                    Section("Subscription") {
                        ExpenseSubscriptionFieldsView(
                            isSubscription: $viewModel.isSubscription,
                            isTrial: $viewModel.isTrial,
                            subscriptionStartDate: $viewModel.subscriptionStartDate,
                            trialEndDate: $viewModel.trialEndDate,
                            renewalReminderDays: $viewModel.renewalReminderDays
                        )
                    }

                    Section("Date") {
                        DatePicker("Date", selection: $viewModel.date, displayedComponents: .date)
                            .datePickerStyle(.compact)
                    }

                    Section("Notes") {
                        TextField("Notes (optional)", text: $viewModel.notes)
                    }

                    Section("How did this feel?") {
                        EmotionalTagPickerView(selection: $viewModel.emotionTag)
                            .environmentObject(themeManager)
                    }

                    if let hint = viewModel.smartHint {
                        Section {
                            Text(hint)
                                .font(.system(size: 13, weight: .medium))
                                .buxLabelSecondary()
                        }
                    }

                    if let error = viewModel.saveError {
                        Section {
                            Text(error)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.red)
                                .transition(.opacity)
                        }
                    }
                }
                .buxThemedFormStyle()
                .buxScrollDismissesKeyboard()
            }
            .navigationTitle(sheetTitle)
            .navigationBarTitleDisplayMode(.inline)
            .buxThemedSheetContent()
            .onAppear {
                syncMoodBackdrop(to: viewModel.emotionTag, animated: false)
            }
            .onChange(of: viewModel.emotionTag) { _, newTag in
                syncMoodBackdrop(to: newTag, animated: true)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(viewModel.isEditing ? "Update" : "Save") {
                        if viewModel.saveTransaction() {
                            dismiss()
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(viewModel.amountString.isEmpty || viewModel.merchantName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .sheet(isPresented: $viewModel.showMerchantPickSheet) {
                merchantPickSheet
                    .buxThemedSheetContent()
            }
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
                    Button("Cancel") {
                        viewModel.showMerchantPickSheet = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func syncMoodBackdrop(to tag: String, animated: Bool) {
        let trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        let isActive = !trimmed.isEmpty

        if isActive {
            moodBackdropTag = trimmed
            if animated {
                withAnimation(BuxMotion.emotionFadeIn) {
                    moodBackdropOpacity = 1
                }
            } else {
                moodBackdropOpacity = 1
            }
            return
        }

        guard !moodBackdropTag.isEmpty || moodBackdropOpacity > 0.01 else { return }

        if animated {
            withAnimation(BuxMotion.emotionFadeOut) {
                moodBackdropOpacity = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + BuxMotion.emotionFadeOutDuration) {
                if viewModel.emotionTag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    moodBackdropTag = ""
                }
            }
        } else {
            moodBackdropOpacity = 0
            moodBackdropTag = ""
        }
    }
}
