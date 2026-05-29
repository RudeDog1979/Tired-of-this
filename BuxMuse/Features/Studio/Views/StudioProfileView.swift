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

    var body: some View {
        StudioThemedListBackdrop {
            Form {
                Section("BUSINESS DETAILS") {
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
                        saveProfile()
                    }

                    TextField("Full Name", text: $displayName)
                    TextField("Business Name", text: $businessName)

                    Picker("Business Type", selection: $businessType) {
                        ForEach(BusinessType.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                }

                Section("GLOBAL LOCALE") {
                    HStack {
                        Text("Region & Currency")
                        Spacer()
                        Text("\(appSettingsManager.selectedCountry.flag) \(appSettingsManager.selectedCurrency.id)")
                            .buxLabelSecondary()
                    }
                    Text("Change in Settings → Currency & Region")
                        .font(.system(size: 11))
                        .buxLabelSecondary()
                }

                Section {
                    InvoicePartyEditorForm(
                        party: $party,
                        defaultCountryCode: appSettingsManager.selectedCountry.id,
                        showRegistrationFields: true
                    )
                } header: {
                    Text("INVOICE IDENTITY & ADDRESS")
                } footer: {
                    Text("Shown on invoice FROM block and legal footer.")
                        .font(.system(size: 11))
                }

                Section("INVOICING DEFAULTS") {
                    Stepper("Payment Terms: \(paymentTerms) Days", value: $paymentTerms, in: 0...120, step: 1)
                    HStack {
                        Text("Default Hourly Rate")
                        Spacer()
                        TextField("Rate", text: $hourlyRate)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .buxScrollDismissesKeyboard()
        }
        .navigationTitle("Business Profile")
        .navigationBarTitleDisplayMode(.inline)
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
