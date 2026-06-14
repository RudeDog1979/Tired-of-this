//
//  SimpleBudgetSetupSheet.swift
//  BuxMuse
//
//  Three-step budget setup for first-time and Home card entry.
//

import SwiftUI

struct SimpleBudgetSetupSheet: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @ObservedObject private var store = SettingsStore.shared

    @State private var step = 0
    @State private var monthlyAmount: Decimal
    @State private var budgetCycle: SimpleBudgetCycle
    @State private var periodAnchor: Date
    @State private var enableBillReminders: Bool

    init() {
        let store = SettingsStore.shared
        _monthlyAmount = State(initialValue: store.simpleBudgetLimit)
        _budgetCycle = State(initialValue: store.simpleBudgetCycle)
        _periodAnchor = State(initialValue: store.simpleBudgetPeriodAnchor)
        _enableBillReminders = State(initialValue: store.billRemindersEnabled)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: BuxTokens.block) {
                progressHeader

                Group {
                    switch step {
                    case 0: amountStep
                    case 1: resetStep
                    default: remindersStep
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                footerButtons
            }
            .padding(BuxLayout.marginHorizontal)
            .padding(.top, BuxTokens.tight)
            .padding(.bottom, BuxTokens.block)
            .background {
                themeManager.screenBackground(for: colorScheme)
                    .ignoresSafeArea()
            }
            .buxCatalogNavigationTitle("Set up your budget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    BuxToolbarCancelButton { dismiss() }
                }
            }
        }
        .buxThemedSheetContent()
    }

    private var progressHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(stepTitle)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(themeManager.labelPrimary(for: colorScheme))
            Text(stepSubtitle)
                .font(.system(size: 14, weight: .medium))
                .buxLabelSecondary()
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var stepTitle: String {
        switch step {
        case 0: return BuxCatalogLabel.string("Monthly Spending Limit", locale: appSettingsManager.interfaceLocale)
        case 1: return BuxCatalogLabel.string("When your month resets", locale: appSettingsManager.interfaceLocale)
        default: return BuxCatalogLabel.string("Stay ahead of bills", locale: appSettingsManager.interfaceLocale)
        }
    }

    private var stepSubtitle: String {
        switch step {
        case 0: return BuxCatalogLabel.string("How much do you want to spend this period?", locale: appSettingsManager.interfaceLocale)
        case 1: return BuxCatalogLabel.string("Pick the rhythm that matches your paycheck or calendar.", locale: appSettingsManager.interfaceLocale)
        default: return BuxCatalogLabel.string("Get a nudge before subscriptions and fixed bills are due.", locale: appSettingsManager.interfaceLocale)
        }
    }

    private var amountStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            TextField(
                BuxCatalogLabel.string("Amount", locale: appSettingsManager.interfaceLocale),
                value: $monthlyAmount,
                format: .number
            )
            .keyboardType(.decimalPad)
            .font(.system(size: 28, weight: .bold, design: .rounded))
            .padding(BuxLayout.section)
            .expensesThemedCardChrome(cornerRadius: 20)
        }
    }

    private var resetStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Picker(selection: $budgetCycle) {
                ForEach(SimpleBudgetCycle.allCases) { cycle in
                    Text(cycle.catalogLabel(locale: appSettingsManager.interfaceLocale)).tag(cycle)
                }
            } label: {
                EmptyView()
            }
            .pickerStyle(.inline)
            .padding(BuxLayout.section)
            .expensesThemedCardChrome(cornerRadius: 20)

            if budgetCycle.needsAnchorDate {
                DatePicker(
                    BuxCatalogLabel.string("Reset anchor date", locale: appSettingsManager.interfaceLocale),
                    selection: $periodAnchor,
                    displayedComponents: .date
                )
                .padding(BuxLayout.section)
                .expensesThemedCardChrome(cornerRadius: 20)
            }
        }
    }

    private var remindersStep: some View {
        Toggle(isOn: $enableBillReminders) {
            VStack(alignment: .leading, spacing: 4) {
                BuxCatalogText.text("Bill reminders")
                    .font(.system(size: 16, weight: .bold))
                BuxCatalogText.text("Notify me before subscriptions and fixed payments are due")
                    .font(.system(size: 13, weight: .medium))
                    .buxLabelSecondary()
            }
        }
        .tint(themeManager.contrastAccentColor(for: colorScheme))
        .padding(BuxLayout.section)
        .expensesThemedCardChrome(cornerRadius: 20)
    }

    private var footerButtons: some View {
        VStack(spacing: 12) {
            BuxButton(
                title: step < 2 ? "Continue" : "Save budget",
                systemImage: step < 2 ? "arrow.right" : "checkmark.circle.fill",
                role: .primary,
                size: .regular
            ) {
                if step < 2 {
                    withAnimation(.buxSnap) { step += 1 }
                } else {
                    saveAndDismiss()
                }
            }
        }
    }

    private func saveAndDismiss() {
        store.budgetingMode = .simple
        store.simpleBudgetLimit = max(0, monthlyAmount)
        store.simpleBudgetCycle = budgetCycle
        store.simpleBudgetPeriodAnchor = periodAnchor
        store.billRemindersEnabled = enableBillReminders
        if enableBillReminders {
            store.notificationsEnabled = true
        }
        store.budgetQuickSetupCompleted = true
        store.save()
        dismiss()
    }
}
