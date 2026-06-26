//
//  DebtEditorSheet.swift
//  BuxMuse
//  Features/Debt/Views/
//
//  Form for creating and editing consumer debts.
//

import SwiftUI

struct DebtEditorSheet: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @EnvironmentObject private var debtEngine: DebtEngine

    let editingDebt: Debt?

    @State private var name: String = ""
    @State private var type: DebtType = .creditCard
    @State private var currentBalanceText: String = ""
    @State private var originalBalanceText: String = ""
    @State private var aprText: String = ""
    @State private var minimumPaymentText: String = ""
    @State private var dueDay: Int = 1
    @State private var hasDueDay: Bool = false
    @State private var lender: String = ""
    @State private var lenderSource: DebtLenderSource = .bank
    @State private var remindersEnabled: Bool = true
    @State private var notes: String = ""

    init(editingDebt: Debt? = nil) {
        self.editingDebt = editingDebt
    }

    var body: some View {
        NavigationStack {
            BuxThemedCardForm {
                BuxFormSection(title: "Debt details") {
                    HStack(spacing: 12) {
                        DebtLogoView(
                            debt: Debt(
                                name: name,
                                type: type,
                                currentBalance: parseDecimal(currentBalanceText) ?? 0,
                                lender: lender.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : lender,
                                lenderSource: lenderSource
                            ),
                            size: 44
                        )
                        VStack(alignment: .leading, spacing: 4) {
                            BuxCatalogText.text("Account")
                                .font(.system(size: 11, weight: .semibold))
                                .buxLabelSecondary()
                            Text(name.isEmpty ? "—" : name)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(themeManager.labelPrimary(for: colorScheme))
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                    }
                    .buxFormFieldPadding()

                    BuxFormRowDivider()

                    BuxSettingsLabeledValueRow {
                        BuxCatalogText.text("Name")
                            .font(.system(size: 15, weight: .semibold))
                    } value: {
                        TextField(
                            BuxCatalogLabel.string("e.g. Chase Sapphire", locale: appSettingsManager.interfaceLocale),
                            text: $name
                        )
                        .multilineTextAlignment(.trailing)
                    }

                    BuxFormRowDivider()

                    BuxSettingsMenuPickerRow(titleKey: "Type", selection: $type) {
                        ForEach(DebtType.allCases) { debtType in
                            Text(BuxCatalogLabel.string(debtType.catalogLabelKey, locale: appSettingsManager.interfaceLocale))
                                .tag(debtType)
                        }
                    }

                    BuxFormRowDivider()

                    BuxSettingsLabeledValueRow {
                        BuxCatalogText.text("Current balance")
                            .font(.system(size: 15, weight: .semibold))
                    } value: {
                        DebtCurrencyAmountField(placeholderKey: "Amount", amountText: $currentBalanceText)
                    }

                    BuxFormRowDivider()

                    BuxSettingsLabeledValueRow {
                        BuxCatalogText.text("Original balance")
                            .font(.system(size: 15, weight: .semibold))
                    } value: {
                        DebtCurrencyAmountField(placeholderKey: "Optional", amountText: $originalBalanceText)
                    }
                }

                BuxFormSection(title: "Terms") {
                    BuxSettingsLabeledValueRow {
                        BuxCatalogText.text("APR %")
                            .font(.system(size: 15, weight: .semibold))
                    } value: {
                        TextField(
                            BuxCatalogLabel.string("Optional", locale: appSettingsManager.interfaceLocale),
                            text: $aprText
                        )
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                    }

                    BuxFormRowDivider()

                    BuxSettingsLabeledValueRow {
                        BuxCatalogText.text("Minimum payment")
                            .font(.system(size: 15, weight: .semibold))
                    } value: {
                        DebtCurrencyAmountField(placeholderKey: "Optional", amountText: $minimumPaymentText)
                    }

                    BuxFormRowDivider()

                    Toggle(isOn: $hasDueDay) {
                        BuxCatalogText.text("Monthly due date")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .tint(themeManager.contrastAccentColor(for: colorScheme))
                    .buxFormFieldPadding()

                    if hasDueDay {
                        BuxFormRowDivider()
                        BuxSettingsMenuPickerRow(titleKey: "Due day", selection: $dueDay) {
                            ForEach(1...28, id: \.self) { day in
                                Text("\(day)").tag(day)
                            }
                        }
                    }
                }

                BuxFormSection(title: "Lender") {
                    BuxSettingsMenuPickerRow(titleKey: "Source", selection: $lenderSource) {
                        ForEach(DebtLenderSource.allCases) { source in
                            Text(BuxCatalogLabel.string(source.catalogLabelKey, locale: appSettingsManager.interfaceLocale))
                                .tag(source)
                        }
                    }

                    BuxFormRowDivider()

                    BuxSettingsLabeledValueRow {
                        BuxCatalogText.text(lenderSource == .bank || lenderSource == .creditUnion ? "Institution" : "Name")
                            .font(.system(size: 15, weight: .semibold))
                    } value: {
                        TextField(
                            BuxCatalogLabel.string(
                                lenderSource == .friendOrFamily ? "e.g. Mom, Uncle Carlos" :
                                    lenderSource == .informalLender ? "e.g. Local lender" :
                                    lenderSource == .privateIndividual ? "e.g. John Smith" :
                                    "e.g. Chase, mBank",
                                locale: appSettingsManager.interfaceLocale
                            ),
                            text: $lender
                        )
                        .multilineTextAlignment(.trailing)
                    }

                    if lenderSource.usesInstitutionLogo,
                       !lender.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                       !FinancialInstitutionCatalog.hasKnownInstitution(lender) {
                        BuxFormRowDivider()
                        BuxCatalogDynamicText(key: "Logo appears only for known banks in our catalog. Everyone else gets a category icon.")
                            .font(.system(size: 11, weight: .medium))
                            .buxLabelSecondary()
                            .buxFormFieldPadding()
                    }
                }

                BuxFormSection(title: "Reminders") {
                    Toggle(isOn: $remindersEnabled) {
                        VStack(alignment: .leading, spacing: 4) {
                            BuxCatalogText.text("Due date reminders")
                                .font(.system(size: 15, weight: .semibold))
                            BuxCatalogDynamicText(key: "Local notification 3 days before your due date.")
                                .font(.system(size: 11, weight: .medium))
                                .buxLabelSecondary()
                        }
                    }
                    .tint(themeManager.contrastAccentColor(for: colorScheme))
                    .buxFormFieldPadding()
                }

                BuxFormSection(title: "Notes") {
                    TextField(
                        BuxCatalogLabel.string("Notes", locale: appSettingsManager.interfaceLocale),
                        text: $notes,
                        axis: .vertical
                    )
                    .lineLimit(3...6)
                    .buxFormFieldPadding()
                }

                if let preview = payoffPreview {
                    BuxFormSection(title: "Payoff estimate") {
                        BuxCatalogDynamicText(key: preview)
                            .font(.system(size: 13, weight: .medium))
                            .buxLabelSecondary()
                            .buxFormFieldPadding()
                    }
                }
            }
            .buxCatalogNavigationTitle(editingDebt == nil ? "Add debt" : "Edit debt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(BuxCatalogLabel.string("Cancel", locale: appSettingsManager.interfaceLocale)) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(BuxCatalogLabel.string("Save", locale: appSettingsManager.interfaceLocale)) {
                        save()
                    }
                    .disabled(!canSave)
                }
            }
        }
        .onAppear(perform: populateFromEditingDebt)
        .buxThemedSheetContent()
        .environment(\.isSettingsContext, true)
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && parseDecimal(currentBalanceText) != nil
    }

    private var payoffPreview: String? {
        guard let balance = parseDecimal(currentBalanceText),
              let apr = parseDecimal(aprText),
              let minPay = parseDecimal(minimumPaymentText) else { return nil }
        let draft = Debt(
            name: name,
            type: type,
            currentBalance: balance,
            aprPercent: apr,
            minimumPayment: minPay
        )
        guard let payoff = draft.estimatedPayoffMonth else {
            return BuxLocalizedString.string(
                "Add APR and minimum payment to see an estimated payoff month.",
                locale: appSettingsManager.interfaceLocale
            )
        }
        let payoffLabel = BuxDisplayDate.monthYear(
            from: payoff,
            locale: appSettingsManager.interfaceLocale
        )
        return BuxLocalizedString.format(
            "Estimated payoff: %@",
            locale: appSettingsManager.interfaceLocale,
            payoffLabel
        )
    }

    private func populateFromEditingDebt() {
        guard let debt = editingDebt else { return }
        name = debt.name
        type = debt.type
        currentBalanceText = appSettingsManager.formatAmountInput(debt.currentBalance)
        if let original = debt.originalBalance {
            originalBalanceText = appSettingsManager.formatAmountInput(original)
        }
        if let apr = debt.aprPercent {
            aprText = appSettingsManager.formatAmountInput(apr)
        }
        if let minPay = debt.minimumPayment {
            minimumPaymentText = appSettingsManager.formatAmountInput(minPay)
        }
        if let day = debt.dueDayOfMonth {
            hasDueDay = true
            dueDay = day
        }
        lender = debt.lender ?? ""
        lenderSource = debt.lenderSource
        remindersEnabled = debt.remindersEnabled
        notes = debt.notes ?? ""
    }

    private func save() {
        guard let balance = parseDecimal(currentBalanceText) else { return }
        let original = parseDecimal(originalBalanceText)
        let apr = parseDecimal(aprText)
        let minPay = parseDecimal(minimumPaymentText)
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLender = lender.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)

        if var existing = editingDebt {
            existing.name = trimmedName
            existing.type = type
            existing.currentBalance = balance
            existing.originalBalance = original
            existing.aprPercent = apr
            existing.minimumPayment = minPay
            existing.dueDayOfMonth = hasDueDay ? dueDay : nil
            existing.lender = trimmedLender.isEmpty ? nil : trimmedLender
            existing.lenderSource = lenderSource
            existing.remindersEnabled = remindersEnabled
            existing.notes = trimmedNotes.isEmpty ? nil : trimmedNotes
            debtEngine.updateDebt(existing)
        } else {
            debtEngine.createDebt(
                name: trimmedName,
                type: type,
                currentBalance: balance,
                originalBalance: original,
                aprPercent: apr,
                minimumPayment: minPay,
                dueDayOfMonth: hasDueDay ? dueDay : nil,
                lender: trimmedLender.isEmpty ? nil : trimmedLender,
                lenderSource: lenderSource,
                remindersEnabled: remindersEnabled,
                notes: trimmedNotes.isEmpty ? nil : trimmedNotes
            )
        }
        dismiss()
    }

    private func parseDecimal(_ text: String) -> Decimal? {
        appSettingsManager.parseAmountInput(text)
    }
}
