//
//  TaxComplianceAdvisor.swift
//  BuxMuse
//
//  Cross-checks Tax Profile, invoices, and turnover — one advisory surface.
//

import Foundation

public struct TaxComplianceNotice: Identifiable, Equatable, Sendable {
    public enum Severity: Sendable {
        case info
        case warning
    }

    public let id: String
    public let severity: Severity
    public let messageKey: String

    public init(id: String, severity: Severity, messageKey: String) {
        self.id = id
        self.severity = severity
        self.messageKey = messageKey
    }
}

public enum TaxComplianceAdvisor {

    public static func notices(
        taxProfile: StudioTaxProfile,
        invoices: [StudioInvoice],
        locale: Locale = BuxInterfaceLocale.currentInterfaceLocale,
        now: Date = Date()
    ) -> [TaxComplianceNotice] {
        var items: [TaxComplianceNotice] = []

        let activeInvoices = invoices.filter {
            $0.status == .paid || $0.status == .sent || $0.status == .overdue
        }
        let invoiceVatTotal = activeInvoices.reduce(Decimal(0)) { $0 + $1.taxAmount }
        let rollingGross = TaxIntelligenceEngine.rollingTwelveMonthGross(invoices: invoices, now: now)

        if invoiceVatTotal > 0, !taxProfile.vatRegistered {
            items.append(.init(
                id: "invoice-vat-unregistered",
                severity: .warning,
                messageKey: "Invoices include tax but your Tax Profile says you are not registered for indirect tax. Update Tax Profile or remove tax from invoices."
            ))
        }

        if taxProfile.vatRegistered, invoiceVatTotal == 0, !activeInvoices.isEmpty {
            items.append(.init(
                id: "registered-no-invoice-vat",
                severity: .info,
                messageKey: "You are registered for indirect tax but recent invoices have no tax lines. New invoices will auto-fill from Tax Profile."
            ))
        }

        if !taxProfile.vatRegistered {
            let countryCode = taxProfile.selectedTaxCountry ?? taxProfile.countryCode
            let currency = catalogCurrency(for: taxProfile) ?? "USD"
            if TaxCountryHeuristics.isApproachingVATThreshold(
                rollingGross: rollingGross,
                countryCode: countryCode,
                currencyCode: currency
            ) {
                items.append(.init(
                    id: "approaching-vat-threshold",
                    severity: .warning,
                    messageKey: "Rolling 12-month turnover may approach VAT/GST registration thresholds — review local rules."
                ))
            }
        }

        if taxProfile.vatRegistered,
           taxProfile.estimatedIndirectTaxRatePercent != nil,
           let catalogRate = catalogVATPercent(for: taxProfile),
           taxProfile.estimatedIndirectTaxRatePercent != catalogRate {
            items.append(.init(
                id: "indirect-override-mismatch",
                severity: .info,
                messageKey: "Your manual indirect tax % overrides the catalog rate. Clear it in Tax Profile to use the standard rate automatically."
            ))
        }

        return items
    }

    public static func identitySummary(
        taxProfile: StudioTaxProfile,
        locale: Locale
    ) -> String {
        let code = taxProfile.selectedTaxCountry
            ?? TaxManager.normalizeCountryCode(taxProfile.countryCode)
        let country = code.isEmpty
            ? BuxCatalogLabel.string("No country", locale: locale)
            : code
        let income = taxProfile.taxIncomeType.catalogSummaryLabel(locale: locale)
        let indirect = taxProfile.vatRegistered
            ? IndirectTaxLabelResolver.registrationLabel(for: taxProfile, locale: locale)
            : BuxCatalogLabel.string("Not registered for indirect tax", locale: locale)
        return BuxLocalizedString.format(
            "%@ · %@ · %@",
            locale: locale,
            country,
            income,
            indirect
        )
    }

    // MARK: - Private

    private static func catalogCurrency(for taxProfile: StudioTaxProfile) -> String? {
        let code = taxProfile.selectedTaxCountry ?? taxProfile.countryCode
        return TaxComputeCatalogStore.shared.entry(for: code)?.meta.currency
    }

    private static func catalogVATPercent(for taxProfile: StudioTaxProfile) -> Decimal? {
        guard let rate = taxProfile.vatRules.first?.rate ?? catalogVATDecimal(for: taxProfile) else {
            return nil
        }
        if rate > 0, rate <= 1 { return rate * 100 }
        return rate
    }

    private static func catalogVATDecimal(for taxProfile: StudioTaxProfile) -> Decimal? {
        let code = taxProfile.selectedTaxCountry ?? taxProfile.countryCode
        guard let entry = TaxComputeCatalogStore.shared.entry(for: code) else { return nil }
        let block = entry.mergedBlock(forRegion: taxProfile.regionCode)
        return block.vat?.standardRate
    }
}
