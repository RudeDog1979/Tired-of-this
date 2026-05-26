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
    
    private var bgColor: Color {
        themeManager.screenBackground(for: colorScheme)
    }
    
    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()
            
            Form {
                Section("BUDGET METHOD") {
                    Picker("Budgeting Mode", selection: $store.budgetingMode) {
                        ForEach(BudgetingMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.vertical, 4)
                    
                    if store.budgetingMode == .simple {
                        HStack {
                            Text("Monthly Spending Limit")
                                .font(.system(size: 15, weight: .semibold))
                            Spacer()
                            TextField("Amount", value: $store.simpleBudgetLimit, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .foregroundColor(themeManager.current.accentColor)
                                .font(.system(size: 16, weight: .bold))
                                .frame(width: 120)
                        }
                    } else if store.budgetingMode == .custom {
                        HStack {
                            Text("Spending Cap")
                                .font(.system(size: 15, weight: .semibold))
                            Spacer()
                            TextField("Amount", value: $store.customBudgetLimit, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .foregroundColor(themeManager.current.accentColor)
                                .font(.system(size: 16, weight: .bold))
                                .frame(width: 120)
                        }
                        
                        Picker("Budget Period", selection: $store.customBudgetPeriod) {
                            ForEach(DefaultBudgetPeriod.allCases) { period in
                                Text(period.rawValue).tag(period)
                            }
                        }
                        .pickerStyle(.menu)
                    } else {
                        Picker("Default Cycle", selection: $store.defaultBudgetPeriod) {
                            ForEach(DefaultBudgetPeriod.allCases) { period in
                                Text(period.rawValue).tag(period)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }
                
                Section("INTELLIGENCE RULES") {
                    Toggle("Show Budget Warnings", isOn: $store.showBudgetWarnings)
                    
                    Toggle(isOn: $store.autoAdjustBudgetsFromHistory) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Auto-adjust from History")
                                .font(.system(size: 15, weight: .semibold))
                            Text("BuxMuse Brain will adjust limits based on seasonal spend trends")
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                        }
                    }
                }
                
                Section("CUSTOM ENVELOPE PROFILES") {
                    if store.customBudgetProfiles.isEmpty {
                        Text("No custom profiles configured.")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                            .padding(.vertical, 4)
                    } else {
                        ForEach(store.customBudgetProfiles) { profile in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 8) {
                                        Text(profile.name)
                                            .font(.system(size: 15, weight: .bold))
                                            .foregroundColor(colorScheme == .dark ? .white : .black)
                                        if profile.isActive {
                                            Text("Active")
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(themeManager.current.accentColor)
                                                .clipShape(Capsule())
                                        }
                                    }
                                    Text("\(profile.categories.count) Categories · Target: \(appSettingsManager.format(profile.targetAmount))")
                                        .font(.system(size: 12))
                                        .foregroundColor(.gray)
                                }
                                
                                Spacer()
                                
                                Button(action: { editingProfile = profile }) {
                                    Image(systemName: "pencil")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(themeManager.current.accentColor)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.vertical, 4)
                        }
                        .onDelete(perform: deleteProfile)
                    }
                    
                    Button(action: { showCreator = true }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Custom Envelope Profile")
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(themeManager.current.accentColor)
                    }
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Budgets")
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
        }
        .onChange(of: store.budgetingMode) { _, _ in store.save() }
        .onChange(of: store.defaultBudgetPeriod) { _, _ in store.save() }
        .onChange(of: store.showBudgetWarnings) { _, _ in store.save() }
        .onChange(of: store.autoAdjustBudgetsFromHistory) { _, _ in store.save() }
        .onChange(of: store.simpleBudgetLimit) { _, _ in store.save() }
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
    
    private func deleteProfile(at offsets: IndexSet) {
        store.customBudgetProfiles.remove(atOffsets: offsets)
        // If the active profile was deleted, activate the first remaining one
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
                themeManager.screenBackground(for: colorScheme)
                    .ignoresSafeArea()
                
                Form {
                    Section("PROFILE GENERAL DETAILS") {
                        TextField("Profile Name (e.g. Summer Travel)", text: $profile.name)
                            .font(.system(size: 15, weight: .semibold))
                        
                        Toggle("Active Budget Rule", isOn: $profile.isActive)
                        Toggle("Enable Category Rollover", isOn: $profile.rolloverEnabled)
                    }
                    
                    Section("ENVELOPE CATEGORIES") {
                        if profile.categories.isEmpty {
                            Text("No categories added yet.")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                        } else {
                            ForEach(profile.categories) { category in
                                HStack {
                                    Text(category.name)
                                        .font(.system(size: 14, weight: .bold))
                                    Spacer()
                                    Text(appSettingsManager.format(category.targetAmount))
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.gray)
                                }
                            }
                            .onDelete(perform: removeCategory)
                        }
                    }
                    
                    Section("ADD NEW CATEGORY") {
                        TextField("Category Name", text: $newCategoryName)
                        HStack {
                            TextField("Target Limit Amount", text: $newCategoryTarget)
                                .keyboardType(.decimalPad)
                            Spacer()
                            Button(action: addCategory) {
                                Text("Add")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(themeManager.current.accentColor)
                            }
                            .disabled(newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || newCategoryTarget.isEmpty)
                        }
                    }
                    
                    Section("SUMMARY") {
                        HStack {
                            Text("Total Budget Limit")
                                .font(.system(size: 15, weight: .bold))
                            Spacer()
                            Text(appSettingsManager.format(profile.targetAmount))
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(themeManager.current.accentColor)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(profile.name.isEmpty ? "New Budget Rule" : "Edit Budget Rule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave(profile)
                        dismiss()
                    }
                    .disabled(profile.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
    
    private func removeCategory(at offsets: IndexSet) {
        profile.categories.remove(atOffsets: offsets)
        profile.targetAmount = profile.categories.reduce(0) { $0 + $1.targetAmount }
    }
}
