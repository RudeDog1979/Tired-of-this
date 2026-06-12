//
//  InvoicePartyEngine.swift
//  BuxMuse
//
//  Invoice party formatting, address rules, payment lines — used by StudioBrain & templates.
//

import Foundation

public enum InvoiceAddressRules {
    private static let subdivisionCountries: Set<String> = [
        "US", "CA", "AU", "GB", "UK", "IE", "IN", "MX", "BR", "IT", "ES", "DE", "FR",
        "AT", "CH", "NL", "BE", "PL", "NZ", "ZA", "AR", "CO", "CL", "PE", "MY", "TH",
        "JP", "KR", "CN", "TW", "HK", "SG", "PH", "ID", "VN", "NG", "KE", "EG", "SA",
        "AE", "IL", "TR", "RU", "UA", "SE", "NO", "DK", "FI", "PT", "GR", "CZ", "RO",
        "HU", "BG", "HR", "SK", "SI", "LT", "LV", "EE"
    ]

    public static func normalizedCountry(_ code: String) -> String {
        let upper = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if upper == "UK" { return "GB" }
        return upper
    }

    public static func requiresSubdivision(for countryCode: String) -> Bool {
        subdivisionCountries.contains(normalizedCountry(countryCode))
    }

    public static func subdivisionLabel(for countryCode: String) -> String {
        switch normalizedCountry(countryCode) {
        case "US": return "State"
        case "CA": return "Province"
        case "AU": return "State"
        case "GB", "UK", "IE": return "County"
        case "DE", "AT", "CH": return "State / Region"
        case "IN": return "State"
        case "MX", "BR", "AR": return "State"
        default: return "Region"
        }
    }

    public static func postalCodeLabel(for countryCode: String) -> String {
        switch normalizedCountry(countryCode) {
        case "US": return "ZIP Code"
        case "GB", "UK": return "Postcode"
        case "CA": return "Postal Code"
        case "IE": return "Eircode"
        case "AU": return "Postcode"
        case "IN": return "PIN Code"
        default: return "Postal Code"
        }
    }

    public static func defaultBankAccountType(for countryCode: String) -> BankAccountType {
        switch normalizedCountry(countryCode) {
        case "GB", "UK": return .uk
        case "US": return .us
        case "CA": return .canada
        case "AU": return .australia
        case "DE", "FR", "ES", "IT", "NL", "BE", "AT", "PT", "IE", "PL", "SE", "NO", "DK",
             "FI", "GR", "LU", "MT", "CY", "SK", "SI", "LT", "LV", "EE", "HR", "BG", "RO",
             "CZ", "HU", "CH", "LI", "IS", "AE", "SA", "QA", "KW", "BH", "OM", "JO", "LB",
             "TR", "EG", "MA", "TN", "ZA", "NG", "KE", "GH", "BR", "MX", "AR", "CL", "CO",
             "PE", "UY", "CR", "PA", "DO", "GT", "HN", "SV", "NI", "EC", "BO", "PY", "VE":
            return .iban
        default:
            return .generic
        }
    }
}

@MainActor
public enum InvoicePartyEngine {

    public enum PartyRole {
        case issuer
        case recipient
    }

    // MARK: - Bank type

