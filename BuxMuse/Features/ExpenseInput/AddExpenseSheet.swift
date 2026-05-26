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
    @State private var saveButtonPop = false

    let mode: ExpenseSheetMode

    var cardColor: Color {
        themeManager.cardFill(for: colorScheme)
    }

    init(brain: BuxMuseBrain, settingsManager: AppSettingsManager, mode: ExpenseSheetMode) {
        self.mode = mode
        let editing: Transaction? = {
            if case .edit(let tx) = mode { return tx }
            return nil
        }()
        _viewModel = StateObject(wrappedValue: AddExpenseViewModel(
            brain: brain,
            settingsManager: settingsManager,
            editing: editing
        ))
    }

    var body: some View {
        ZStack {
            themeManager.screenBackground(for: colorScheme)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Button(action: { dismiss() }) {
                        Text("Cancel")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(BuxMicroShrinkStyle())

                    Spacer()

                    Text(viewModel.isEditing ? "Edit Expense" : "Add Expense")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(colorScheme == .dark ? .white : Color(red: 26/255, green: 28/255, blue: 32/255))

                    Spacer()

                    Text("Cancel")
                        .font(.system(size: 16, weight: .medium))
                        .opacity(0)
                }
                .padding(.horizontal, BuxLayout.marginHorizontal)
                .padding(.vertical, 16)

                Divider().opacity(0.08)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        AmountField(amountString: $viewModel.amountString)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("MERCHANT")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(colorScheme == .dark ? .white.opacity(0.4) : Color(red: 140/255, green: 145/255, blue: 160/255))
                                .kerning(1.2)

                            ZStack(alignment: .topTrailing) {
                                HStack(spacing: 12) {
                                    if !viewModel.merchantName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                        AsyncMerchantLogoView(merchantName: viewModel.merchantName, size: 28)
                                    } else {
                                        Image(systemName: "building.2.crop.circle")
                                            .foregroundColor(themeManager.current.accentColor)
                                            .font(.system(size: 20))
                                    }

                                    TextField("Enter merchant name", text: $viewModel.merchantName)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(colorScheme == .dark ? .white : Color(red: 26/255, green: 28/255, blue: 32/255))
                                        .tint(themeManager.current.accentColor)
                                        .autocapitalization(.words)
                                        .disableAutocorrection(true)
                                }
                                .padding(.horizontal, BuxLayout.marginHorizontal)
                                .padding(.vertical, 16)
                                .background(cardColor)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(colorScheme == .dark ? Color.white.opacity(0.04) : Color.black.opacity(0.03), lineWidth: 1)
                                )
                            }

                            if !viewModel.suggestions.isEmpty {
                                MerchantAutocompleteView(suggestions: viewModel.suggestions) { selected in
                                    withAnimation(.buxSnap) {
                                        viewModel.selectSuggestion(selected)
                                    }
                                }
                                .transition(.buxScaleReveal)
                            }
                        }

                        ExpenseCategoryPickerView(
                            selectedCategoryId: $viewModel.selectedCategoryId,
                            selectedCategory: $viewModel.selectedCategory
                        )
                        .environmentObject(brain)

                        ExpenseSubscriptionFieldsView(
                            isSubscription: $viewModel.isSubscription,
                            isTrial: $viewModel.isTrial,
                            subscriptionStartDate: $viewModel.subscriptionStartDate,
                            trialEndDate: $viewModel.trialEndDate,
                            renewalReminderDays: $viewModel.renewalReminderDays
                        )

                        DateFieldPicker(date: $viewModel.date)
                        NotesField(notes: $viewModel.notes)

                        if let hint = viewModel.smartHint {
                            Text(hint)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.gray)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        if let error = viewModel.saveError {
                            Text(error)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.red)
                                .transition(.opacity)
                        }
                    }
                    .padding(.horizontal, BuxLayout.marginHorizontal)
                    .padding(.top, 20)
                    .padding(.bottom, 120)
                }
            }

            VStack {
                Spacer()

                Button(action: {
                    let success = viewModel.saveTransaction()
                    if success {
                        withAnimation(.buxSnap) {
                            saveButtonPop = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            dismiss()
                        }
                    }
                }) {
                    Text(viewModel.isEditing ? "Update Transaction" : "Save Transaction")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(themeManager.current.accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: themeManager.current.accentColor.opacity(0.3), radius: 10, x: 0, y: 5)
                }
                .buttonStyle(BuxMicroShrinkStyle())
                .buxSuccessPop(isActive: saveButtonPop)
                .padding(.horizontal, BuxLayout.marginHorizontal)
                .padding(.bottom, 24)
            }
        }
    }
}
