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
    @EnvironmentObject private var brain: BuxMuseBrain
    @EnvironmentObject private var tutorialCoordinator: AppTutorialCoordinator
    @ObservedObject private var store = SettingsStore.shared

    @State private var editingProfile: CustomBudgetProfile? = nil
    @State private var showCreator = false

    var body: some View {
        BuxThemedCardForm {
            BuxFormSection(title: "Budget setup") {
                BuxSettingsSegmentedEnumRow(titleKey: "How you budget", selection: $store.budgetingMode) {
                    ForEach(BudgetingMode.allCases.filter { $0 != .custom }) { mode in
                        Text(mode.catalogLabel(locale: appSettingsManager.interfaceLocale)).tag(mode)
                    }
                }
                .onAppear {
                    store.migrateLegacyCustomBudgetModeIfNeeded()
                    store.normalizeEnvelopeCategoryStorageIfNeeded()
                }
            }

            if store.studioEnabled, store.budgetingMode == .simple, store.studioMode == .simple, !store.includeSimpleStudioIncomeInBudget {
                BuxFormSection {
                    VStack(alignment: .leading, spacing: 8) {
                        BuxCatalogText.text("Simple Studio income")
                            .font(.system(size: 15, weight: .bold))
                        BuxCatalogDynamicText(key: "Counts money-in entries from Simple Studio toward this period's earned budget. Matching Add Income on the same day is counted once.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .buxFormFieldPadding()
                }
            }

            if store.studioEnabled, store.budgetingMode == .simple, store.studioMode == .pro, !store.includeProStudioIncomeInBudget {
                BuxFormSection {
                    VStack(alignment: .leading, spacing: 8) {
                        BuxCatalogText.text("Pro Studio income")
                            .font(.system(size: 15, weight: .bold))
                        BuxCatalogDynamicText(key: "Counts paid Pro Studio invoices toward this period's earned budget. Matching Add Income on the same day is counted once.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .buxFormFieldPadding()
                }
            }

            if store.budgetingMode == .simple || store.budgetingMode == .envelope {
                BuxFormSection(title: "Income & payday profile") {
                    BuxSettingsSegmentedEnumRow(titleKey: "What counts as income", selection: $store.incomeFundingSource) {
                        ForEach(IncomeFundingSource.allCases) { source in
                            Text(source.catalogLabel(locale: appSettingsManager.interfaceLocale)).tag(source)
                        }
                    }

                    BuxSettingsFootnote(key: "Only matching Add Income entries count toward your budget. Paycheck & salary: Salary and Paycheck labels. Freelance & other: gigs, Other income, and custom labels. Studio bridge dedup uses the same rule.")

                    BuxFormRowDivider()
                    BuxSettingsMenuPickerRow(titleKey: "When your budget resets", selection: $store.simpleBudgetCycle) {
                        ForEach(SimpleBudgetCycle.allCases) { cycle in
                            Text(cycle.catalogLabel(locale: appSettingsManager.interfaceLocale)).tag(cycle)
                        }
                    }

                    if store.simpleBudgetCycle.needsAnchorDate {
                        BuxFormRowDivider()
                        DatePicker(
                            selection: $store.simpleBudgetPeriodAnchor,
                            displayedComponents: .date
                        ) {
                            Text(BuxCatalogLabel.string("Period starts on", locale: appSettingsManager.interfaceLocale))
                        }
                        .tint(themeManager.contrastAccentColor(for: colorScheme))
                        .buxFormFieldPadding()
                    }

                    if store.budgetingMode == .simple {
                        BuxFormRowDivider()
                        BuxSettingsLabeledValueRow {
                            BuxCatalogDynamicText(key: "Optional spending cap")
                                .font(.system(size: 15, weight: .semibold))
                                .fixedSize(horizontal: false, vertical: true)
                        } value: {
                            TextField(BuxCatalogLabel.string("Amount", locale: appSettingsManager.interfaceLocale), value: $store.simpleBudgetLimit, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                                .font(.system(size: 16, weight: .bold))
                                .frame(minWidth: 120, maxWidth: 160)
                        }

                        BuxFormRowDivider()
                        BuxSettingsFootnote(key: "Log each payment when it arrives. Your limit comes from recorded income this period. Housing and utilities are essentials and do not reduce discretionary progress. Leave the cap at zero to use your full logged income. Auto-adjust tunes the optional cap from your spend history.")
                    }

                    if store.studioEnabled, store.budgetingMode == .simple, store.studioMode == .simple {
                        BuxFormRowDivider()
                        Toggle(isOn: $store.includeSimpleStudioIncomeInBudget) {
                            VStack(alignment: .leading, spacing: 4) {
                                BuxCatalogDynamicText(key: "Include Simple Studio income")
                                    .font(.system(size: 15, weight: .semibold))
                                BuxCatalogDynamicText(key: "Counts money-in entries from Simple Studio toward this period's earned budget. Matching Add Income on the same day is counted once.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .tint(themeManager.contrastAccentColor(for: colorScheme))
                        .buxFormFieldPadding()
                    }

                    if store.studioEnabled, store.budgetingMode == .simple, store.studioMode == .pro {
                        BuxFormRowDivider()
                        Toggle(isOn: $store.includeProStudioIncomeInBudget) {
                            VStack(alignment: .leading, spacing: 4) {
                                BuxCatalogDynamicText(key: "Include Pro Studio income")
                                    .font(.system(size: 15, weight: .semibold))
                                BuxCatalogDynamicText(key: "Counts paid Pro Studio invoices toward this period's earned budget. Matching Add Income on the same day is counted once.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .tint(themeManager.contrastAccentColor(for: colorScheme))
                        .buxFormFieldPadding()
                    }

                    if store.budgetingMode == .envelope {
                        BuxFormRowDivider()
                        BuxSettingsLabeledValueRow {
                            BuxCatalogDynamicText(key: "Spending limit this period")
                                .font(.system(size: 15, weight: .semibold))
                                .fixedSize(horizontal: false, vertical: true)
                        } value: {
                            TextField(BuxCatalogLabel.string("Amount", locale: appSettingsManager.interfaceLocale), value: $store.simpleBudgetLimit, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                                .font(.system(size: 16, weight: .bold))
                                .frame(minWidth: 120, maxWidth: 160)
                        }

                        BuxFormRowDivider()
                        BuxSettingsFootnote(key: "Your simple budget tracks expenses starting on your pay cycle—allowing you to measure spending relative to when your income arrives, rather than just the calendar month.")
                    }
                }
                .tutorialAnchor(.settingsBudgetPayPeriod, coordinator: tutorialCoordinator)
            }

            BuxFormSection(title: "Intelligence rules") {
                BuxSettingsToggleRow(
                    titleKey: "Show Budget Warnings",
                    isOn: $store.showBudgetWarnings
                )
                if store.budgetingMode == .simple {
                    BuxFormRowDivider()
                    Stepper(
                        value: $store.budgetApproachingThresholdPercent,
                        in: 50...95,
                        step: 5
                    ) {
                        Text(
                            BuxLocalizedString.format(
                                "Approaching threshold: %lld%%",
                                locale: appSettingsManager.interfaceLocale,
                                Int64(store.budgetApproachingThresholdPercent)
                            )
                        )
                    }
                    .buxFormFieldPadding()
                    BuxFormRowDivider()
                    BuxSettingsToggleRow(
                        titleKey: "Auto-adjust from history",
                        subtitleKey: "BuxMuse Brain will adjust your optional spending cap based on seasonal spend trends",
                        isOn: $store.autoAdjustBudgetsFromHistory
                    )
                }
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
                                    .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                            }
                            .buxSettingsRowInteraction()

                            Button(role: .destructive) {
                                deleteProfile(id: profile.id)
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 14, weight: .bold))
                            }
                            .buxSettingsRowInteraction()
                        }
                        .buxFormFieldPadding()
                    }
                }

                BuxFormRowDivider()
                Button(action: { showCreator = true }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        BuxCatalogDynamicText(key: "Add custom envelope profile")
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
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
            .environmentObject(brain)
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
            .environmentObject(brain)
            .buxThemedSheetContent()
            .environment(\.settingsEnhancedTint, true)
        }
        .onChange(of: store.budgetingMode) { _, _ in store.save() }
        .onChange(of: store.budgetApproachingThresholdPercent) { _, _ in store.save() }
        .onChange(of: store.defaultBudgetPeriod) { _, newValue in
            store.customBudgetPeriod = newValue
            store.save()
        }
        .onChange(of: store.showBudgetWarnings) { _, _ in store.save() }
        .onChange(of: store.autoAdjustBudgetsFromHistory) { _, _ in store.save() }
        .onChange(of: store.simpleBudgetLimit) { _, _ in
            store.budgetQuickSetupCompleted = true
            store.save()
        }
        .onChange(of: store.simpleBudgetCycle) { _, _ in store.save() }
        .onChange(of: store.simpleBudgetPeriodAnchor) { _, _ in store.save() }
        .onChange(of: store.incomeFundingSource) { _, _ in store.save() }
        .onChange(of: store.includeSimpleStudioIncomeInBudget) { _, _ in store.save() }
        .onChange(of: store.includeProStudioIncomeInBudget) { _, _ in store.save() }
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

private struct BudgetCategoryOption: Identifiable, Hashable {
    let id: String
    let label: String
    /// Stable English key or custom user name — never a localized picker label.
    let storageName: String
    let categoryId: UUID?
    let systemCategoryRaw: String?
}

struct BudgetProfileEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @EnvironmentObject private var brain: BuxMuseBrain

    @State var profile: CustomBudgetProfile
    let onSave: (CustomBudgetProfile) -> Void

    @State private var selectedCategoryOptionID: String?
    @State private var newCategoryTarget = ""
    @State private var showCreateCategory = false

    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.screenBackground(for: colorScheme).ignoresSafeArea()
                BuxThemedCardForm {
                    BuxFormSection(title: "Profile details") {
                        TextField(BuxCatalogLabel.string("Profile Name (e.g. Summer Travel)", locale: appSettingsManager.interfaceLocale), text: $profile.name)
                            .font(.system(size: 15, weight: .semibold))
                            .buxFormFieldPadding()
                        BuxFormRowDivider()
                        Toggle(isOn: $profile.isActive) {
                            Text(BuxCatalogLabel.string("Active Budget Rule", locale: appSettingsManager.interfaceLocale))
                        }
                            .tint(themeManager.contrastAccentColor(for: colorScheme))
                            .buxFormFieldPadding()
                        BuxFormRowDivider()
                        Toggle(isOn: $profile.rolloverEnabled) {
                            Text(BuxCatalogLabel.string("Enable Category Rollover", locale: appSettingsManager.interfaceLocale))
                        }
                            .tint(themeManager.contrastAccentColor(for: colorScheme))
                            .buxFormFieldPadding()
                        BuxFormRowDivider()
                        Stepper(
                            value: $profile.approachingThresholdPercent,
                            in: 50...95,
                            step: 5
                        ) {
                            Text(
                                BuxLocalizedString.format(
                                    "Approaching threshold: %lld%%",
                                    locale: appSettingsManager.interfaceLocale,
                                    Int64(profile.approachingThresholdPercent)
                                )
                            )
                        }
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
                                    Text(
                                        category.localizedDisplayName(
                                            categoryRecords: (try? brain.fetchAllCategoryRecords()) ?? [],
                                            locale: appSettingsManager.interfaceLocale
                                        )
                                    )
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
                                    .buxSettingsRowInteraction()
                                }
                                .buxFormFieldPadding()
                            }
                        }
                    }

                    BuxFormSection(title: "Add category") {
                        Picker(
                            BuxCatalogLabel.string("Expense category", locale: appSettingsManager.interfaceLocale),
                            selection: $selectedCategoryOptionID
                        ) {
                            Text(BuxCatalogLabel.string("Choose category", locale: appSettingsManager.interfaceLocale)).tag(Optional<String>.none)
                            ForEach(categoryOptions) { option in
                                Text(option.label).tag(Optional(option.id))
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(themeManager.contrastAccentColor(for: colorScheme))
                        .buxFormFieldPadding()
                        BuxFormRowDivider()
                        HStack {
                            TextField(BuxCatalogLabel.string("Target Limit Amount", locale: appSettingsManager.interfaceLocale), text: $newCategoryTarget)
                                .keyboardType(.decimalPad)
                            Spacer()
                            Button(action: addCategory) {
                                BuxCatalogDynamicText(key: "Add")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                            }
                            .disabled(selectedCategoryOptionID == nil || newCategoryTarget.isEmpty)
                        }
                        .buxFormFieldPadding()
                        BuxFormRowDivider()
                        Button {
                            showCreateCategory = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                BuxCatalogText.text("Create category")
                                    .font(.system(size: 15, weight: .semibold))
                                Spacer()
                            }
                            .foregroundStyle(themeManager.contrastAccentColor(for: colorScheme))
                        }
                        .buxSettingsRowInteraction()
                        .buxFormFieldPadding()
                    }

                    BuxFormSection(title: "Summary") {
                        HStack {
                            BuxCatalogDynamicText(key: "Total budget limit")
                                .font(.system(size: 15, weight: .bold))
                            Spacer()
                            Text(appSettingsManager.format(profile.targetAmount))
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                        }
                        .buxFormFieldPadding()
                    }
                }
            }
            .buxCatalogNavigationTitle(profile.name.isEmpty ? "New budget rule" : "Edit budget rule")
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
        .sheet(isPresented: $showCreateCategory) {
            ExpenseCategoryEditorSheet { name, icon, color in
                if let created = try? brain.createCategory(name: name, icon: icon, color: color) {
                    selectedCategoryOptionID = "custom-\(created.id.uuidString)"
                }
            }
            .environmentObject(themeManager)
            .environmentObject(appSettingsManager)
        }
    }

    private var categoryOptions: [BudgetCategoryOption] {
        let locale = appSettingsManager.interfaceLocale
        var options: [BudgetCategoryOption] = []
        for system in TransactionCategory.allCases where system != .income {
            options.append(BudgetCategoryOption(
                id: "system-\(system.rawValue)",
                label: system.localizedDisplayName(locale: locale),
                storageName: system.catalogLabelKey,
                categoryId: nil,
                systemCategoryRaw: system.rawValue
            ))
        }
        for custom in ((try? brain.fetchAllCategoryRecords()) ?? []).filter(\.isCustom) {
            options.append(BudgetCategoryOption(
                id: "custom-\(custom.id.uuidString)",
                label: custom.localizedDisplayName(locale: locale),
                storageName: custom.name,
                categoryId: custom.id,
                systemCategoryRaw: custom.systemCategoryRaw
            ))
        }
        return options
    }

    private func addCategory() {
        guard let amount = Decimal(string: newCategoryTarget),
              let optionID = selectedCategoryOptionID,
              let option = categoryOptions.first(where: { $0.id == optionID }) else { return }
        let newCat = CustomBudgetCategory(
            name: option.storageName,
            targetAmount: amount,
            categoryId: option.categoryId,
            systemCategoryRaw: option.systemCategoryRaw
        )
        profile.categories.append(newCat)
        profile.targetAmount = profile.categories.reduce(0) { $0 + $1.targetAmount }
        selectedCategoryOptionID = nil
        newCategoryTarget = ""
    }

    private func removeCategory(id: UUID) {
        profile.categories.removeAll { $0.id == id }
        profile.targetAmount = profile.categories.reduce(0) { $0 + $1.targetAmount }
    }
}
