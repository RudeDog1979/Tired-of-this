//
//  DebtsSettingsView.swift
//  BuxMuse
//  Features/Debt/Views/
//
//  Settings drill-in for managing consumer debts.
//

import SwiftUI

struct DebtsSettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @EnvironmentObject private var debtEngine: DebtEngine

    @State private var showAddSheet = false
    @State private var editingDebt: Debt?
    @State private var paymentDebt: Debt?
    @State private var showArchived = false

    var body: some View {
        BuxThemedCardForm {
            BuxFormSection(title: "Consumer debt") {
                Toggle(isOn: Binding(
                    get: { SettingsStore.shared.consumerDebtEnabled },
                    set: { enabled in
                        SettingsStore.shared.consumerDebtEnabled = enabled
                        if !enabled {
                            SettingsStore.shared.debtDiscoveryDeferred = false
                        }
                        SettingsStore.shared.save()
                        PersonalCloudSyncEngine.shared.scheduleSettingsPush()
                    }
                )) {
                    VStack(alignment: .leading, spacing: 4) {
                        BuxCatalogText.text("Track consumer debt")
                            .font(.system(size: 15, weight: .semibold))
                        BuxCatalogDynamicText(key: "Credit cards, bank loans, family loans, and informal lenders.")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
                .tint(themeManager.contrastAccentColor(for: colorScheme))
                .buxFormFieldPadding()
            }

            if SettingsStore.shared.consumerDebtEnabled {
                if debtEngine.activeDebts.isEmpty && debtEngine.archivedDebts.isEmpty {
                    BuxFormSection {
                        VStack(alignment: .leading, spacing: 10) {
                            BuxCatalogText.text("No debts yet")
                                .font(.system(size: 17, weight: .bold))
                            BuxCatalogText.text("Track credit cards, loans, and other balances in one place.")
                                .font(.system(size: 13, weight: .medium))
                                .buxLabelSecondary()
                                .fixedSize(horizontal: false, vertical: true)

                            Button {
                                showAddSheet = true
                            } label: {
                                BuxCatalogText.text("Add your first debt")
                                    .font(.system(size: 15, weight: .bold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(themeManager.contrastAccentColor(for: colorScheme))
                        }
                        .buxFormFieldPadding()
                    }
                } else {
                    summarySection

                    BuxFormSection(title: "Active debts") {
                        ForEach(Array(debtEngine.activeDebts.enumerated()), id: \.element.id) { index, debt in
                            if index > 0 { BuxFormRowDivider() }
                            debtRow(debt)
                        }

                        BuxFormRowDivider()
                        Button {
                            showAddSheet = true
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                BuxCatalogText.text("Add debt")
                                    .font(.system(size: 15, weight: .semibold))
                            }
                            .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .buxFormFieldPadding()
                        }
                        .buttonStyle(.plain)
                    }

                    if !debtEngine.archivedDebts.isEmpty {
                        BuxFormSection(title: "Archived") {
                            Button {
                                withAnimation(.buxSnap) { showArchived.toggle() }
                            } label: {
                                HStack {
                                    BuxCatalogText.text("Show archived debts")
                                        .font(.system(size: 15, weight: .semibold))
                                    Spacer()
                                    BuxCatalogText.text("\(debtEngine.archivedDebts.count)")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                                    Image(systemName: showArchived ? "chevron.up" : "chevron.down")
                                        .font(.system(size: 12, weight: .semibold))
                                        .buxLabelSecondary()
                                }
                                .buxFormFieldPadding()
                            }
                            .buttonStyle(.plain)

                            if showArchived {
                                ForEach(Array(debtEngine.archivedDebts.enumerated()), id: \.element.id) { index, debt in
                                    BuxFormRowDivider()
                                    debtRow(debt, isArchived: true)
                                }
                            }
                        }
                    }
                }
            } else {
                BuxFormSection {
                    BuxCatalogDynamicText(key: "Turn on consumer debt tracking to manage balances, reminders, and payoff insights.")
                        .font(.system(size: 13, weight: .medium))
                        .buxLabelSecondary()
                        .buxFormFieldPadding()
                }
            }
        }
        .buxCatalogNavigationTitle("Debts")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAddSheet) {
            DebtEditorSheet()
                .environmentObject(themeManager)
                .environmentObject(appSettingsManager)
                .environmentObject(debtEngine)
        }
        .sheet(item: $editingDebt) { debt in
            DebtEditorSheet(editingDebt: debt)
                .environmentObject(themeManager)
                .environmentObject(appSettingsManager)
                .environmentObject(debtEngine)
        }
        .sheet(item: $paymentDebt) { debt in
            DebtPaymentLogSheet(debt: debt)
                .environmentObject(themeManager)
                .environmentObject(appSettingsManager)
                .environmentObject(debtEngine)
        }
        .environment(\.isSettingsContext, true)
    }

    @ViewBuilder
    private var summarySection: some View {
        BuxFormSection(title: "Overview") {
            HStack(spacing: 16) {
                summaryMetric(titleKey: "Total owed", value: appSettingsManager.format(debtEngine.totalOwed))
                summaryMetric(titleKey: "Paid this month", value: appSettingsManager.format(debtEngine.paidThisMonth))
                if let nextDue = debtEngine.nextDueDate {
                    summaryMetric(
                        titleKey: "Next due",
                        value: BuxDisplayDate.monthDayYear(from: nextDue, locale: appSettingsManager.interfaceLocale)
                    )
                } else {
                    summaryMetric(titleKey: "Next due", value: "—")
                }
            }
            .buxFormFieldPadding()

            if !debtEngine.balanceBreakdown.isEmpty {
                BuxFormRowDivider()
                DebtBreakdownChartView(breakdown: debtEngine.balanceBreakdown)
                    .buxFormFieldPadding()
            }
        }
    }

    private func summaryMetric(titleKey: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            BuxCatalogText.text(titleKey)
                .font(.system(size: 11, weight: .semibold))
                .buxLabelSecondary()
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func debtRow(_ debt: Debt, isArchived: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                DebtLogoView(debt: debt, size: 40)

                VStack(alignment: .leading, spacing: 4) {
                    Text(debt.name)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                    BuxCatalogText.text(debt.type.catalogLabelKey)
                        .font(.system(size: 12, weight: .medium))
                        .buxLabelSecondary()
                    if let lender = debt.lender, !lender.isEmpty, lender.caseInsensitiveCompare(debt.name) != .orderedSame {
                        Text(lender)
                            .font(.system(size: 11, weight: .medium))
                            .buxLabelSecondary()
                    }
                }
                Spacer()
                Text(appSettingsManager.format(debt.currentBalance))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
            }

            if let payoff = debt.estimatedPayoffMonth {
                let payoffLabel = BuxDisplayDate.monthYear(
                    from: payoff,
                    locale: appSettingsManager.interfaceLocale
                )
                Text(
                    BuxLocalizedString.format(
                        "Est. payoff %@",
                        locale: appSettingsManager.interfaceLocale,
                        payoffLabel
                    )
                )
                .font(.system(size: 11, weight: .medium))
                .buxLabelSecondary()
            }

            HStack(spacing: 12) {
                Button {
                    paymentDebt = debt
                } label: {
                    BuxCatalogText.text("Payment log")
                        .font(.system(size: 12, weight: .semibold))
                }

                Button {
                    editingDebt = debt
                } label: {
                    BuxCatalogText.text("Edit")
                        .font(.system(size: 12, weight: .semibold))
                }

                if isArchived {
                    Button {
                        debtEngine.unarchiveDebt(id: debt.id)
                    } label: {
                        BuxCatalogText.text("Restore")
                            .font(.system(size: 12, weight: .semibold))
                    }
                } else {
                    Button(role: .destructive) {
                        debtEngine.archiveDebt(id: debt.id)
                    } label: {
                        BuxCatalogText.text("Archive")
                            .font(.system(size: 12, weight: .semibold))
                    }
                }
            }
            .buttonStyle(.plain)
            .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
        }
        .buxFormFieldPadding()
    }
}

// MARK: - Payment log sheet

private struct DebtPaymentLogSheet: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @EnvironmentObject private var debtEngine: DebtEngine

    let debt: Debt

    @State private var amountText = ""
    @State private var notes = ""

    private var liveDebt: Debt {
        debtEngine.debts.first(where: { $0.id == debt.id }) ?? debt
    }

    var body: some View {
        NavigationStack {
            BuxThemedCardForm {
                BuxFormSection(title: "Record payment") {
                    BuxSettingsLabeledValueRow {
                        BuxCatalogText.text("Amount")
                            .font(.system(size: 15, weight: .semibold))
                    } value: {
                        DebtCurrencyAmountField(placeholderKey: "Amount", amountText: $amountText)
                    }

                    BuxFormRowDivider()

                    TextField(
                        BuxCatalogLabel.string("Notes", locale: appSettingsManager.interfaceLocale),
                        text: $notes
                    )
                    .buxFormFieldPadding()

                    Button {
                        recordPayment()
                    } label: {
                        BuxCatalogText.text("Log payment")
                            .font(.system(size: 15, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(themeManager.contrastAccentColor(for: colorScheme))
                    .disabled(parseDecimal(amountText) == nil)
                    .buxFormFieldPadding()
                }

                BuxFormSection(title: "Payment history") {
                    if liveDebt.payments.isEmpty {
                        BuxCatalogText.text("No payments logged yet.")
                            .font(.system(size: 13, weight: .medium))
                            .buxLabelSecondary()
                            .buxFormFieldPadding()
                    } else {
                        ForEach(Array(liveDebt.payments.enumerated()), id: \.element.id) { index, payment in
                            if index > 0 { BuxFormRowDivider() }
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(appSettingsManager.format(payment.amount))
                                        .font(.system(size: 14, weight: .bold))
                                    Text(payment.date, style: .date)
                                        .font(.system(size: 12, weight: .medium))
                                        .buxLabelSecondary()
                                    if let note = payment.notes, !note.isEmpty {
                                        Text(note)
                                            .font(.system(size: 11, weight: .medium))
                                            .buxLabelSecondary()
                                    }
                                }
                                Spacer()
                                if payment.linkedExpenseId != nil {
                                    Image(systemName: "link")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                                }
                            }
                            .buxFormFieldPadding()
                        }
                    }
                }
            }
            .buxCatalogNavigationTitle(liveDebt.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(BuxCatalogLabel.string("Done", locale: appSettingsManager.interfaceLocale)) {
                        dismiss()
                    }
                }
            }
        }
        .buxThemedSheetContent()
    }

    private func recordPayment() {
        guard let amount = parseDecimal(amountText) else { return }
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        debtEngine.recordPayment(
            debtId: debt.id,
            amount: amount,
            notes: trimmedNotes.isEmpty ? nil : trimmedNotes
        )
        amountText = ""
        notes = ""
    }

    private func parseDecimal(_ text: String) -> Decimal? {
        appSettingsManager.parseAmountInput(text)
    }
}
