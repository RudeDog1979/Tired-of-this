//
//  StudioSettingsView.swift
//  BuxMuse
//
//  Freelance Hub master preferences — business identity and invoicing defaults.
//  Region, currency, and tax registration live in global Settings / Tax Profile.
//

import SwiftUI

struct StudioSettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @EnvironmentObject private var appDataManager: AppDataManager
    @EnvironmentObject private var navigationCoordinator: NavigationCoordinator
    @ObservedObject private var store = SettingsStore.shared
    @EnvironmentObject private var studioStore: StudioStore
    @EnvironmentObject private var simpleStudioStore: SimpleStudioStore

    @State private var displayName = ""
    @State private var businessName = ""
    @State private var businessType: BusinessType = .freelancer
    @State private var paymentTerms = 30
    @State private var hourlyRate = ""
    @State private var logoData: Data?

    private var studioToggleOn: Bool {
        store.studioEnabled || navigationCoordinator.studioUnlockAwaitingCommit
    }

    var body: some View {
        BuxThemedCardForm {
            if !store.studioEnabled {
                BuxFormSection {
                    BuxCatalogDynamicText(key: "Studio adds work tracking, simple invoices, and job pockets. Turn it on when you need it — Home and Expenses stay the same.")
                        .font(.system(size: 12, weight: .medium))
                        .buxLabelSecondary()
                        .fixedSize(horizontal: false, vertical: true)
                        .buxFormFieldPadding()
                }
            }

            BuxFormSection(title: "Studio") {
                Toggle(isOn: studioToggleBinding) {
                    VStack(alignment: .leading, spacing: 2) {
                        BuxCatalogDynamicText(key: "Show Studio Tab")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                        BuxCatalogDynamicText(key: "Simple work ledger or full Pro tools")
                            .font(.system(size: 11))
                            .buxLabelSecondary()
                    }
                }
                .tint(themeManager.current.accentColor)
                .buxFormFieldPadding()
            }

            if store.studioEnabled {
                BuxFormSection(title: "Studio mode") {
                    Picker("Mode", selection: $store.studioMode) {
                        BuxCatalogDynamicText(key: "Simple Studio").tag(StudioMode.simple)
                        BuxCatalogDynamicText(key: "Pro Studio").tag(StudioMode.pro)
                    }
                    .buxThemedSegmentedPicker()
                    .buxFormFieldPadding()
                    .onChange(of: store.studioMode) { _, newMode in
                        if newMode == .pro {
                            _ = SimpleStudioUpgradeCoordinator.upgradeToPro(
                                simpleStore: simpleStudioStore,
                                studioStore: studioStore,
                                settings: store,
                                currencyCode: appSettingsManager.selectedCurrency.id
                            )
                        } else {
                            store.save()
                        }
                    }

                    HStack(spacing: 10) {
                        if store.studioMode == .pro {
                            StudioTierWordmark(style: .badge)
                        } else {
                            BuxCatalogDynamicText(key: "Simple")
                                .font(.system(size: 11, weight: .heavy, design: .rounded))
                                .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(themeManager.labelSecondary(for: colorScheme).opacity(0.12))
                                .clipShape(Capsule())
                        }
                        Text(store.studioMode.subtitle)
                            .font(.system(size: 11, weight: .medium))
                            .buxLabelSecondary()
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .buxFormFieldPadding()
                }

                BuxFormSection(title: "Work type") {
                    Picker("Persona", selection: $store.studioPersona) {
                        ForEach(StudioPersona.allCases) { persona in
                            Text(persona.title).tag(persona)
                        }
                    }
                    .tint(themeManager.current.accentColor)
                    .buxFormFieldPadding()
                    .onChange(of: store.studioPersona) { _, _ in
                        store.studioPersonaConfigured = true
                        store.save()
                    }
                }

                if store.studioMode == .pro {
                    BuxFormSection(title: "Brand") {
                        NavigationLink {
                            ProBusinessCardStudioView()
                                .environmentObject(themeManager)
                                .environmentObject(studioStore)
                                .environmentObject(simpleStudioStore)
                        } label: {
                            HStack {
                                BuxCatalogDynamicText(key: "Business Card Studio")
                                    .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                                Spacer()
                                Text(
                                    BuxLocalizedString.format(
                                        "%lld designs",
                                        locale: appSettingsManager.interfaceLocale,
                                        Int64(studioStore.businessCardLibrary.savedDesigns.count)
                                    )
                                )
                                    .font(.system(size: 12, weight: .semibold))
                                    .buxLabelSecondary()
                                BuxChevron()
                            }
                        }
                        .buxFormFieldPadding()
                    }
                }

                BuxFormSection(title: "Business profile") {
                    PhotoPickCropRow(
                        title: "Company Logo",
                        subtitle: "Shown on exported invoice PDFs",
                        imageData: logoData,
                        cropShape: .roundedRectangle(cornerRadius: 12),
                        cropTitle: "Crop Logo",
                        previewSize: 64,
                        previewCornerRadius: 12
                    ) { data in
                        logoData = data
                        saveStudioProfile()
                    }
                    .buxFormFieldPadding()
                    BuxFormRowDivider()
                    TextField("Full Name", text: $displayName)
                        .buxFormFieldPadding()
                    BuxFormRowDivider()
                    TextField("Business Name", text: $businessName)
                        .buxFormFieldPadding()
                    BuxFormRowDivider()
                    Picker("Business Type", selection: $businessType) {
                        ForEach(BusinessType.allCases) { type in
                            Text(type.catalogLabel(locale: appSettingsManager.interfaceLocale)).tag(type)
                        }
                    }
                    .tint(themeManager.current.accentColor)
                    .buxFormFieldPadding()
                }

                BuxFormSection(title: "Global locale") {
                    NavigationLink {
                        RegionCurrencySettingsView()
                    } label: {
                        HStack {
                            BuxCatalogDynamicText(key: "Region & Currency")
                                .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                            Spacer()
                            Text(
                                BuxLocalizedString.format(
                                    "%@ %@ · %@",
                                    locale: appSettingsManager.interfaceLocale,
                                    appSettingsManager.selectedCountry.flag,
                                    appSettingsManager.selectedCountry.name,
                                    appSettingsManager.selectedCurrency.id
                                )
                            )
                                .font(.system(size: 12, weight: .semibold))
                                .buxLabelSecondary()
                                .lineLimit(1)
                            BuxChevron()
                        }
                    }
                    .buxFormFieldPadding()
                    BuxFormRowDivider()
                    NavigationLink {
                        StudioTaxReferenceView()
                            .environmentObject(themeManager)
                            .environmentObject(appSettingsManager)
                            .environmentObject(appDataManager)
                            .environmentObject(studioStore)
                    } label: {
                        HStack {
                            BuxCatalogDynamicText(key: "Tax Profile")
                                .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                            Spacer()
                            if studioStore.taxProfile.isTaxProfileConfigured {
                                Text(studioStore.taxProfile.selectedTaxCountry ?? "Custom")
                                    .font(.system(size: 12, weight: .semibold))
                                    .buxLabelSecondary()
                            } else {
                                BuxCatalogDynamicText(key: "Not configured")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.orange)
                            }
                            BuxChevron()
                        }
                    }
                    .buxFormFieldPadding()
                }

                BuxFormSection(title: "Invoicing defaults") {
                    Stepper("Payment Terms: \(paymentTerms) Days", value: $paymentTerms, in: 0...120, step: 1)
                        .tint(themeManager.current.accentColor)
                        .buxFormFieldPadding()
                    BuxFormRowDivider()
                    HStack {
                        BuxCatalogDynamicText(key: "Default Hourly Rate")
                        Spacer()
                        TextField("Rate", text: $hourlyRate)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                    .buxFormFieldPadding()
                }

                studioToolsSection
            }
        }
        .buxCatalogNavigationTitle("Studio")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadStudioProfile() }
        .onChange(of: store.studioEnabled) { _, isEnabled in
            if isEnabled {
                loadStudioProfile()
            } else {
                store.save()
            }
        }
        .onChange(of: displayName) { _, _ in saveStudioProfile() }
        .onChange(of: businessName) { _, _ in saveStudioProfile() }
        .onChange(of: businessType) { _, _ in saveStudioProfile() }
        .onChange(of: paymentTerms) { _, _ in saveStudioProfile() }
        .onChange(of: hourlyRate) { _, _ in saveStudioProfile() }
    }

    private var studioToolsSection: some View {
        BuxFormSection(title: "Studio tools") {
            studioToolLink(title: "Workspaces", subtitle: workspaceSubtitle, icon: "briefcase.fill") {
                HustleSettingsView()
                    .environmentObject(themeManager)
                    .environmentObject(appSettingsManager)
                    .environmentObject(studioStore)
                    .environmentObject(simpleStudioStore)
            }
            BuxFormRowDivider()
            studioToolLink(title: "Cash & Barter", subtitle: cashBarterSubtitle, icon: "banknote.fill") {
                StudioCashBarterSettingsView()
                    .environmentObject(themeManager)
            }
            BuxFormRowDivider()
            studioToolLink(title: "Workload & Energy", subtitle: store.burnoutGuardEnabled ? "On" : "Off", icon: "bolt.heart.fill") {
                BurnoutGuardSettingsView()
                    .environmentObject(themeManager)
                    .environmentObject(appSettingsManager)
                    .environmentObject(studioStore)
                    .environmentObject(simpleStudioStore)
            }
            BuxFormRowDivider()
            studioToolLink(title: "Invoice Payment", subtitle: invoicePaymentSubtitle, icon: "building.columns.fill") {
                InvoicePaymentSettingsView()
            }
            BuxFormRowDivider()
            studioToolLink(title: "Mileage Log", subtitle: store.autoLocationForMileage ? "On" : "Off", icon: "car.fill") {
                MileageSettingsView()
            }
            if store.studioMode == .pro {
                BuxFormRowDivider()
                studioToolLink(title: "Scope Radar", subtitle: store.antiScopeCreepEnabled ? "On" : "Off", icon: "scope") {
                    ScopeCreepRadarSettingsView()
                        .environmentObject(themeManager)
                }
                BuxFormRowDivider()
                studioToolLink(title: "Agreement Scratchpad", subtitle: store.agreementScratchpadEnabled ? "On" : "Off", icon: "doc.text.fill") {
                    AgreementScratchpadSettingsView()
                        .environmentObject(themeManager)
                }
            }
        }
    }

    private var workspaceSubtitle: String {
        guard store.sideHustleMatrixEnabled else { return "Off" }
        return store.studioMode == .pro ? "On · Unlimited" : "On · Up to 3"
    }

    private var cashBarterSubtitle: String {
        let parts = [
            store.dualCashDrawerEnabled ? "Cash on" : nil,
            store.barterLoggerEnabled ? "Barter on" : nil
        ].compactMap { $0 }
        return parts.isEmpty ? "Off" : parts.joined(separator: " · ")
    }

    private var invoicePaymentSubtitle: String {
        store.autoDetectInvoiceBankAccountType ? "Auto" : (store.invoiceBankAccountTypeOverride?.displayName ?? "Manual")
    }

    private func studioToolLink<Destination: View>(
        title: String,
        subtitle: String,
        icon: String,
        @ViewBuilder destination: () -> Destination
    ) -> some View {
        NavigationLink {
            destination()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(themeManager.current.accentColor)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .buxLabelSecondary()
                }
                Spacer()
                BuxChevron()
            }
            .buxFormFieldPadding()
        }
    }

    private var studioToggleBinding: Binding<Bool> {
        Binding(
            get: { studioToggleOn },
            set: { enabled in
                if enabled {
                    guard !store.studioEnabled else { return }
                    navigationCoordinator.beginStudioUnlock()
                } else {
                    navigationCoordinator.cancelStudioUnlockIfPending()
                    store.studioEnabled = false
                    store.save()
                }
            }
        )
    }

    private func loadStudioProfile() {
        let p = studioStore.profile
        displayName = p.displayName
        businessName = p.businessName
        businessType = p.businessType
        paymentTerms = p.defaultInvoicePaymentTerms
        logoData = p.logoData
        hourlyRate = p.defaultHourlyRate.map { "\($0)" } ?? ""
    }

    private func saveStudioProfile() {
        var profile = studioStore.profile
        profile.displayName = displayName
        profile.businessName = businessName
        profile.businessType = businessType
        profile.defaultInvoicePaymentTerms = paymentTerms
        profile.logoData = logoData
        profile.defaultHourlyRate = Decimal(string: hourlyRate)
        studioStore.updateProfile(profile)
    }
}
