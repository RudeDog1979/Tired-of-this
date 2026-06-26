//
//  StudioProfileView.swift
//  BuxMuse
//
//  In-hub business profile editor — identity and invoicing defaults only.
//

import SwiftUI

struct StudioProfileView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @EnvironmentObject private var store: StudioStore

    @State private var displayName = ""
    @State private var businessName = ""
    @State private var party = InvoicePartyDetails()
    @State private var businessType: BusinessType = .freelancer
    @State private var paymentTerms = 30
    @State private var hourlyRate = ""
    @State private var logoData: Data?

    private var locale: Locale { appSettingsManager.interfaceLocale }

    private func loc(_ key: String) -> String {
        BuxCatalogLabel.string(key, locale: locale)
    }

    var body: some View {
        StudioThemedListBackdrop {
            BuxThemedCardForm {
                StudioProToolScreenHeader(titleKey: "Business Profile")
                    .studioProToolScrollPlacementEmbedded()

                BuxFormSection(title: "Business details") {
                    PhotoPickCropRow(
                        title: loc("Company Logo"),
                        subtitle: loc("Shown on exported invoice PDFs"),
                        imageData: logoData,
                        cropShape: .roundedRectangle(cornerRadius: 12),
                        cropTitle: loc("Crop Logo"),
                        previewSize: 64,
                        previewCornerRadius: 12
                    ) { data in
                        logoData = data
                        saveProfile()
                    }
                    .buxFormFieldPadding()
                    BuxFormRowDivider()
                    TextField(loc("Full Name"), text: $displayName)
                        .buxFormFieldPadding()
                    BuxFormRowDivider()
                    TextField(loc("Business Name"), text: $businessName)
                        .buxFormFieldPadding()
                    BuxFormRowDivider()
                    Picker(loc("Business Type"), selection: $businessType) {
                        ForEach(BusinessType.allCases) { type in
                            Text(type.catalogLabel(locale: appSettingsManager.interfaceLocale)).tag(type)
                        }
                    }
                    .tint(themeManager.contrastAccentColor(for: colorScheme))
                    .buxFormFieldPadding()
                }

                BuxFormSection(title: "Global locale") {
                    HStack {
                        BuxCatalogDynamicText(key: "Region & Currency")
                        Spacer()
                        Text(
                            BuxLocalizedString.format(
                                "%@ %@",
                                locale: appSettingsManager.interfaceLocale,
                                appSettingsManager.selectedCountry.flag,
                                appSettingsManager.selectedCurrency.id
                            )
                        )
                            .buxLabelSecondary()
                    }
                    .buxFormFieldPadding()
                    BuxCatalogDynamicText(key: "Change in Settings → Currency & Region")
                        .font(.system(size: 11))
                        .buxLabelSecondary()
                        .buxFormFieldPadding()
                }

                BuxFormSection(title: "Invoice identity & address") {
                    InvoicePartyEditorFields(
                        party: $party,
                        showRegistrationFields: true
                    )
                    BuxCatalogDynamicText(key: "Shown on invoice FROM block and legal footer.")
                        .font(.system(size: 11))
                        .buxLabelSecondary()
                        .buxFormFieldPadding()
                }

                BuxFormSection(title: "Invoicing defaults") {
                    Stepper(
                        BuxLocalizedString.format("Payment Terms: %lld Days", locale: locale, Int64(paymentTerms)),
                        value: $paymentTerms,
                        in: 0...120,
                        step: 1
                    )
                        .tint(themeManager.contrastAccentColor(for: colorScheme))
                        .buxFormFieldPadding()
                    BuxFormRowDivider()
                    HStack {
                        BuxCatalogDynamicText(key: "Default Hourly Rate")
                        Spacer()
                        TextField(loc("Rate"), text: $hourlyRate)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                    .buxFormFieldPadding()
                }
            }
            .studioProToolScrollTopInset()
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .buxRootNavigationChrome()
        .onAppear { loadProfile() }
        .onChange(of: displayName) { _, _ in saveProfile() }
        .onChange(of: businessName) { _, _ in saveProfile() }
        .onChange(of: party) { _, _ in saveProfile() }
        .onChange(of: businessType) { _, _ in saveProfile() }
        .onChange(of: paymentTerms) { _, _ in saveProfile() }
        .onChange(of: hourlyRate) { _, _ in saveProfile() }
    }

    private func loadProfile() {
        let p = store.profile
        displayName = p.displayName
        businessName = p.businessName
        party = p.resolvedPartyDetails()
        if party.countryCode.isEmpty {
            party.countryCode = appSettingsManager.selectedCountry.id
        }
        businessType = p.businessType
        paymentTerms = p.defaultInvoicePaymentTerms
        logoData = p.logoData
        hourlyRate = p.defaultHourlyRate.map { "\($0)" } ?? ""
    }

    private func saveProfile() {
        var profile = store.profile
        profile.displayName = displayName
        profile.businessName = businessName
        profile.applyPartyDetails(party)
        profile.businessType = businessType
        profile.defaultInvoicePaymentTerms = paymentTerms
        profile.logoData = logoData
        profile.defaultHourlyRate = Decimal(string: hourlyRate)
        store.updateProfile(profile)
    }
}
