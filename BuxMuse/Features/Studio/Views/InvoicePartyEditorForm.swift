//
//  InvoicePartyEditorForm.swift
//  BuxMuse
//
//  Structured issuer/recipient fields for Studio profile & clients.
//

import SwiftUI

/// Card-layout fields (use inside `BuxFormSection`).
struct InvoicePartyEditorFields: View {
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    @Binding var party: InvoicePartyDetails
    var showRegistrationFields: Bool

    private var locale: Locale { appSettingsManager.interfaceLocale }

    private func loc(_ key: String) -> String {
        BuxCatalogLabel.string(key, locale: locale)
    }

    var body: some View {
        groupLabel("Identity")
        Toggle(loc("Company / organization"), isOn: $party.isOrganization)
            .buxFormFieldPadding()
        if party.isOrganization {
            BuxFormRowDivider()
            TextField(loc("Organization name"), text: $party.organizationName)
                .buxFormFieldPadding()
            BuxFormRowDivider()
            TextField(loc("Trading name (optional)"), text: $party.tradeName)
                .buxFormFieldPadding()
        }
        BuxFormRowDivider()
        TextField(loc("Given / first name(s)"), text: $party.givenNames)
            .buxFormFieldPadding()
        BuxFormRowDivider()
        TextField(loc("Additional name(s)"), text: $party.additionalNames)
            .buxFormFieldPadding()
        BuxFormRowDivider()
        TextField(loc("Family / surname(s)"), text: $party.familyNames)
            .buxFormFieldPadding()

        BuxFormRowDivider()
        groupLabel("Contact")
        TextField(loc("Email"), text: $party.email)
            .keyboardType(.emailAddress)
            .textInputAutocapitalization(.never)
            .buxFormFieldPadding()
        BuxFormRowDivider()
        TextField(loc("Phone"), text: $party.phone)
            .keyboardType(.phonePad)
            .buxFormFieldPadding()

        BuxFormRowDivider()
        groupLabel("Address")
        TextField(loc("Address line 1"), text: $party.addressLine1)
            .buxFormFieldPadding()
        BuxFormRowDivider()
        TextField(loc("Address line 2"), text: $party.addressLine2)
            .buxFormFieldPadding()
        BuxFormRowDivider()
        Picker(loc("Country"), selection: $party.countryCode) {
            ForEach(CountryCatalog.allCountries) { country in
                Text(
                    BuxLocalizedString.format(
                        "%@ %@",
                        locale: locale,
                        country.flag,
                        CountryDisplayL10n.displayName(for: country, locale: locale)
                    )
                )
                .tag(country.id)
            }
        }
        .buxFormFieldPadding()
        if InvoiceAddressRules.requiresSubdivision(for: party.countryCode) {
            BuxFormRowDivider()
            TextField(
                loc(InvoiceAddressRules.subdivisionLabel(for: party.countryCode)),
                text: $party.subdivision
            )
                .buxFormFieldPadding()
        }
        BuxFormRowDivider()
        TextField(
            loc(InvoiceAddressRules.postalCodeLabel(for: party.countryCode)),
            text: $party.postalCode
        )
            .buxFormFieldPadding()

        if showRegistrationFields {
            BuxFormRowDivider()
            groupLabel("Registration")
            TextField(loc("Business registration no."), text: $party.businessRegistrationNumber)
                .buxFormFieldPadding()
            BuxFormRowDivider()
            TextField(loc("Tax / VAT registration no."), text: $party.taxRegistrationNumber)
                .buxFormFieldPadding()
        }
    }

    private func groupLabel(_ title: String) -> some View {
        Text(loc(title).uppercased())
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
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    @Binding var party: InvoicePartyDetails
    var defaultCountryCode: String
    var showRegistrationFields: Bool

    private var locale: Locale { appSettingsManager.interfaceLocale }

    private func loc(_ key: String) -> String {
        BuxCatalogLabel.string(key, locale: locale)
    }

    var body: some View {
        Section {
            Toggle(loc("Company / organization"), isOn: $party.isOrganization)
            if party.isOrganization {
                TextField(loc("Organization name"), text: $party.organizationName)
                TextField(loc("Trading name (optional)"), text: $party.tradeName)
            }
            TextField(loc("Given / first name(s)"), text: $party.givenNames)
            TextField(loc("Additional name(s)"), text: $party.additionalNames)
            TextField(loc("Family / surname(s)"), text: $party.familyNames)
        } header: {
            BuxCatalogDynamicText(key: "Identity")
        }

        Section {
            TextField(loc("Email"), text: $party.email)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
            TextField(loc("Phone"), text: $party.phone)
                .keyboardType(.phonePad)
        } header: {
            BuxCatalogDynamicText(key: "Contact")
        }

        Section {
            TextField(loc("Address line 1"), text: $party.addressLine1)
            TextField(loc("Address line 2"), text: $party.addressLine2)
            Picker(loc("Country"), selection: $party.countryCode) {
                ForEach(CountryCatalog.allCountries) { country in
                    Text(
                        BuxLocalizedString.format(
                            "%@ %@",
                            locale: locale,
                            country.flag,
                            CountryDisplayL10n.displayName(for: country, locale: locale)
                        )
                    )
                    .tag(country.id)
                }
            }
            if InvoiceAddressRules.requiresSubdivision(for: party.countryCode) {
                TextField(
                    loc(InvoiceAddressRules.subdivisionLabel(for: party.countryCode)),
                    text: $party.subdivision
                )
            }
            TextField(
                loc(InvoiceAddressRules.postalCodeLabel(for: party.countryCode)),
                text: $party.postalCode
            )
        } header: {
            BuxCatalogDynamicText(key: "Address")
        }

        if showRegistrationFields {
            Section {
                TextField(loc("Business registration no."), text: $party.businessRegistrationNumber)
                TextField(loc("Tax / VAT registration no."), text: $party.taxRegistrationNumber)
            } header: {
                BuxCatalogDynamicText(key: "Registration")
            }
        }
    }
}