    public static func resolveBankAccountType(
        countryCode: String,
        paymentConfig: InvoicePaymentConfig,
        autoDetect: Bool,
        manualOverride: BankAccountType?
    ) -> BankAccountType {
        if let manual = manualOverride, !autoDetect {
            return manual
        }
        if let stored = paymentConfig.accountType {
            return stored
        }
        if !paymentConfig.iban.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .iban
        }
        return InvoiceAddressRules.defaultBankAccountType(for: countryCode)
    }

    // MARK: - Formatting

    public static func formattedSortCode(_ raw: String) -> String {
        let digits = raw.filter(\.isNumber)
        guard digits.count >= 6 else { return raw }
        let idx = digits.index(digits.startIndex, offsetBy: 6)
        let six = String(digits[..<idx])
        return "\(six.prefix(2))-\(six.dropFirst(2).prefix(2))-\(six.dropFirst(4))"
    }

    public static func formattedAddressLines(for party: InvoicePartyDetails, includeCountry: Bool) -> [String] {
        var lines: [String] = []
        if !party.addressLine1.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lines.append(party.addressLine1)
        }
        if !party.addressLine2.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lines.append(party.addressLine2)
        }
        var cityLine = ""
        if !party.subdivision.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            cityLine = party.subdivision
        }
        if !party.postalCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            cityLine = cityLine.isEmpty ? party.postalCode : "\(cityLine) \(party.postalCode)"
        }
        if !cityLine.isEmpty { lines.append(cityLine) }
        if includeCountry, !party.countryCode.isEmpty {
            let name = CountryDisplayL10n.displayName(
                isoCode: party.countryCode,
                locale: BuxInterfaceLocale.currentInterfaceLocale,
                englishFallback: CountryCatalog.country(for: party.countryCode)?.name
            )
            lines.append(name)
        }
        return lines
    }

    public static func partyBlock(details: InvoicePartyDetails, role: PartyRole) -> InvoicePartyBlockDisplay {
        let heading = role == .issuer ? "FROM" : "BILL TO"
        var lines: [String] = formattedAddressLines(for: details, includeCountry: true)
        if !details.email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lines.append(details.email)
        }
        if !details.phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lines.append(details.phone)
        }
        if !details.businessRegistrationNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lines.append("Reg: \(details.businessRegistrationNumber)")
        }
        if !details.taxRegistrationNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lines.append("Tax ID: \(details.taxRegistrationNumber)")
        }
        if !details.tradeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           details.tradeName != details.organizationName {
            lines.append("Trading as: \(details.tradeName)")
        }

        let title = details.primaryTitle.isEmpty ? "—" : details.primaryTitle
        return InvoicePartyBlockDisplay(
            heading: heading,
            title: title,
            subtitle: details.contactSubtitle,
            lines: lines
        )
    }

    public static func legalFooter(
        issuer: InvoicePartyDetails,
        settings: StudioInvoiceSettings,
        taxProfile: StudioTaxProfile,
        locale: Locale = BuxInterfaceLocale.currentInterfaceLocale
    ) -> InvoiceLegalFooterDisplay {
        guard settings.showLegalFooter else { return .hidden }

        var lines: [String] = []
        let legalName = issuer.isOrganization
            ? issuer.organizationName
            : issuer.personFullName
        if !legalName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lines.append(legalName)
        }
        if !issuer.tradeName.isEmpty, issuer.tradeName != legalName {
            lines.append("Trading as \(issuer.tradeName)")
        }
        lines.append(contentsOf: formattedAddressLines(for: issuer, includeCountry: true))
        if !issuer.businessRegistrationNumber.isEmpty {
            lines.append("Company registration: \(issuer.businessRegistrationNumber)")
        }
        if settings.showTaxID {
            if !issuer.taxRegistrationNumber.isEmpty {
                lines.append("\(IndirectTaxLabelResolver.registrationLabel(for: taxProfile, locale: locale)): \(issuer.taxRegistrationNumber)")
            } else if taxProfile.vatRegistered {
                lines.append("\(IndirectTaxLabelResolver.registrationLabel(for: taxProfile, locale: locale)): —")
            }
        }
        if !issuer.countryCode.isEmpty {
            let country = CountryDisplayL10n.displayName(
                isoCode: issuer.countryCode,
                locale: locale,
                englishFallback: CountryCatalog.country(for: issuer.countryCode)?.name
            )
            lines.append("Registered in \(country)")
        }

        let trimmed = lines.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard !trimmed.isEmpty else { return .hidden }
        return InvoiceLegalFooterDisplay(lines: trimmed, isVisible: true)
    }

    public static func paymentDetailLines(
        config: InvoicePaymentConfig,
        settings: StudioInvoiceSettings,
        countryCode: String,
        autoDetectBankType: Bool,
        manualOverride: BankAccountType?
    ) -> [InvoicePaymentLineDisplay] {
        guard config.showBankBlock else {
            if settings.showBankDetails, !settings.bankDetails.isEmpty {
                return [InvoicePaymentLineDisplay(label: "Payment", value: settings.bankDetails)]
            }
            return []
        }

        var lines: [InvoicePaymentLineDisplay] = []
        let bankType = resolveBankAccountType(
            countryCode: countryCode,
            paymentConfig: config,
            autoDetect: autoDetectBankType,
            manualOverride: manualOverride
        )

        if !config.bankName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lines.append(.init(label: "Bank", value: config.bankName))
        }

        switch bankType {
        case .iban:
            if !config.iban.isEmpty { lines.append(.init(label: "IBAN", value: config.iban)) }
            if !config.bic.isEmpty { lines.append(.init(label: "BIC / SWIFT", value: config.bic)) }
        case .uk:
            if !config.sortCode.isEmpty {
                lines.append(.init(label: "Sort Code", value: formattedSortCode(config.sortCode)))
            }
            if !config.accountNumber.isEmpty { lines.append(.init(label: "Account Number", value: config.accountNumber)) }
            if config.iban.isEmpty == false { lines.append(.init(label: "IBAN", value: config.iban)) }
        case .us:
            if !config.routingNumber.isEmpty { lines.append(.init(label: "Routing Number", value: config.routingNumber)) }
            if !config.accountNumber.isEmpty { lines.append(.init(label: "Account Number", value: config.accountNumber)) }
        case .canada:
            if !config.transitNumber.isEmpty { lines.append(.init(label: "Transit Number", value: config.transitNumber)) }
            if !config.institutionNumber.isEmpty { lines.append(.init(label: "Institution Number", value: config.institutionNumber)) }
            if !config.accountNumber.isEmpty { lines.append(.init(label: "Account Number", value: config.accountNumber)) }
        case .australia:
            if !config.bsb.isEmpty { lines.append(.init(label: "BSB", value: config.bsb)) }
            if !config.accountNumber.isEmpty { lines.append(.init(label: "Account Number", value: config.accountNumber)) }
        case .generic:
            if !config.accountNumber.isEmpty { lines.append(.init(label: "Account Number", value: config.accountNumber)) }
            if !config.iban.isEmpty { lines.append(.init(label: "IBAN", value: config.iban)) }
            if !config.bic.isEmpty { lines.append(.init(label: "BIC / SWIFT", value: config.bic)) }
        }

        return lines
    }

    // MARK: - Render context assembly

    public static func enrichRenderContext(
        invoice: StudioInvoice,
        client: StudioClient?,
        profile: StudioProfile,
        settings: StudioInvoiceSettings,
        taxProfile: StudioTaxProfile,
        templateConfig: InvoiceTemplateConfig,
        taxConfig: InvoiceTaxEngineConfig,
        paymentConfig: InvoicePaymentConfig,
        totals: InvoiceTotalsDisplay,
        formatAmount: @escaping (Decimal) -> String,
        snapshotIssuer: InvoicePartyDetails? = nil,
        snapshotRecipient: InvoicePartyDetails? = nil,
        countryCode: String,
        autoDetectBankType: Bool,
        manualOverride: BankAccountType?,
        interfaceLocale: Locale = BuxInterfaceLocale.currentInterfaceLocale
    ) -> InvoiceRenderContext {
        let issuerDetails = snapshotIssuer ?? profile.resolvedPartyDetails()
        let recipientDetails = snapshotRecipient ?? client?.resolvedPartyDetails() ?? InvoicePartyDetails()

        return InvoiceRenderContext(
            invoice: invoice,
            client: client,
            profile: profile,
            settings: settings,
            templateConfig: templateConfig,
            taxConfig: taxConfig,
            paymentConfig: paymentConfig,
            totals: totals,
            formatAmount: formatAmount,
            issuerBlock: partyBlock(details: issuerDetails, role: .issuer),
            recipientBlock: partyBlock(details: recipientDetails, role: .recipient),
            legalFooter: legalFooter(issuer: issuerDetails, settings: settings, taxProfile: taxProfile),
            paymentDetailLines: paymentDetailLines(
                config: paymentConfig,
                settings: settings,
                countryCode: countryCode,
                autoDetectBankType: autoDetectBankType,
                manualOverride: manualOverride
            ),
            interfaceLocale: interfaceLocale
        )
    }
}
