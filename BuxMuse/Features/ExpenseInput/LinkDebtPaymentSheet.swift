//
//  LinkDebtPaymentSheet.swift
//  BuxMuse
//
//  Links an existing expense outflow as a consumer debt payment.
//

import SwiftUI

struct LinkDebtPaymentSheet: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @EnvironmentObject private var debtEngine: DebtEngine
    @EnvironmentObject private var brain: BuxMuseBrain

    let record: ExpenseRecord

    @State private var selectedDebtId: UUID?
    @State private var notes: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var activeDebts: [Debt] {
        debtEngine.activeDebts.filter { $0.currentBalance > 0 }
    }

    private var suggestions: [DebtPaymentSuggestion] {
        DebtPaymentMatcher.suggestions(for: record, debts: debtEngine.debts)
    }

    init(record: ExpenseRecord, debtEngine: DebtEngine) {
        self.record = record
        let suggested = DebtPaymentMatcher.bestMatch(for: record, debts: debtEngine.debts)?.id
            ?? debtEngine.activeDebts.first?.id
        _selectedDebtId = State(initialValue: suggested)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    transactionSummary

                    if !suggestions.isEmpty {
                        suggestionsSection
                    }

                    debtPickerSection

                    notesSection

                    Text(BuxLocalizedString.string(
                        "This logs a payment on the debt and keeps the expense in your ledger — linked on both sides.",
                        locale: appSettingsManager.interfaceLocale
                    ))
                    .font(.footnote)
                    .foregroundStyle(themeManager.labelSecondary(for: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }

                    BuxButton(
                        title: BuxCatalogLabel.string(
                            "Log as debt payment",
                            locale: appSettingsManager.interfaceLocale
                        ),
                        role: .primary,
                        size: .regular
                    ) {
                        save()
                    }
                    .disabled(isSaving || selectedDebtId == nil)
                }
                .padding(BuxLayout.marginHorizontal)
                .padding(.vertical, BuxTokens.block)
            }
            .background {
                themeManager.screenBackground(for: colorScheme)
                    .ignoresSafeArea()
            }
            .buxCatalogNavigationTitle("Link Debt Payment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    BuxToolbarCancelButton { dismiss() }
                }
            }
        }
        .buxThemedSheetContent()
    }

    private var transactionSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(record.name)
                .font(.title3.weight(.bold))
                .foregroundStyle(themeManager.labelPrimary(for: colorScheme))

            Text(appSettingsManager.format(abs(record.amountDouble)))
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(themeManager.labelPrimary(for: colorScheme))

            Text(record.date, format: .dateTime.month().day().year())
                .font(.subheadline.weight(.medium))
                .foregroundStyle(themeManager.labelSecondary(for: colorScheme))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(BuxLayout.section)
        .expensesThemedCardChrome(cornerRadius: 20)
    }

    private var suggestionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(BuxLocalizedString.string("Suggested match", locale: appSettingsManager.interfaceLocale))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(themeManager.sectionHeaderColor(for: colorScheme))

            ForEach(suggestions.prefix(3)) { suggestion in
                Button {
                    selectedDebtId = suggestion.debt.id
                } label: {
                    HStack(spacing: 12) {
                        DebtLogoView(debt: suggestion.debt, size: 36)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(suggestion.debt.name)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(themeManager.labelPrimary(for: colorScheme))

                            Text(suggestionReasonLine(suggestion))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(themeManager.labelSecondary(for: colorScheme))
                                .multilineTextAlignment(.leading)
                        }

                        Spacer(minLength: 8)

                        if selectedDebtId == suggestion.debt.id {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(themeManager.contrastAccentColor(for: colorScheme))
                        }
                    }
                    .padding(BuxLayout.section)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(
                                selectedDebtId == suggestion.debt.id
                                    ? themeManager.current.accentColor.opacity(colorScheme == .dark ? 0.18 : 0.1)
                                    : (colorScheme == .dark ? Color.white.opacity(0.04) : Color.black.opacity(0.03))
                            )
                    )
                }
                .buttonStyle(BuxMicroShrinkStyle())
            }
        }
    }

    private var debtPickerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(BuxLocalizedString.string("Apply to debt", locale: appSettingsManager.interfaceLocale))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(themeManager.sectionHeaderColor(for: colorScheme))

            Picker(selection: $selectedDebtId) {
                ForEach(activeDebts) { debt in
                    Text(debt.name).tag(Optional(debt.id))
                }
            } label: {
                EmptyView()
            }
            .pickerStyle(.inline)
            .padding(BuxLayout.section)
            .expensesThemedCardChrome(cornerRadius: 20)
        }
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(BuxLocalizedString.string("Notes (optional)", locale: appSettingsManager.interfaceLocale))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(themeManager.sectionHeaderColor(for: colorScheme))

            TextField(
                BuxLocalizedString.string("Payment note", locale: appSettingsManager.interfaceLocale),
                text: $notes,
                axis: .vertical
            )
            .lineLimit(2...4)
            .padding(BuxLayout.section)
            .expensesThemedCardChrome(cornerRadius: 20)
        }
    }

    private func suggestionReasonLine(_ suggestion: DebtPaymentSuggestion) -> String {
        suggestion.reasonKeys
            .prefix(2)
            .map { BuxCatalogLabel.string($0, locale: appSettingsManager.interfaceLocale) }
            .joined(separator: " · ")
    }

    private func save() {
        guard let selectedDebtId else { return }
        isSaving = true
        errorMessage = nil

        do {
            let sourceRecord = (try? brain.fetchExpenseRecord(id: record.id)) ?? record
            try debtEngine.recordPaymentFromExpense(
                debtId: selectedDebtId,
                record: sourceRecord,
                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            )
            dismiss()
        } catch let error as DebtEngineError {
            errorMessage = error.localizedMessage(locale: appSettingsManager.interfaceLocale)
            isSaving = false
        } catch {
            errorMessage = error.localizedDescription
            isSaving = false
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
