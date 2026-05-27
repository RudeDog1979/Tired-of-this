//
//  FreelanceTaxReferenceView.swift
//  BuxMuse
//
//  Unified Tax Profile — country preset, income type, and editable self-employed rules.
//

import SwiftUI

struct FreelanceTaxReferenceView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @EnvironmentObject private var store: FreelanceStore
    @EnvironmentObject private var appDataManager: AppDataManager

    @State private var showCountryPicker = false
    @State private var pickerSearchQuery = ""
    @State private var taxIncomeType: TaxIncomeType = .selfEmployed
    @State private var selectedPresetCode = ""
    @State private var customIncomeTax = ""
    @State private var customSelfEmployedTax = ""
    @State private var customIndirectTax = ""
    @State private var customNotes = ""
    @State private var indirectTaxRegistered = false
    @State private var paymentSchedule = "annually"
    @State private var estimatedIncomeRate = ""
    @State private var estimatedSERate = ""
    @State private var catalogReady = false
    @State private var saveBanner: String?
    @State private var showPresetReview = false
    @State private var pendingPreset: TaxInfo?

    private var registrationToggleLabel: String {
        var draft = store.taxProfile
        draft.customIndirectTax = customIndirectTax.isEmpty ? nil : customIndirectTax
        return IndirectTaxLabelResolver.registrationLabel(for: draft)
    }

    private var savedCountryLabel: String {
        if selectedPresetCode.isEmpty {
            return "Custom profile (no preset)"
        }
        if let preset = TaxPresetLoader.preset(for: selectedPresetCode) {
            return "\(preset.name) (\(preset.isoCode))"
        }
        return selectedPresetCode
    }

    var body: some View {
        ZStack {
            themeManager.screenBackground(for: colorScheme)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: BuxLayout.section) {
                    currencyBanner
                    presetDropdownSection
                    incomeTypeSection
                    registrationSection
                    paymentScheduleSection

                    if appDataManager.taxManagerRef.isLoading && !catalogReady {
                        loadingCatalogCard
                    }

                    editableFieldsSection
                    effectiveRatesSection

                    if let saveBanner {
                        Text(saveBanner)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.green)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 4)
                    }

                    TaxReferenceDisclaimerNote()
                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, BuxLayout.marginHorizontal)
                .padding(.top, BuxLayout.tight)
            }
        }
        .navigationTitle("Tax Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") { saveProfile() }
                    .fontWeight(.semibold)
            }
        }
        .task {
            await TaxPresetLoader.ensureCatalogLoaded()
            catalogReady = true
        }
        .onAppear {
            hydrateFromStore()
        }
        .sheet(isPresented: $showCountryPicker) {
            TaxCountryPickerSheet(searchQuery: $pickerSearchQuery) { preset in
                pendingPreset = preset
                showPresetReview = true
            }
            .environmentObject(themeManager)
        }
        .sheet(isPresented: $showPresetReview) {
            if let preset = pendingPreset {
                TaxPresetReviewSheet(preset: preset) {
                    applyPreset(preset)
                    pendingPreset = nil
                } onCancel: {
                    pendingPreset = nil
                }
                .environmentObject(themeManager)
            }
        }
    }

    // MARK: - Sections

    private var currencyBanner: some View {
        HStack(spacing: 10) {
            Text(appSettingsManager.selectedCountry.flag)
                .font(.system(size: 22))
            VStack(alignment: .leading, spacing: 2) {
                Text("Region & currency")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.gray)
                Text("\(appSettingsManager.selectedCountry.name) · \(appSettingsManager.selectedCurrency.name) (\(appSettingsManager.selectedCurrency.id))")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(colorScheme == .dark ? .white : Color(red: 26/255, green: 28/255, blue: 32/255))
            }
            Spacer()
            Text("From Settings")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.gray)
        }
        .padding(BuxLayout.section)
        .referenceCard
    }

    private var registrationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("INDIRECT TAX STATUS")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.gray)
                .kerning(0.8)

            Toggle(isOn: $indirectTaxRegistered) {
                Text(registrationToggleLabel)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(colorScheme == .dark ? .white : .black)
            }

            Text("Label updates from your indirect tax rules above (VAT, GST, ITBIS, etc.).")
                .font(.system(size: 11))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(BuxLayout.section)
        .referenceCard
    }

    private var paymentScheduleSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("TAX PAYMENT SCHEDULE")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.gray)
                .kerning(0.8)

            Picker("Payment schedule", selection: $paymentSchedule) {
                Text("Monthly").tag("monthly")
                Text("Quarterly").tag("quarterly")
                Text("Annually").tag("annually")
            }
            .pickerStyle(.segmented)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(BuxLayout.section)
        .referenceCard
    }

    private var presetDropdownSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("SUGGESTED TAX PRESET")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.gray)
                .kerning(0.8)

            Button {
                pickerSearchQuery = ""
                showCountryPicker = true
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Country preset")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.gray)
                        Text(savedCountryLabel)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(colorScheme == .dark ? .white : Color(red: 26/255, green: 28/255, blue: 32/255))
                            .multilineTextAlignment(.leading)
                    }
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(themeManager.current.accentColor)
                }
                .padding(14)
                .background(colorScheme == .dark ? Color.white.opacity(0.04) : Color.black.opacity(0.03))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)

            Button("Clear preset (custom only)") {
                selectedPresetCode = ""
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(themeManager.current.accentColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(BuxLayout.section)
        .referenceCard
    }

    private var incomeTypeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("HOW YOU EARN")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.gray)
                .kerning(0.8)

            Picker("Income type", selection: $taxIncomeType) {
                ForEach(TaxIncomeType.allCases) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)

            Text(taxIncomeType.summaryLabel)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(BuxLayout.section)
        .referenceCard
    }

    private var loadingCatalogCard: some View {
        HStack(spacing: 10) {
            ProgressView()
            Text("Loading country presets…")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(BuxLayout.section)
        .referenceCard
    }

    private var editableFieldsSection: some View {
        VStack(alignment: .leading, spacing: BuxLayout.section) {
            Text("YOUR TAX RULES")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.gray)
                .kerning(0.8)

            editorField(title: "Income Tax", text: $customIncomeTax, minHeight: 100)
            editorField(title: "Self-Employed Tax", text: $customSelfEmployedTax, minHeight: 100)
            editorField(title: "Indirect Tax", text: $customIndirectTax, minHeight: 80)
            editorField(title: "Notes", text: $customNotes, minHeight: 100)
        }
    }

    private var effectiveRatesSection: some View {
        VStack(alignment: .leading, spacing: BuxLayout.section) {
            Text("EFFECTIVE TAX RATES (FOR CALCULATOR)")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.gray)
                .kerning(0.8)

            VStack(alignment: .leading, spacing: 8) {
                Text("INCOME TAX RATE %")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.gray)
                TextField("e.g. 22", text: $estimatedIncomeRate)
                    .keyboardType(.decimalPad)
                    .padding(10)
                    .background(colorScheme == .dark ? Color.white.opacity(0.04) : Color.black.opacity(0.03))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(BuxLayout.section)
            .referenceCard

            VStack(alignment: .leading, spacing: 8) {
                Text("SELF-EMPLOYED TAX RATE %")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.gray)
                TextField("e.g. 15.3", text: $estimatedSERate)
                    .keyboardType(.decimalPad)
                    .padding(10)
                    .background(colorScheme == .dark ? Color.white.opacity(0.04) : Color.black.opacity(0.03))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                Text("These rates power the Income Tax Calculator and quarterly estimates. They are never auto-filled from JSON presets.")
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(BuxLayout.section)
            .referenceCard
        }
    }

    // MARK: - Actions

    private func hydrateFromStore() {
        let profile = store.taxProfile
        selectedPresetCode = profile.selectedTaxCountry ?? ""
        taxIncomeType = profile.taxIncomeType
        customIncomeTax = profile.customIncomeTax ?? ""
        customSelfEmployedTax = profile.customSelfEmployedTax ?? ""
        customIndirectTax = profile.customIndirectTax ?? ""
        customNotes = profile.customNotes ?? ""
        indirectTaxRegistered = profile.vatRegistered
        paymentSchedule = profile.paymentSchedule
        if let rate = profile.estimatedIncomeTaxRatePercent { estimatedIncomeRate = "\(rate)" }
        if let rate = profile.estimatedSelfEmployedRatePercent { estimatedSERate = "\(rate)" }
    }

    private func applyPreset(_ preset: TaxInfo) {
        selectedPresetCode = preset.isoCode
        customIncomeTax = preset.income_tax
        customSelfEmployedTax = preset.self_employed_tax
        customIndirectTax = preset.vat
        customNotes = preset.notes
    }

    private func saveProfile() {
        var profile = store.taxProfile
        profile.selectedTaxCountry = selectedPresetCode.isEmpty ? nil : selectedPresetCode
        profile.taxIncomeType = taxIncomeType
        profile.customIncomeTax = customIncomeTax.isEmpty ? nil : customIncomeTax
        profile.customSelfEmployedTax = customSelfEmployedTax.isEmpty ? nil : customSelfEmployedTax
        profile.customIndirectTax = customIndirectTax.isEmpty ? nil : customIndirectTax
        profile.customNotes = customNotes.isEmpty ? nil : customNotes
        profile.vatRegistered = indirectTaxRegistered
        profile.paymentSchedule = paymentSchedule
        profile.estimatedIncomeTaxRatePercent = Decimal(string: estimatedIncomeRate)
        profile.estimatedSelfEmployedRatePercent = Decimal(string: estimatedSERate)

        store.updateTaxProfile(profile)

        let countryPart = selectedPresetCode.isEmpty ? "Custom profile" : savedCountryLabel
        saveBanner = "Saved · \(countryPart) · \(taxIncomeType.rawValue) · \(appSettingsManager.selectedCurrency.id)"
    }

    // MARK: - UI helpers

    private func editorField(title: String, text: Binding<String>, minHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.gray)
            TextEditor(text: text)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(colorScheme == .dark ? .white : Color(red: 26/255, green: 28/255, blue: 32/255))
                .scrollContentBackground(.hidden)
                .frame(minHeight: minHeight)
                .padding(10)
                .background(colorScheme == .dark ? Color.white.opacity(0.04) : Color.black.opacity(0.03))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(BuxLayout.section)
        .referenceCard
    }
}

