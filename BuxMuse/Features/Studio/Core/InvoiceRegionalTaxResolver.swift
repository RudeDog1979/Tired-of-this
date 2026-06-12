//
//  InvoiceRegionalTaxResolver.swift
//  BuxMuse
//
//  Phase C — supplemental invoice tax lines from client region (US state, etc.).
//

import Foundation

public enum InvoiceRegionalTaxResolver {

    /// Representative invoice subtotal for marginal state-rate estimates.
    private static let representativeBase: Decimal = 5_000

    /// Extra tax lines based on **client** region (e.g. US state sales/use tax estimate).
    public static func supplementalRates(
        countryCode: String,
        clientRegionCode: String?,
        locale: Locale
    ) -> [InvoiceTaxRate] {
        let code = TaxManager.normalizeCountryCode(countryCode)
        guard let entry = TaxComputeCatalogStore.shared.entry(for: code) else { return [] }

        let region = clientRegionCode?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased() ?? ""
        guard !region.isEmpty else { return [] }

        switch code {
        case "US":
            return usStateRates(entry: entry, region: region, locale: locale)
        default:
            return []
        }
    }

    public static func regionDisplayName(
        countryCode: String,
        regionCode: String,
        locale: Locale
    ) -> String {
        let regions = TaxComputeCatalogStore.shared.regions(for: countryCode)
        let normalized = regionCode.uppercased()
        if let match = regions.first(where: { $0.code.uppercased() == normalized }) {
            return match.name
        }
        return regionCode
    }

    // MARK: - US

    private static func usStateRates(
        entry: TaxCountryComputeEntry,
        region: String,
        locale: Locale
    ) -> [InvoiceTaxRate] {
        let name = regionDisplayName(countryCode: "US", regionCode: region, locale: locale)

        if let salesFraction = entry.regionalSalesTaxRate(forRegion: region) {
            let pct = TaxComputeKernel.rounded(salesFraction * 100, scale: 2)
            let label = BuxLocalizedString.format(
                "%@ sales tax (est.)",
                locale: locale,
                name
            )
            return [InvoiceTaxRate(label: label, percentage: pct)]
        }

        guard let overrides = entry.regionalOverrides,
              let regional = overrides[region],
              let rules = regional.selfEmployed,
              !rules.brackets.isEmpty else {
            return []
        }

        let fraction = TaxComputeKernel.marginalRateFraction(
            at: representativeBase,
            brackets: rules.brackets
        )
        guard fraction > 0 else { return [] }

        let pct = TaxComputeKernel.rounded(fraction * 100, scale: 2)
        let label = BuxLocalizedString.format(
            "%@ tax (est.)",
            locale: locale,
            name
        )

        return [InvoiceTaxRate(label: label, percentage: pct)]
    }
}
