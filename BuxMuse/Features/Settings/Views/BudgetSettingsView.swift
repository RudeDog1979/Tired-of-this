//
//  BudgetSettingsView.swift
//  BuxMuse
//
//  Budget configuration and custom budgeting envelope profiles manager.
//

import SwiftUI

struct BudgetSettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @ObservedObject private var store = SettingsStore.shared

    @State private var editingProfile: CustomBudgetProfile? = nil
    @State private var showCreator = false

    var body: some View {
        BuxThemedCardForm {
            BuxFormSection(title: "Budget method") {
                Picker("Budgeting Mode", selection: $store.budgetingMode) {
                    ForEach(BudgetingMode.allCases) { mode in
                        Text(mode.catalogLabel(locale: appSettingsManager.interfaceLocale)).tag(mode)
                    }
                }
                .buxThemedSegmentedPicker()
                .buxFormFieldPadding()

                if store.budgetingMode == .custom {
                    BuxFormRowDivider()
                    HStack {
                        BuxCatalogDynamicText(key: "Spending Cap")
                            .font(.system(size: 15, weight: .semibold))
                        Spacer()
                        TextField("Amount", value: $store.customBudgetLimit, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(themeManager.current.accentColor)
                            .font(.system(size: 16, weight: .bold))
                            .frame(width: 120)
                    }
                    .buxFormFieldPadding()
                    BuxFormRowDivider()
                    Picker("Budget Period", selection: $store.customBudgetPeriod) {
                        ForEach(DefaultBudgetPeriod.allCases) { period in
                            Text(period.catalogLabel(locale: appSettingsManager.interfaceLocale)).tag(period)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(themeManager.current.accentColor)
                    .buxFormFieldPadding()
                } else if store.budgetingMode == .envelope {
                    BuxFormRowDivider()
                    Picker("Default Cycle", selection: $store.defaultBudgetPeriod) {
                        ForEach(DefaultBudgetPeriod.allCases) { period in
                            Text(period.catalogLabel(locale: appSettingsManager.interfaceLocale)).tag(period)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(themeManager.current.accentColor)
                    .buxFormFieldPadding()
                }
            }

            if store.budgetingMode == .simple {
                BuxFormSection(title: "Income & payday profile") {
                    Picker("Income Source", selection: $store.incomeFundingSource) {
                        ForEach(IncomeFundingSource.allCases) { source in
                            Text(source.catalogLabel(locale: appSettingsManager.interfaceLocale)).tag(source)
                        }
                    }
                    .buxThemedSegmentedPicker()
                    .buxFormFieldPadding()

                    BuxFormRowDivider()
                    Picker("Payday Schedule", selection: $store.simpleBudgetCycle) {
                        ForEach(SimpleBudgetCycle.allCases) { cycle in
                            Text(cycle.catalogLabel(locale: appSettingsManager.interfaceLocale)).tag(cycle)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(themeManager.current.accentColor)
                    .buxFormFieldPadding()

                    if store.simpleBudgetCycle.needsAnchorDate {
                        BuxFormRowDivider()
                        DatePicker(
                            "Period starts on",
                            selection: $store.simpleBudgetPeriodAnchor,
                            displayedComponents: .date
                        )
                        .tint(themeManager.current.accentColor)
                        .buxFormFieldPadding()
                    }

                    BuxFormRowDivider()
                    HStack {
                        BuxCatalogDynamicText(key: "Spending limit this period")
                            .font(.system(size: 15, weight: .semibold))
                        Spacer()
                        TextField("Amount", value: $store.simpleBudgetLimit, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(themeManager.current.accentColor)
                            .font(.system(size: 16, weight: .bold))
                            .frame(width: 120)
                    }
                    .buxFormFieldPadding()

                    BuxFormRowDivider()
                    BuxCatalogDynamicText(key: "Your simple budget tracks expenses starting on your pay cycle—allowing you to measure spending relative to when your income arrives, rather than just the calendar month.")
                        .font(.system(size: 12, weight: .medium))
                        .buxLabelSecondary()
                        .fixedSize(horizontal: false, vertical: true)
                        .buxFormFieldPadding()
                }
            }

            BuxFormSection(title: "Intelligence rules") {
                Toggle("Show Budget Warnings", isOn: $store.showBudgetWarnings)
                    .tint(themeManager.current.accentColor)
                    .buxFormFieldPadding()
                BuxFormRowDivider()
                Toggle(isOn: $store.autoAdjustBudgetsFromHistory) {
                    VStack(alignment: .leading, spacing: 2) {
                        BuxCatalogDynamicText(key: "Auto-adjust from History")
                            .font(.system(size: 15, weight: .semibold))
                        BuxCatalogDynamicText(key: "BuxMuse Brain will adjust limits based on seasonal spend trends")
                            .font(.system(size: 11))
                            .buxLabelSecondary()
                    }
                }
                .tint(themeManager.current.accentColor)
                .buxFormFieldPadding()
            }

            BuxFormSection(title: "Custom envelope profiles") {
                if store.customBudgetProfiles.isEmpty {
                    BuxCatalogDynamicText(key: "No custom profiles configured.")
                        .font(.system(size: 14))
                        .buxLabelSecondary()
                        .buxFormFieldPadding()
                } else {
                    ForEach(Array(store.customBudgetProfiles.enumerated()), id: \.element.id) { index, profile in
                        if index > 0 { BuxFormRowDivider() }
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 8) {
                                    Text(profile.name)
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                                    if profile.isActive {
                                        BuxCatalogDynamicText(key: "Active")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(themeManager.current.accentColor)
                                            .clipShape(Capsule())
                                    }
                                }
                                Text(
                                    BuxLocalizedString.format(
                                        "%lld Categories · Target: %@",
                                        locale: appSettingsManager.interfaceLocale,
                                        Int64(profile.categories.count),
                                        appSettingsManager.format(profile.targetAmount)
                                    )
                                )
                                    .font(.system(size: 12))
                                    .buxLabelSecondary()
                            }

                            Spacer()

                            Button(action: { editingProfile = profile }) {
                                Image(systemName: "pencil")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(themeManager.current.accentColor)
                            }
                            .buttonStyle(.plain)

                            Button(role: .destructive) {
                                deleteProfile(id: profile.id)
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 14, weight: .bold))
                            }
                            .buttonStyle(.plain)
                        }
                        .buxFormFieldPadding()
                    }
                }

                BuxFormRowDivider()
                Button(action: { showCreator = true }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        BuxCatalogDynamicText(key: "Add Custom Envelope Profile")
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(themeManager.current.accentColor)
                }
                .buxFormFieldPadding()
            }
        }
        .buxCatalogNavigationTitle("Budgets")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editingProfile) { profile in
            BudgetProfileEditorView(profile: profile) { updatedProfile in
                if let index = store.customBudgetProfiles.firstIndex(where: { $0.id == updatedProfile.id }) {
                    store.customBudgetProfiles[index] = updatedProfile
                    if updatedProfile.isActive {
                        makeProfileActive(updatedProfile)
                    }
                    store.save()
                }
            }
            .buxThemedSheetContent()
            .environment(\.settingsEnhancedTint, true)
        }
        .sheet(isPresented: $showCreator) {
            BudgetProfileEditorView(profile: CustomBudgetProfile(name: "", categories: [])) { newProfile in
                var finalProfile = newProfile
                if store.customBudgetProfiles.isEmpty {
                    finalProfile.isActive = true
                }
                store.customBudgetProfiles.append(finalProfile)
                if finalProfile.isActive {
                    makeProfileActive(finalProfile)
                }
                store.save()
            }
            .buxThemedSheetContent()
            .environment(\.settingsEnhancedTint, true)
        }
        .onChange(of: store.budgetingMode) { _, _ in store.save() }
        .onChange(of: store.defaultBudgetPeriod) { _, newValue in
            store.customBudgetPeriod = newValue
            store.save()
        }
        .onChange(of: store.showBudgetWarnings) { _, _ in store.save() }
        .onChange(of: store.autoAdjustBudgetsFromHistory) { _, _ in store.save() }
        .onChange(of: store.simpleBudgetLimit) { _, _ in store.save() }
        .onChange(of: store.simpleBudgetCycle) { _, _ in store.save() }
        .onChange(of: store.simpleBudgetPeriodAnchor) { _, _ in store.save() }
        .onChange(of: store.incomeFundingSource) { _, _ in store.save() }
        .onChange(of: store.customBudgetLimit) { _, _ in store.save() }
        .onChange(of: store.customBudgetPeriod) { _, _ in store.save() }
    }

    private func makeProfileActive(_ activeProfile: CustomBudgetProfile) {
        for i in 0..<store.customBudgetProfiles.count {
            if store.customBudgetProfiles[i].id != activeProfile.id {
                store.customBudgetProfiles[i].isActive = false
            } else {
                store.customBudgetProfiles[i].isActive = true
            }
        }
    }

    private func deleteProfile(id: UUID) {
        store.customBudgetProfiles.removeAll { $0.id == id }
        if !store.customBudgetProfiles.isEmpty && !store.customBudgetProfiles.contains(where: { $0.isActive }) {
            store.customBudgetProfiles[0].isActive = true
        }
        store.save()
    }
}

// MARK: - Custom Budget Profile & Category Editor View

struct BudgetProfileEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    @State var profile: CustomBudgetProfile
    let onSave: (CustomBudgetProfile) -> Void

    @State private var newCategoryName = ""
    @State private var newCategoryTarget = ""

    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.screenBackground(for: colorScheme).ignoresSafeArea()
                BuxThemedCardForm {
                    BuxFormSection(title: "Profile details") {
                        TextField("Profile Name (e.g. Summer Travel)", text: $profile.name)
                            .font(.system(size: 15, weight: .semibold))
                            .buxFormFieldPadding()
                        BuxFormRowDivider()
                        Toggle("Active Budget Rule", isOn: $profile.isActive)
                            .tint(themeManager.current.accentColor)
                            .buxFormFieldPadding()
                        BuxFormRowDivider()
                        Toggle("Enable Category Rollover", isOn: $profile.rolloverEnabled)
                            .tint(themeManager.current.accentColor)
                            .buxFormFieldPadding()
                    }

                    BuxFormSection(title: "Envelope categories") {
                        if profile.categories.isEmpty {
                            BuxCatalogDynamicText(key: "No categories added yet.")
                                .font(.system(size: 14))
                                .buxLabelSecondary()
                                .buxFormFieldPadding()
                        } else {
                            ForEach(Array(profile.categories.enumerated()), id: \.element.id) { index, category in
                                if index > 0 { BuxFormRowDivider() }
                                HStack {
                                    Text(category.name)
                                        .font(.system(size: 14, weight: .bold))
                                    Spacer()
                                    Text(appSettingsManager.format(category.targetAmount))
                                        .font(.system(size: 14, weight: .medium))
                                        .buxLabelSecondary()
                                    Button(role: .destructive) {
                                        removeCategory(id: category.id)
                                    } label: {
                                        Image(systemName: "minus.circle.fill")
                                    }
                                    .buttonStyle(.plain)
                                }
                                .buxFormFieldPadding()
                            }
                        }
                    }

                    BuxFormSection(title: "Add category") {
                        TextField("Category Name", text: $newCategoryName)
                            .buxFormFieldPadding()
                        BuxFormRowDivider()
                        HStack {
                            TextField("Target Limit Amount", text: $newCategoryTarget)
                                .keyboardType(.decimalPad)
                            Spacer()
                            Button(action: addCategory) {
                                BuxCatalogDynamicText(key: "Add")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(themeManager.current.accentColor)
                            }
                            .disabled(newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || newCategoryTarget.isEmpty)
                        }
                        .buxFormFieldPadding()
                    }

                    BuxFormSection(title: "Summary") {
                        HStack {
                            BuxCatalogDynamicText(key: "Total Budget Limit")
                                .font(.system(size: 15, weight: .bold))
                            Spacer()
                            Text(appSettingsManager.format(profile.targetAmount))
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(themeManager.current.accentColor)
                        }
                        .buxFormFieldPadding()
                    }
                }
            }
            .navigationTitle(profile.name.isEmpty ? "New Budget Rule" : "Edit Budget Rule")
            .navigationBarTitleDisplayMode(.inline)
            .buxThemedSheetContent()
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    BuxToolbarCancelButton { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    BuxToolbarSaveButton(isDirty: !profile.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
                        onSave(profile)
                        BuxSaveFeedback.success()
                        dismiss()
                    }
                }
            }
        }
    }

    private func addCategory() {
        guard let amount = Decimal(string: newCategoryTarget) else { return }
        let newCat = CustomBudgetCategory(name: newCategoryName, targetAmount: amount)
        profile.categories.append(newCat)
        profile.targetAmount = profile.categories.reduce(0) { $0 + $1.targetAmount }
        newCategoryName = ""
        newCategoryTarget = ""
    }

    private func removeCategory(id: UUID) {
        profile.categories.removeAll { $0.id == id }
        profile.targetAmount = profile.categories.reduce(0) { $0 + $1.targetAmount }
    }
}
