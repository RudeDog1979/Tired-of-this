//
//  LinkPaycheckSheet.swift
//  BuxMuse
//
//  Links an incoming transaction as the user's recurring paycheck anchor.
//

import SwiftUI

struct LinkPaycheckSheet: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @EnvironmentObject private var brain: BuxMuseBrain

    let record: ExpenseRecord

    @State private var payCycle: SimpleBudgetCycle
    @State private var payAnchorDate: Date
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(record: ExpenseRecord) {
        self.record = record
        let suggested = SalaryPayrollMatcher.suggestedPayCycle(for: record.date)
        _payCycle = State(initialValue: suggested.0)
        _payAnchorDate = State(initialValue: suggested.1)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    transactionSummary

                    VStack(alignment: .leading, spacing: 12) {
                        Text(BuxLocalizedString.string("When your budget resets", locale: appSettingsManager.interfaceLocale))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(themeManager.sectionHeaderColor(for: colorScheme))

                        Picker(selection: $payCycle) {
                            ForEach(SimpleBudgetCycle.allCases) { cycle in
                                Text(cycle.catalogLabel(locale: appSettingsManager.interfaceLocale)).tag(cycle)
                            }
                        } label: {
                            EmptyView()
                        }
                        .pickerStyle(.inline)
                        .padding(BuxLayout.section)
                        .expensesThemedCardChrome(cornerRadius: 20)

                        if payCycle.needsAnchorDate || payCycle == .custom {
                            DatePicker(
                                BuxLocalizedString.string("Period starts on", locale: appSettingsManager.interfaceLocale),
                                selection: $payAnchorDate,
                                displayedComponents: .date
                            )
                            .tint(themeManager.contrastAccentColor(for: colorScheme))
                            .padding(BuxLayout.section)
                            .expensesThemedCardChrome(cornerRadius: 20)
                        }
                    }

                    Text(BuxLocalizedString.string(
                        "We keep the bank label on this transaction and recognise future paychecks from the same source on your pay cycle.",
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
                        title: "Link as paycheck",
                        role: .primary,
                        size: .regular
                    ) {
                        save()
                    }
                    .disabled(isSaving)
                }
                .padding(BuxLayout.marginHorizontal)
                .padding(.vertical, BuxTokens.block)
            }
            .background {
                themeManager.screenBackground(for: colorScheme)
                    .ignoresSafeArea()
            }
            .buxCatalogNavigationTitle("Link Paycheck")
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
                .foregroundStyle(themeManager.contrastAccentColor(for: colorScheme))

            Text(record.date, format: .dateTime.month().day().year())
                .font(.subheadline.weight(.medium))
                .foregroundStyle(themeManager.labelSecondary(for: colorScheme))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(BuxLayout.section)
        .expensesThemedCardChrome(cornerRadius: 20)
    }

    private func save() {
        isSaving = true
        errorMessage = nil
        do {
            _ = try brain.linkPaycheck(from: record, payCycle: payCycle, payAnchorDate: payAnchorDate)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            isSaving = false
        }
    }
}
