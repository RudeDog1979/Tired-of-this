//
//  InvoicePartyEditorForm.swift
//  BuxMuse
//
//  Structured issuer/recipient fields for Studio profile & clients.
//

import SwiftUI

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
                    Text("\(country.flag) \(country.name)").tag(country.id)
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
