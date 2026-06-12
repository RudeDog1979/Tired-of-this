//
//  StudioTaxReferenceView.swift
//  BuxMuse
//
//  Unified Tax Profile — country preset, income type, and editable self-employed rules.
//

import SwiftUI

struct StudioTaxReferenceView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.studioHubEmbedded) private var studioHubEmbedded
    @Environment(\.taxStudioProfileSaveBridge) private var taxStudioProfileSaveBridge
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @EnvironmentObject private var store: StudioStore
    @EnvironmentObject private var appDataManager: AppDataManager

    @State private var showCountryPicker = false
    @State private var taxIncomeType: TaxIncomeType = .selfEmployed
    @State private var selectedPresetCode = ""
    @State private var selectedRegionCode = ""
    @State private var customIncomeTax = ""
    @State private var customSelfEmployedTax = ""
    @State private var customIndirectTax = ""
    @State private var customNotes = ""
    @State private var indirectTaxRegistered = false
    @State private var paymentSchedule = "annually"
    @State private var estimatedIncomeRate = ""
    @State private var estimatedSERate = ""
    @State private var estimatedIndirectRate = ""
    @State private var catalogReady = false
    @State private var saveBanner: String?
    @State private var lastSavedDraft: TaxProfileDraft?
    /// Selected in country picker; promoted to `presetToReview` after picker dismisses.
    @State private var stagingPreset: TaxInfo?
    @State private var presetToReview: TaxInfo?
    @State private var savedPresetSummaryText: String?

    private var registrationToggleLabel: String {
        var draft = store.taxProfile
        draft.customIndirectTax = customIndirectTax.isEmpty ? nil : customIndirectTax
        return IndirectTaxLabelResolver.registrationLabel(for: draft, locale: appSettingsManager.interfaceLocale)
    }

    private var savedCountryLabel: String {
        if selectedPresetCode.isEmpty {
            return BuxCatalogLabel.string("Custom profile (no preset)", locale: appSettingsManager.interfaceLocale)
        }
        if let preset = TaxPresetLoader.preset(for: selectedPresetCode) {
            return TaxCountryDisplayName.pickerLabel(for: preset, locale: appSettingsManager.interfaceLocale)
        }
        return selectedPresetCode
    }

    private var catalogUpdatedLabel: String? {
        appDataManager.taxManagerRef.catalogUpdatedAt.map {
            BuxLocalizedString.format("Reference updated %@", locale: appSettingsManager.interfaceLocale, $0)
        }
    }

    private var computeCatalogUpdatedLabel: String? {
        TaxComputeCatalogStore.shared.catalogUpdatedAt.map {
            BuxLocalizedString.format("Compute rules updated %@", locale: appSettingsManager.interfaceLocale, $0)
        }
    }

    private var availableTaxRegions: [TaxComputeRegion] {
        guard !selectedPresetCode.isEmpty else { return [] }
        return TaxComputeCatalogStore.shared.regions(for: selectedPresetCode)
    }

    private var currentDraft: TaxProfileDraft {
        TaxProfileDraft(
            selectedPresetCode: selectedPresetCode,
            selectedRegionCode: selectedRegionCode,
            taxIncomeType: taxIncomeType,
            customIncomeTax: customIncomeTax,
            customSelfEmployedTax: customSelfEmployedTax,
            customIndirectTax: customIndirectTax,
            customNotes: customNotes,
            indirectTaxRegistered: indirectTaxRegistered,
            paymentSchedule: paymentSchedule,
            estimatedIncomeRate: estimatedIncomeRate,
            estimatedSERate: estimatedSERate,
            estimatedIndirectRate: estimatedIndirectRate
        )
    }

    private var hasUnsavedChanges: Bool {
        guard let lastSavedDraft else { return true }
        return lastSavedDraft != currentDraft
    }

    var body: some View {
        Group {
            if studioHubEmbedded {
                taxProfileContent
            } else {
                ZStack {
                    themeManager.screenBackground(for: colorScheme)
                        .ignoresSafeArea()

                    ScrollView(showsIndicators: false) {
                        taxProfileContent
                    }
                }
                .buxCatalogNavigationTitle("Tax profile")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        BuxToolbarSaveButton(isDirty: hasUnsavedChanges) {
                            saveProfile()
                        }
                    }
                }
            }
        }
        .background {
            TaxTranslationSessionBridgeView()
        }
        .onAppear {
            hydrateFromStore()
            if studioHubEmbedded, let bridge = taxStudioProfileSaveBridge {
                bridge.bindSave { saveProfile() }
                bridge.setDirty(hasUnsavedChanges)
            }
        }
        .onDisappear {
            taxStudioProfileSaveBridge?.unbind()
        }
        .onChange(of: hasUnsavedChanges) { _, dirty in
            taxStudioProfileSaveBridge?.setDirty(dirty)
        }
        .task {
            await TaxPresetLoader.ensureCatalogLoaded()
            catalogReady = true
            await refreshSavedPresetSummary()
        }
        .onChange(of: taxIncomeType) { _, _ in
            if selectedRegionCode.isEmpty, let first = availableTaxRegions.first?.code {
                selectedRegionCode = first
            }
        }
        .onChange(of: selectedPresetCode) { _, _ in
            Task { await refreshSavedPresetSummary() }
        }
        .onChange(of: appDataManager.taxManagerRef.catalogUpdatedAt) { _, _ in
            Task { await refreshSavedPresetSummary() }
        }
        .onChange(of: appSettingsManager.interfaceLocale.identifier) { oldID, _ in
            Task {
                await relocalizeTaxFields(from: Locale(identifier: oldID))
                await refreshSavedPresetSummary()
            }
        }
        .sheet(isPresented: $showCountryPicker, onDismiss: {
            guard let staged = stagingPreset else { return }
            presetToReview = staged
            stagingPreset = nil
        }) {
            TaxCountryPickerSheet { preset in
                stagingPreset = preset
            }
            .environmentObject(themeManager)
            .buxStudioSheetContent()
        }
        .sheet(item: $presetToReview) { preset in
            TaxPresetReviewSheet(preset: preset) { englishPreset in
                applyPreset(englishPreset)
                presetToReview = nil
                Task { await refreshSavedPresetSummary() }
            } onCancel: {
                presetToReview = nil
            }
            .environmentObject(themeManager)
            .environmentObject(appSettingsManager)
            .environment(\.studioEnhancedTint, true)
            .buxStudioSheetContent()
        }
    }

    // MARK: - Sections

    private var taxProfileContent: some View {
        VStack(alignment: .leading, spacing: BuxLayout.section) {
            currencyBanner
            presetDropdownSection
            if !availableTaxRegions.isEmpty {
                taxRegionSection
            }
            taxIdentitySection
            paymentScheduleSection
            complianceNoticesSection

            if appDataManager.taxManagerRef.isLoading && !catalogReady {
                loadingCatalogCard
            }

            editableFieldsSection
            if showManualEffectiveRates {
                effectiveRatesSection
            } else {
                catalogRatesInfoCard
            }

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
        .studioHubEmbeddedHorizontalPadding()
        .padding(.top, BuxLayout.tight)
        .environment(\.studioEnhancedTint, true)
    }

    private var currencyBanner: some View {
        HStack(spacing: 10) {
            Text(appSettingsManager.selectedCountry.flag)
                .font(.system(size: 22))
            VStack(alignment: .leading, spacing: 2) {
                BuxCatalogDynamicText(key: "Region & currency")
                    .font(.system(size: 10, weight: .bold))
                    .buxLabelSecondary()
                Text(
                    BuxLocalizedString.format(
                        "%@ · %@ (%@)",
                        locale: appSettingsManager.interfaceLocale,
                        appSettingsManager.selectedCountry.name,
                        appSettingsManager.selectedCurrency.name,
                        appSettingsManager.selectedCurrency.id
                    )
                )
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(themeManager.labelPrimary(for: colorScheme))
            }
            Spacer()
            BuxCatalogDynamicText(key: "From Settings")
                .font(.system(size: 10, weight: .medium))
                .buxLabelSecondary()
        }
        .padding(BuxLayout.section)
        .referenceCard
    }

    private var taxRegionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            BuxCatalogDynamicText(key: "Tax region")
                .font(.system(size: 11, weight: .bold))
                .buxLabelSecondary()
                .kerning(0.8)

            Picker(
                BuxCatalogLabel.string("Tax region", locale: appSettingsManager.interfaceLocale),
                selection: $selectedRegionCode
            ) {
                BuxCatalogDynamicText(key: "National default").tag("")
                ForEach(availableTaxRegions, id: \.code) { region in
                    Text(region.name).tag(region.code)
                }
            }
            .pickerStyle(.menu)

            if let computeCatalogUpdatedLabel {
                Text(computeCatalogUpdatedLabel)
                    .font(.system(size: 10, weight: .medium))
                    .buxLabelSecondary()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(BuxLayout.section)
        .referenceCard
    }

    private var taxIdentitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            BuxCatalogDynamicText(key: "Tax identity")
                .font(.system(size: 11, weight: .bold))
                .buxLabelSecondary()
                .kerning(0.8)

            BuxCatalogDynamicText(key: "Income tax and indirect tax (VAT/GST) are configured together. Invoices and calculators follow these settings.")
                .font(.system(size: 11))
                .buxLabelSecondary()

            incomeTypeSectionInline

            Toggle(isOn: $indirectTaxRegistered) {
                Text(registrationToggleLabel)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(themeManager.labelPrimary(for: colorScheme))
            }

            BuxCatalogDynamicText(key: "Turn on only if you are registered to charge VAT, GST, ITBIS, or similar on invoices.")
                .font(.system(size: 11))
                .buxLabelSecondary()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(BuxLayout.section)
        .referenceCard
    }

    private var incomeTypeSectionInline: some View {
        VStack(alignment: .leading, spacing: 8) {
            BuxCatalogDynamicText(key: "Income path")
                .font(.system(size: 10, weight: .bold))
                .buxLabelSecondary()
            Picker("", selection: $taxIncomeType) {
                ForEach(TaxIncomeType.allCases) { type in
                    Text(type.catalogLabel(locale: appSettingsManager.interfaceLocale)).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .buxThemedSegmentedPicker()
            Text(taxIncomeType.catalogSummaryLabel(locale: appSettingsManager.interfaceLocale))
                .font(.system(size: 11, weight: .medium))
                .buxLabelSecondary()
        }
    }

    private var complianceNoticesSection: some View {
        let notices = TaxComplianceAdvisor.notices(
            taxProfile: store.taxProfile,
            invoices: store.invoices,
            locale: appSettingsManager.interfaceLocale
        )
        return Group {
            if !notices.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    BuxCatalogDynamicText(key: "Tax checks")
                        .font(.system(size: 11, weight: .bold))
                        .buxLabelSecondary()
                    ForEach(notices) { notice in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: notice.severity == .warning ? "exclamationmark.triangle.fill" : "info.circle.fill")
                                .foregroundColor(notice.severity == .warning ? .orange : themeManager.contrastAccentColor(for: colorScheme))
                            Text(BuxCatalogLabel.string(notice.messageKey, locale: appSettingsManager.interfaceLocale))
                                .font(.system(size: 12))
                                .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(BuxLayout.section)
                .referenceCard
            }
        }
    }

    private var paymentScheduleSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            BuxCatalogDynamicText(key: "Tax payment schedule")
                .font(.system(size: 11, weight: .bold))
                .buxLabelSecondary()
                .kerning(0.8)

            Picker(BuxCatalogLabel.string("Payment schedule", locale: appSettingsManager.interfaceLocale), selection: $paymentSchedule) {
                BuxCatalogDynamicText(key: "Monthly").tag("monthly")
                BuxCatalogDynamicText(key: "Quarterly").tag("quarterly")
                BuxCatalogDynamicText(key: "Annually").tag("annually")
            }
            .pickerStyle(.segmented)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(BuxLayout.section)
        .referenceCard
    }

    private var presetDropdownSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            BuxCatalogDynamicText(key: "Suggested tax preset")
                .font(.system(size: 11, weight: .bold))
                .buxLabelSecondary()
                .kerning(0.8)

            TaxTranslationPackNoticeBanner()
                .environmentObject(appSettingsManager)

            Button {
                showCountryPicker = true
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        BuxCatalogDynamicText(key: "Country preset")
                            .font(.system(size: 11, weight: .medium))
                            .buxLabelSecondary()
                        Text(savedCountryLabel)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                            .multilineTextAlignment(.leading)
                        if let savedPresetSummaryText {
                            Text(savedPresetSummaryText)
                                .font(.system(size: 11, weight: .medium))
                                .buxLabelSecondary()
                                .multilineTextAlignment(.leading)
                                .lineLimit(3)
                        }
                        if let catalogUpdatedLabel {
                            Text(catalogUpdatedLabel)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(themeManager.contrastAccentColor(for: colorScheme).opacity(0.85))
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                }
                .padding(14)
                .buxThemedInputPlate(cornerRadius: 12)
            }
            .buttonStyle(BuxPressFeedbackStyle())

            BuxButton(
                title: "Clear preset (custom only)",
                systemImage: "xmark.circle",
                role: .secondary,
                size: .compact
            ) {
                selectedPresetCode = ""
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(BuxLayout.section)
        .referenceCard
    }

    private var loadingCatalogCard: some View {
        HStack(spacing: 10) {
            ProgressView()
            BuxCatalogDynamicText(key: "Loading country presets…")
                .font(.system(size: 12, weight: .medium))
                .buxLabelSecondary()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(BuxLayout.section)
        .referenceCard
    }

    private var editableFieldsSection: some View {
        VStack(alignment: .leading, spacing: BuxLayout.section) {
            BuxCatalogDynamicText(key: "Your tax rules")
                .font(.system(size: 11, weight: .bold))
                .buxLabelSecondary()
                .kerning(0.8)

            editorField(title: BuxCatalogLabel.string("Income tax", locale: appSettingsManager.interfaceLocale), text: $customIncomeTax, minHeight: 100)
            editorField(title: BuxCatalogLabel.string("Self-employed tax", locale: appSettingsManager.interfaceLocale), text: $customSelfEmployedTax, minHeight: 100)
            editorField(title: BuxCatalogLabel.string("Indirect tax", locale: appSettingsManager.interfaceLocale), text: $customIndirectTax, minHeight: 80)
            editorField(title: BuxCatalogLabel.string("Notes", locale: appSettingsManager.interfaceLocale), text: $customNotes, minHeight: 100)
        }
    }

    private var showManualEffectiveRates: Bool {
        let profile = draftTaxProfileForVisibility
        return TaxCatalogProfileHydrator.shouldShowManualIncomeRate(for: profile)
            || TaxCatalogProfileHydrator.shouldShowManualSelfEmployedRate(for: profile)
            || TaxCatalogProfileHydrator.shouldShowManualIndirectRate(for: profile)
    }

    private var draftTaxProfileForVisibility: StudioTaxProfile {
        var profile = store.taxProfile
        profile.selectedTaxCountry = selectedPresetCode.isEmpty ? nil : selectedPresetCode
        profile.regionCode = selectedRegionCode.isEmpty ? nil : selectedRegionCode
        profile.taxIncomeType = taxIncomeType
        if !selectedPresetCode.isEmpty {
            TaxCatalogProfileHydrator.applyCatalogRules(
                to: &profile,
                countryCode: selectedPresetCode,
                regionCode: profile.regionCode
            )
        }
        return profile
    }

    private var catalogRatesInfoCard: some View {
        VStack(alignment: .leading, spacing: BuxLayout.section) {
            BuxCatalogDynamicText(key: "Tax rates from catalog")
                .font(.system(size: 11, weight: .bold))
                .buxLabelSecondary()
                .kerning(0.8)

            BuxCatalogDynamicText(key: "Income tax, social contributions, and VAT/GST are computed from structured rules in the monthly tax catalog. Manual effective % overrides are hidden while catalog brackets apply.")
                .font(.system(size: 11))
                .buxLabelSecondary()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(BuxLayout.section)
        .referenceCard
    }

    private var effectiveRatesSection: some View {
        VStack(alignment: .leading, spacing: BuxLayout.section) {
            BuxCatalogDynamicText(key: "Effective tax rates (for calculator)")
                .font(.system(size: 11, weight: .bold))
                .buxLabelSecondary()
                .kerning(0.8)

            if TaxCatalogProfileHydrator.shouldShowManualIncomeRate(for: draftTaxProfileForVisibility) {
                VStack(alignment: .leading, spacing: 8) {
                    BuxCatalogDynamicText(key: "Income tax rate %")
                        .font(.system(size: 10, weight: .bold))
                        .buxLabelSecondary()
                    TextField(BuxCatalogLabel.string("e.g. 22", locale: appSettingsManager.interfaceLocale), text: $estimatedIncomeRate)
                        .keyboardType(.decimalPad)
                        .padding(10)
                        .buxThemedInputPlate(cornerRadius: 12)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(BuxLayout.section)
                .referenceCard
            }

            if TaxCatalogProfileHydrator.shouldShowManualSelfEmployedRate(for: draftTaxProfileForVisibility) {
                VStack(alignment: .leading, spacing: 8) {
                    BuxCatalogDynamicText(key: "Self-employed tax rate %")
                        .font(.system(size: 10, weight: .bold))
                        .buxLabelSecondary()
                    TextField(BuxCatalogLabel.string("e.g. 15.3", locale: appSettingsManager.interfaceLocale), text: $estimatedSERate)
                        .keyboardType(.decimalPad)
                        .padding(10)
                        .buxThemedInputPlate(cornerRadius: 12)
                    BuxCatalogDynamicText(key: "These rates power the Income Tax Calculator and quarterly estimates. They are never auto-filled from JSON presets.")
                        .font(.system(size: 11))
                        .buxLabelSecondary()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(BuxLayout.section)
                .referenceCard
            }

            if TaxCatalogProfileHydrator.shouldShowManualIndirectRate(for: draftTaxProfileForVisibility) {
                VStack(alignment: .leading, spacing: 8) {
                    BuxCatalogDynamicText(key: "Indirect tax rate % (VAT/GST)")
                        .font(.system(size: 10, weight: .bold))
                        .buxLabelSecondary()
                    TextField(BuxCatalogLabel.string("e.g. 20", locale: appSettingsManager.interfaceLocale), text: $estimatedIndirectRate)
                        .keyboardType(.decimalPad)
                        .padding(10)
                        .buxThemedInputPlate(cornerRadius: 12)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(BuxLayout.section)
                .referenceCard
            }
        }
    }

    // MARK: - Actions

    private func hydrateFromStore() {
        let profile = store.taxProfile
        selectedPresetCode = profile.selectedTaxCountry ?? ""
        selectedRegionCode = profile.regionCode ?? ""
        taxIncomeType = profile.taxIncomeType
        indirectTaxRegistered = profile.vatRegistered
        paymentSchedule = profile.paymentSchedule
        if let rate = profile.estimatedIncomeTaxRatePercent { estimatedIncomeRate = "\(rate)" }
        if let rate = profile.estimatedSelfEmployedRatePercent { estimatedSERate = "\(rate)" }
        if let rate = profile.estimatedIndirectTaxRatePercent { estimatedIndirectRate = "\(rate)" }
        Task { await refreshDisplayedTaxFields() }
    }

    private func applyPreset(_ preset: TaxInfo) {
        selectedPresetCode = preset.isoCode
        let regions = TaxComputeCatalogStore.shared.regions(for: preset.isoCode)
        selectedRegionCode = regions.count == 1 ? (regions.first?.code ?? "") : ""
        if let schedule = TaxCatalogProfileHydrator.catalogPaymentSchedule(
            countryCode: preset.isoCode,
            regionCode: selectedRegionCode.isEmpty ? nil : selectedRegionCode
        ) {
            paymentSchedule = schedule
        }
        Task { await applyPresetFields(preset) }
    }

    @MainActor
    private func applyDisplayedFields(_ fields: TaxProfileTextFields, syncSavedDraft: Bool = false) {
        customIncomeTax = fields.incomeTax
        customSelfEmployedTax = fields.selfEmployedTax
        customIndirectTax = fields.indirectTax
        customNotes = fields.notes
        if syncSavedDraft {
            lastSavedDraft = currentDraft
        }
    }

    private func refreshDisplayedTaxFields() async {
        var canonical = TaxProfileTextFields(profile: store.taxProfile)
        canonical = await TaxPresetTranslator.recoverEnglishFromLegacyTranslation(
            canonical,
            presetCode: store.taxProfile.selectedTaxCountry,
            catalogUpdatedAt: appDataManager.taxManagerRef.catalogUpdatedAt
        )
        let display = await TaxPresetTranslator.localizedProfileFields(
            canonical,
            interfaceLocale: appSettingsManager.interfaceLocale
        )
        await MainActor.run {
            applyDisplayedFields(display, syncSavedDraft: true)
        }
    }

    private func applyPresetFields(_ preset: TaxInfo) async {
        let canonical = TaxProfileTextFields(
            incomeTax: preset.income_tax,
            selfEmployedTax: preset.self_employed_tax,
            indirectTax: preset.vat,
            notes: preset.notes
        )
        let display = await TaxPresetTranslator.localizedProfileFields(
            canonical,
            interfaceLocale: appSettingsManager.interfaceLocale
        )
        await MainActor.run {
            applyDisplayedFields(display)
        }
    }

    private func relocalizeTaxFields(from previousLocale: Locale) async {
        let current = TaxProfileTextFields(
            incomeTax: customIncomeTax,
            selfEmployedTax: customSelfEmployedTax,
            indirectTax: customIndirectTax,
            notes: customNotes
        )
        let canonical = await TaxPresetTranslator.canonicalProfileFields(
            current,
            interfaceLocale: previousLocale
        )
        let display = await TaxPresetTranslator.localizedProfileFields(
            canonical,
            interfaceLocale: appSettingsManager.interfaceLocale
        )
        await MainActor.run {
            applyDisplayedFields(display)
        }
    }

    private func refreshSavedPresetSummary() async {
        guard !selectedPresetCode.isEmpty,
              let preset = TaxPresetLoader.preset(for: selectedPresetCode) else {
            savedPresetSummaryText = nil
            return
        }
        let result = await TaxPresetLocalizationSupport.localized(
            preset,
            catalogUpdatedAt: appDataManager.taxManagerRef.catalogUpdatedAt,
            interfaceLocale: appSettingsManager.interfaceLocale
        )
        savedPresetSummaryText = result.preset.presetLineSummary
    }

    private func saveProfile() {
        Task {
            let display = TaxProfileTextFields(
                incomeTax: customIncomeTax,
                selfEmployedTax: customSelfEmployedTax,
                indirectTax: customIndirectTax,
                notes: customNotes
            )
            let canonical = await TaxPresetTranslator.canonicalProfileFields(
                display,
                interfaceLocale: appSettingsManager.interfaceLocale
            )

            await MainActor.run {
                var profile = store.taxProfile
                profile.selectedTaxCountry = selectedPresetCode.isEmpty ? nil : selectedPresetCode
                profile.taxIncomeType = taxIncomeType
                profile.customIncomeTax = canonical.incomeTax.isEmpty ? nil : canonical.incomeTax
                profile.customSelfEmployedTax = canonical.selfEmployedTax.isEmpty ? nil : canonical.selfEmployedTax
                profile.customIndirectTax = canonical.indirectTax.isEmpty ? nil : canonical.indirectTax
                profile.customNotes = canonical.notes.isEmpty ? nil : canonical.notes
                profile.vatRegistered = indirectTaxRegistered
                profile.regionCode = selectedRegionCode.isEmpty ? nil : selectedRegionCode

                if !selectedPresetCode.isEmpty {
                    TaxCatalogProfileHydrator.applyCatalogRules(
                        to: &profile,
                        countryCode: selectedPresetCode,
                        regionCode: profile.regionCode
                    )
                }

                profile.paymentSchedule = paymentSchedule

                if TaxCatalogProfileHydrator.shouldShowManualIncomeRate(for: profile) {
                    profile.estimatedIncomeTaxRatePercent = Decimal(string: estimatedIncomeRate)
                } else {
                    profile.estimatedIncomeTaxRatePercent = nil
                }
                if TaxCatalogProfileHydrator.shouldShowManualSelfEmployedRate(for: profile) {
                    profile.estimatedSelfEmployedRatePercent = Decimal(string: estimatedSERate)
                } else {
                    profile.estimatedSelfEmployedRatePercent = nil
                }
                if TaxCatalogProfileHydrator.shouldShowManualIndirectRate(for: profile) {
                    profile.estimatedIndirectTaxRatePercent = Decimal(string: estimatedIndirectRate)
                } else {
                    profile.estimatedIndirectTaxRatePercent = nil
                }

                store.updateTaxProfile(profile)

                lastSavedDraft = currentDraft
                BuxSaveFeedback.success()

                let countryPart = selectedPresetCode.isEmpty
                    ? BuxCatalogLabel.string("Custom profile", locale: appSettingsManager.interfaceLocale)
                    : savedCountryLabel
                saveBanner = BuxLocalizedString.format(
                    "Saved · %@ · %@ · %@",
                    locale: appSettingsManager.interfaceLocale,
                    countryPart,
                    taxIncomeType.catalogLabel(locale: appSettingsManager.interfaceLocale),
                    appSettingsManager.selectedCurrency.id
                )
            }
        }
    }

    // MARK: - UI helpers

    private func editorField(title: String, text: Binding<String>, minHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .buxLabelSecondary()
            TextEditor(text: text)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                .scrollContentBackground(.hidden)
                .frame(minHeight: minHeight)
                .padding(10)
                .buxThemedInputPlate(cornerRadius: 12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(BuxLayout.section)
        .referenceCard
    }
}

private struct TaxProfileDraft: Equatable {
    var selectedPresetCode: String
    var selectedRegionCode: String
    var taxIncomeType: TaxIncomeType
    var customIncomeTax: String
    var customSelfEmployedTax: String
    var customIndirectTax: String
    var customNotes: String
    var indirectTaxRegistered: Bool
    var paymentSchedule: String
    var estimatedIncomeRate: String
    var estimatedSERate: String
    var estimatedIndirectRate: String
}

private extension View {
    var referenceCard: some View {
        modifier(StudioTaxReferenceCardModifier())
    }
}

// MARK: - Preset review sheet

struct TaxPresetReviewSheet: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @ObservedObject private var taxManager = TaxManager.shared

    let preset: TaxInfo
    let onConfirm: (TaxInfo) -> Void
    let onCancel: () -> Void

    @State private var displayPreset: TaxInfo
    @State private var isTranslating = false
    @State private var showEnglishBadge = false

    init(
        preset: TaxInfo,
        onConfirm: @escaping (TaxInfo) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.preset = preset
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        _displayPreset = State(initialValue: preset)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.screenBackground(for: colorScheme).ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: BuxLayout.section) {
                        Text(
                            BuxLocalizedString.format(
                                "Review %@ preset",
                                locale: appSettingsManager.interfaceLocale,
                                TaxCountryDisplayName.displayName(
                                    for: preset,
                                    locale: appSettingsManager.interfaceLocale
                                )
                            )
                        )
                            .font(.system(size: 18, weight: .bold))

                        TaxTranslationPackNoticeBanner()
                            .environmentObject(appSettingsManager)

                        BuxCatalogDynamicText(key: "This fills your tax rule text fields only — effective rate percentages stay under your control.")
                            .font(.system(size: 12))
                            .buxLabelSecondary()

                        if isTranslating {
                            ProgressView()
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 8)
                        }

                        presetBlock(
                            BuxCatalogLabel.string("Income tax", locale: appSettingsManager.interfaceLocale),
                            displayPreset.income_tax
                        )
                        presetBlock(
                            BuxCatalogLabel.string("Self-employed tax", locale: appSettingsManager.interfaceLocale),
                            displayPreset.self_employed_tax
                        )
                        presetBlock(
                            BuxCatalogLabel.string("Indirect tax", locale: appSettingsManager.interfaceLocale),
                            displayPreset.vat
                        )
                        if !displayPreset.notes.isEmpty {
                            presetBlock(
                                BuxCatalogLabel.string("Notes", locale: appSettingsManager.interfaceLocale),
                                displayPreset.notes
                            )
                        }

                        TaxReferenceDisclaimerNote()
                    }
                    .padding(BuxLayout.marginHorizontal)
                }
            }
            .background {
                TaxTranslationSessionBridgeView()
            }
            .task(id: translationTaskKey) {
                isTranslating = TaxPresetTranslator.translationTargetTag(
                    for: appSettingsManager.interfaceLocale
                ) != nil
                let result = await TaxPresetLocalizationSupport.localized(
                    preset,
                    catalogUpdatedAt: taxManager.catalogUpdatedAt,
                    interfaceLocale: appSettingsManager.interfaceLocale
                )
                displayPreset = result.preset
                let packInstalled = await TaxTranslationUX.isLanguagePackInstalled(
                    for: appSettingsManager.interfaceLocale
                )
                showEnglishBadge = TaxTranslationUX.shouldShowEnglishBadge(
                    source: preset,
                    displayed: result.preset,
                    packInstalled: packInstalled,
                    interfaceLocale: appSettingsManager.interfaceLocale
                )
                isTranslating = false
            }
            .buxCatalogNavigationTitle("Apply preset?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    BuxToolbarCancelButton {
                        onCancel()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    BuxToolbarConfirmButton(accessibilityLabel: "Apply") {
                        onConfirm(preset)
                        dismiss()
                    }
                }
            }
            .environment(\.studioEnhancedTint, true)
        }
    }

    private var translationTaskKey: String {
        TaxPresetLocalizationSupport.taskKey(
            preset: preset,
            catalogUpdatedAt: taxManager.catalogUpdatedAt,
            locale: appSettingsManager.interfaceLocale
        )
    }

    private func presetBlock(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 6) {
                Text(title)
                    .font(.system(size: 10, weight: .bold))
                    .buxLabelSecondary()
                if showEnglishBadge, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    TaxEnglishFallbackBadge()
                        .environmentObject(appSettingsManager)
                }
            }
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(themeManager.labelPrimary(for: colorScheme))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(BuxLayout.section)
        .studioThemedCardChrome(cornerRadius: 16)
    }
}

private struct StudioTaxReferenceCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager

    func body(content: Content) -> some View {
        content
            .studioThemedCardChrome(cornerRadius: 20)
    }
}
