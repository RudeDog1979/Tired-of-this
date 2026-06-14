//
//  DebtDetailView.swift
//  BuxMuse
//
//  Full debt detail — payments, intelligence, reminders.
//

import SwiftUI

struct DebtDetailView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @EnvironmentObject private var debtEngine: DebtEngine

    let debt: Debt
    @Binding var isPresented: Bool

    @State private var showEditSheet = false
    @State private var showPaymentSheet = false
    @State private var amountText = ""
    @State private var paymentNotes = ""

    private var liveDebt: Debt {
        debtEngine.debts.first(where: { $0.id == debt.id }) ?? debt
    }

    private var insights: [DebtInsight] {
        DebtIntelligenceEngine.debtInsights(for: liveDebt, locale: appSettingsManager.interfaceLocale)
    }

    private var accent: Color { themeManager.contrastAccentColor(for: colorScheme) }

    var body: some View {
        BuxDetailOverlayScaffold(title: liveDebt.name, localizeTitle: false) {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                isPresented = false
            }
        } content: {
            heroSection
            quickActions
            if !insights.isEmpty { insightsSection }
            termsSection
            if liveDebt.remindersEnabled, let days = liveDebt.daysUntilDue {
                reminderBanner(daysUntil: days)
            }
            paymentsSection
        }
        .buxThemedPresentation()
        .sheet(isPresented: $showEditSheet) {
            DebtEditorSheet(editingDebt: liveDebt)
                .environmentObject(themeManager)
                .environmentObject(appSettingsManager)
                .environmentObject(debtEngine)
        }
        .sheet(isPresented: $showPaymentSheet) {
            paymentSheet
        }
    }

    private var heroSection: some View {
        VStack(spacing: 16) {
            DebtLogoView(debt: liveDebt, size: 64)

            VStack(spacing: 6) {
                BuxCatalogText.text(liveDebt.lenderSource.catalogLabelKey)
                    .font(.system(size: 12, weight: .semibold))
                    .buxLabelSecondary()
                Text(appSettingsManager.format(liveDebt.currentBalance))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(themeManager.labelPrimary(for: colorScheme))
                BuxCatalogText.text("Current balance")
                    .font(.system(size: 12, weight: .medium))
                    .buxLabelSecondary()
            }

            if let fraction = liveDebt.paidDownFraction {
                VStack(spacing: 8) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05))
                                .frame(height: 8)
                            Capsule()
                                .fill(accent)
                                .frame(width: geo.size.width * CGFloat(fraction), height: 8)
                        }
                    }
                    .frame(height: 8)

                    Text(
                        BuxLocalizedString.format(
                            "%lld%% paid down",
                            locale: appSettingsManager.interfaceLocale,
                            Int64(Int(fraction * 100))
                        )
                    )
                    .font(.system(size: 11, weight: .semibold))
                    .buxLabelSecondary()
                }
            }
        }
        .padding(.vertical, 8)
    }

    private var quickActions: some View {
        HStack(spacing: 12) {
            actionButton(titleKey: "Log payment", systemImage: "plus.circle.fill") {
                showPaymentSheet = true
            }
            actionButton(titleKey: "Edit", systemImage: "pencil.circle.fill") {
                showEditSheet = true
            }
        }
    }

    private func actionButton(titleKey: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                BuxCatalogText.text(titleKey)
                    .font(.system(size: 14, weight: .bold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .buttonStyle(.borderedProminent)
        .tint(accent)
    }

    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            BuxCatalogText.text("On-device insights")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(themeManager.labelPrimary(for: colorScheme))

            ForEach(insights) { insight in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: insight.systemImage)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(accent)
                        .frame(width: 22)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(insight.title)
                            .font(.system(size: 13, weight: .bold))
                        Text(insight.message)
                            .font(.system(size: 12, weight: .medium))
                            .buxLabelSecondary()
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.04))
                )
            }
        }
    }

    private var termsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            BuxCatalogText.text("Terms")
                .font(.system(size: 14, weight: .bold))

            VStack(spacing: 0) {
                if let lender = liveDebt.lender, !lender.isEmpty {
                    termRow(titleKey: "Lender", value: lender)
                    BuxFormRowDivider()
                }
                termRow(titleKey: "Type", value: BuxCatalogLabel.string(liveDebt.type.catalogLabelKey, locale: appSettingsManager.interfaceLocale))
                if let apr = liveDebt.aprPercent {
                    BuxFormRowDivider()
                    termRow(titleKey: "APR", value: "\(appSettingsManager.formatAmountInput(apr))%")
                }
                if let minPay = liveDebt.minimumPayment {
                    BuxFormRowDivider()
                    termRow(titleKey: "Minimum payment", value: appSettingsManager.format(minPay))
                }
                if let dueDay = liveDebt.dueDayOfMonth {
                    BuxFormRowDivider()
                    termRow(
                        titleKey: "Due day",
                        value: BuxLocalizedString.format(
                            "Day %lld of each month",
                            locale: appSettingsManager.interfaceLocale,
                            Int64(dueDay)
                        )
                    )
                }
            }
            .dashboardMaterialCardChrome(.outlined)
        }
    }

    private func termRow(titleKey: String, value: String) -> some View {
        HStack {
            BuxCatalogText.text(titleKey)
                .font(.system(size: 13, weight: .semibold))
                .buxLabelSecondary()
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(themeManager.labelPrimary(for: colorScheme))
        }
        .padding(.horizontal, BuxTokens.section)
        .padding(.vertical, 12)
    }

    private func reminderBanner(daysUntil: Int) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "bell.fill")
                .foregroundStyle(.orange)
            Text(
                daysUntil == 0
                    ? BuxCatalogLabel.string("Payment due today — reminder is on.", locale: appSettingsManager.interfaceLocale)
                    : BuxLocalizedString.format(
                        "Reminder on — due in %lld days.",
                        locale: appSettingsManager.interfaceLocale,
                        Int64(daysUntil)
                    )
            )
            .font(.system(size: 12, weight: .semibold))
            .buxLabelSecondary()
            Spacer()
            Toggle("", isOn: Binding(
                get: { liveDebt.remindersEnabled },
                set: { debtEngine.setRemindersEnabled(debtId: liveDebt.id, enabled: $0) }
            ))
            .labelsHidden()
            .tint(accent)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.orange.opacity(colorScheme == .dark ? 0.12 : 0.08))
        )
    }

    private var paymentsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            BuxCatalogText.text("Payment history")
                .font(.system(size: 14, weight: .bold))

            if liveDebt.payments.isEmpty {
                BuxCatalogText.text("No payments logged yet.")
                    .font(.system(size: 13, weight: .medium))
                    .buxLabelSecondary()
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(liveDebt.payments.enumerated()), id: \.element.id) { index, payment in
                        if index > 0 { BuxFormRowDivider() }
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(appSettingsManager.format(payment.amount))
                                    .font(.system(size: 14, weight: .bold))
                                Text(payment.date, style: .date)
                                    .font(.system(size: 12, weight: .medium))
                                    .buxLabelSecondary()
                            }
                            Spacer()
                        }
                        .padding(.horizontal, BuxTokens.section)
                        .padding(.vertical, 12)
                    }
                }
                .dashboardMaterialCardChrome(.outlined)
            }
        }
    }

    private var paymentSheet: some View {
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
                        text: $paymentNotes
                    )
                    .buxFormFieldPadding()

                    Button {
                        guard let amount = appSettingsManager.parseAmountInput(amountText) else { return }
                        let trimmed = paymentNotes.trimmingCharacters(in: .whitespacesAndNewlines)
                        debtEngine.recordPayment(
                            debtId: liveDebt.id,
                            amount: amount,
                            notes: trimmed.isEmpty ? nil : trimmed
                        )
                        amountText = ""
                        paymentNotes = ""
                        showPaymentSheet = false
                    } label: {
                        BuxCatalogText.text("Log payment")
                            .font(.system(size: 15, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(accent)
                    .disabled(appSettingsManager.parseAmountInput(amountText) == nil)
                    .buxFormFieldPadding()
                }
            }
            .buxCatalogNavigationTitle(liveDebt.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(BuxCatalogLabel.string("Cancel", locale: appSettingsManager.interfaceLocale)) {
                        showPaymentSheet = false
                    }
                }
            }
        }
        .buxThemedSheetContent()
    }
}