private extension View {
    var referenceCard: some View {
        modifier(FreelanceTaxReferenceCardModifier())
    }
}

// MARK: - Preset review sheet

struct TaxPresetReviewSheet: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager

    let preset: TaxInfo
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: BuxLayout.section) {
                    Text("Review \(preset.name) preset")
                        .font(.system(size: 18, weight: .bold))

                    Text("This fills your tax rule text fields only — effective rate percentages stay under your control.")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)

                    presetBlock("Income tax", preset.income_tax)
                    presetBlock("Self-employed tax", preset.self_employed_tax)
                    presetBlock("Indirect tax", preset.vat)
                    if !preset.notes.isEmpty {
                        presetBlock("Notes", preset.notes)
                    }

                    TaxReferenceDisclaimerNote()
                }
                .padding(BuxLayout.marginHorizontal)
            }
            .navigationTitle("Apply preset?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Apply") {
                        onConfirm()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func presetBlock(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.gray)
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(colorScheme == .dark ? .white : .black)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(BuxLayout.section)
        .background(colorScheme == .dark ? Color(red: 24/255, green: 26/255, blue: 32/255) : .white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

private struct FreelanceTaxReferenceCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager

    func body(content: Content) -> some View {
        content
            .background(colorScheme == .dark ? Color(red: 24/255, green: 26/255, blue: 32/255) : .white)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .buxCardOutline(themeManager: themeManager, colorScheme: colorScheme, cornerRadius: 20)
    }
}
