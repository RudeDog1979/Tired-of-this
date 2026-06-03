//
//  InvoicePartyEditorForm.swift
//  BuxMuse
//
//  Structured issuer/recipient fields for Studio profile & clients.
//

import SwiftUI

/// Card-layout fields (use inside `BuxFormSection`).
struct InvoicePartyEditorFields: View {
    @Binding var party: InvoicePartyDetails
    var showRegistrationFields: Bool

    var body: some View {
        groupLabel("Identity")
        Toggle("Company / organization", isOn: $party.isOrganization)
            .buxFormFieldPadding()
        if party.isOrganization {
            BuxFormRowDivider()
            TextField("Organization name", text: $party.organizationName)
                .buxFormFieldPadding()
            BuxFormRowDivider()
            TextField("Trading name (optional)", text: $party.tradeName)
                .buxFormFieldPadding()
        }
        BuxFormRowDivider()
        TextField("Given / first name(s)", text: $party.givenNames)
            .buxFormFieldPadding()
        BuxFormRowDivider()
        TextField("Additional name(s)", text: $party.additionalNames)
            .buxFormFieldPadding()
        BuxFormRowDivider()
        TextField("Family / surname(s)", text: $party.familyNames)
            .buxFormFieldPadding()

        BuxFormRowDivider()
        groupLabel("Contact")
        TextField("Email", text: $party.email)
            .keyboardType(.emailAddress)
            .textInputAutocapitalization(.never)
            .buxFormFieldPadding()
        BuxFormRowDivider()
        TextField("Phone", text: $party.phone)
            .keyboardType(.phonePad)
            .buxFormFieldPadding()

        BuxFormRowDivider()
        groupLabel("Address")
        TextField("Address line 1", text: $party.addressLine1)
            .buxFormFieldPadding()
        BuxFormRowDivider()
        TextField("Address line 2", text: $party.addressLine2)
            .buxFormFieldPadding()
        BuxFormRowDivider()
        Picker("Country", selection: $party.countryCode) {
            ForEach(CountryCatalog.allCountries) { country in
                Text(
                    BuxLocalizedString.format(
                        "%@ %@",
                        locale: BuxInterfaceLocale.currentInterfaceLocale,
                        country.flag,
                        country.name
                    )
                )
                .tag(country.id)
            }
        }
        .buxFormFieldPadding()
        if InvoiceAddressRules.requiresSubdivision(for: party.countryCode) {
            BuxFormRowDivider()
            TextField(InvoiceAddressRules.subdivisionLabel(for: party.countryCode), text: $party.subdivision)
                .buxFormFieldPadding()
        }
        BuxFormRowDivider()
        TextField(InvoiceAddressRules.postalCodeLabel(for: party.countryCode), text: $party.postalCode)
            .buxFormFieldPadding()

        if showRegistrationFields {
            BuxFormRowDivider()
            groupLabel("Registration")
            TextField("Business registration no.", text: $party.businessRegistrationNumber)
                .buxFormFieldPadding()
            BuxFormRowDivider()
            TextField("Tax / VAT registration no.", text: $party.taxRegistrationNumber)
                .buxFormFieldPadding()
        }
    }

    private func groupLabel(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .bold))
            .buxLabelSecondary()
            .padding(.horizontal, BuxLayout.section)
            .padding(.top, 10)
            .padding(.bottom, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Legacy Form sections — prefer `InvoicePartyEditorFields` in card layouts.
struct InvoicePartyEditorForm: View {
    @Binding var party: InvoicePartyDetails
    var defaultCountryCode: String
    var showRegistrationFields: Bool

    var body: some View {
        Section("Identity") {
            Toggle("Company / organization", isOn: $party.isOrganization)
            if party.isOrganization {
                TextField("Organization name", text: $party.organizationName)
                TextField("Trading name (optional)", text: $party.tradeName)
            }
            TextField("Given / first name(s)", text: $party.givenNames)
            TextField("Additional name(s)", text: $party.additionalNames)
            TextField("Family / surname(s)", text: $party.familyNames)
        }

        Section("Contact") {
            TextField("Email", text: $party.email)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
            TextField("Phone", text: $party.phone)
                .keyboardType(.phonePad)
        }

        Section("Address") {
            TextField("Address line 1", text: $party.addressLine1)
            TextField("Address line 2", text: $party.addressLine2)
            Picker("Country", selection: $party.countryCode) {
                ForEach(CountryCatalog.allCountries) { country in
                    Text(
                        BuxLocalizedString.format(
                            "%@ %@",
                            locale: BuxInterfaceLocale.currentInterfaceLocale,
                            country.flag,
                            country.name
                        )
                    )
                    .tag(country.id)
                }
            }
            if InvoiceAddressRules.requiresSubdivision(for: party.countryCode) {
                TextField(InvoiceAddressRules.subdivisionLabel(for: party.countryCode), text: $party.subdivision)
            }
            TextField(InvoiceAddressRules.postalCodeLabel(for: party.countryCode), text: $party.postalCode)
        }

        if showRegistrationFields {
            Section("Registration") {
                TextField("Business registration no.", text: $party.businessRegistrationNumber)
                TextField("Tax / VAT registration no.", text: $party.taxRegistrationNumber)
            }
        }
    }
}
