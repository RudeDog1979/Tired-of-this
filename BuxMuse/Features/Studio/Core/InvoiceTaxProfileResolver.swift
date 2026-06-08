//
//  InvoiceTaxProfileResolver.swift
//  BuxMuse
//
//  Resolves invoice indirect-tax lines from Tax Profile + compute catalog.
//

import Foundation

public enum InvoiceTaxSource: String, Codable, CaseIterable, Identifiable, Sendable {
    case taxProfile
    case custom
    case none

    public var id: String { rawValue }

    public var catalogKey: String {
        switch self {
        case .taxProfile: return "From Tax Profile"
        case .custom: return "Custom rates"
        case .none: return "No tax"
        }
    }

    public func catalogLabel(locale: Locale) -> String {
        BuxCatalogLabel.string(catalogKey, locale: locale)
    }
}

public enum InvoiceTaxProfileResolver {

    /// Builds invoice tax config from Tax Profile (default) or legacy invoice settings.
    public static func config(
        taxProfile: StudioTaxProfile,
        settings: StudioInvoiceSettings,
        source: InvoiceTaxSource,
        existingRates: [InvoiceTaxRate] = [],
        clientRegionCode: String? = nil,
        locale: Locale = .current
    ) -> InvoiceTaxEngineConfig {
        let label = resolvedLabel(for: taxProfile)
        let mode = taxMode(from: settings.defaultTaxBehavior)

        switch source {
        case .none:
            return InvoiceTaxEngineConfig(
                source: .none,
                mode: mode,
                rates: [],
                localizedLabel: label.isEmpty ? "Tax" : label
            )

        case .custom:
            var rates = existingRates
            if rates.isEmpty, let pct = settings.defaultTaxRatePercent, pct > 0 {
                rates = [InvoiceTaxRate(
                    label: label.isEmpty ? "Tax" : label,
                    percentage: pct
                )]
            }
            return InvoiceTaxEngineConfig(
                source: .custom,
                mode: mode,
                rates: rates,
                localizedLabel: label.isEmpty ? "Tax" : label
            )

        case .taxProfile:
            var rates = ratesFromTaxProfile(taxProfile, settings: settings, label: label)
            let country = taxProfile.selectedTaxCountry ?? taxProfile.countryCode
            rates.append(contentsOf: InvoiceRegionalTaxResolver.supplementalRates(
                countryCode: country,
                clientRegionCode: clientRegionCode,
                locale: locale
            ))
            rates = deduplicatedRates(rates)
            return InvoiceTaxEngineConfig(
                source: .taxProfile,
                mode: effectiveMode(for: taxProfile, settings: settings, rates: rates),
                rates: rates,
                localizedLabel: label.isEmpty ? "Tax" : label
            )
        }
    }

    /// One-line summary for invoice designer UI, e.g. "GB · VAT 20%".
    public static func profileSummary(
        taxProfile: StudioTaxProfile,
        settings: StudioInvoiceSettings,
        locale: Locale,
        clientRegionCode: String? = nil
    ) -> String {
        let code = taxProfile.selectedTaxCountry
            ?? TaxManager.normalizeCountryCode(taxProfile.countryCode)
        if code.isEmpty || code == "CUSTOM" {
            return BuxCatalogLabel.string("Set a country in Tax Profile", locale: locale)
        }

        if !taxProfile.vatRegistered {
            return BuxLocalizedString.format(
                "%@ · %@",
                locale: locale,
                code,
                BuxCatalogLabel.string("Not registered for indirect tax", locale: locale)
            )
        }

        guard let pct = resolvedPercentage(taxProfile: taxProfile, settings: settings), pct > 0 else {
            return BuxLocalizedString.format(
                "%@ · %@",
                locale: locale,
                code,
                BuxCatalogLabel.string("No standard indirect tax rate", locale: locale)
            )
        }

        let label = resolvedLabel(for: taxProfile)
        let taxName = label.isEmpty
            ? BuxCatalogLabel.string("Tax", locale: locale)
            : label
        var summary = BuxLocalizedString.format(
            "%@ · %@ %@%%",
            locale: locale,
            code,
            taxName,
            NSDecimalNumber(decimal: pct).stringValue
        )

        let regional = InvoiceRegionalTaxResolver.supplementalRates(
            countryCode: code,
            clientRegionCode: clientRegionCode,
            locale: locale
        )
        if let stateRate = regional.first {
            summary += BuxLocalizedString.format(
                " · %@ %@%%",
                locale: locale,
                stateRate.label,
                NSDecimalNumber(decimal: stateRate.percentage).stringValue
            )
        }

        return summary
    }

    /// Syncs invoice defaults when Tax Profile is saved.
    public static func syncInvoiceSettings(
        taxProfile: StudioTaxProfile,
        settings: inout StudioInvoiceSettings
    ) {
        settings.defaultInvoiceTaxSource = .taxProfile

        if !taxProfile.vatRegistered {
            settings.defaultTaxBehavior = .noTax
            settings.defaultTaxRatePercent = nil
            return
        }

        if taxProfile.estimatedIndirectTaxRatePercent != nil
            || !taxProfile.vatRules.isEmpty
            || catalogVATRate(for: taxProfile) != nil {
            settings.defaultTaxBehavior = .taxAdded
        }

        settings.defaultTaxRatePercent = resolvedPercentage(taxProfile: taxProfile, settings: settings)
    }

    // MARK: - Private

    private static func ratesFromTaxProfile(
        _ taxProfile: StudioTaxProfile,
        settings: StudioInvoiceSettings,
        label: String
    ) -> [InvoiceTaxRate] {
        guard taxProfile.vatRegistered else { return [] }

        let taxLabel = label.isEmpty ? "Tax" : label
        var rates: [InvoiceTaxRate] = []

        for rule in taxProfile.vatRules {
            let pct = percentageFromStoredRate(rule.rate)
            guard pct > 0 else { continue }
            rates.append(InvoiceTaxRate(label: taxLabel, percentage: pct))
        }

        if rates.isEmpty,
           let pct = resolvedPercentage(taxProfile: taxProfile, settings: settings),
           pct > 0 {
            rates = [InvoiceTaxRate(label: taxLabel, percentage: pct)]
        }

        return deduplicatedRates(rates)
    }

    private static func deduplicatedRates(_ rates: [InvoiceTaxRate]) -> [InvoiceTaxRate] {
        var seen = Set<String>()
        return rates.filter { rate in
            let key = "\(rate.label.lowercased())|\(NSDecimalNumber(decimal: rate.percentage).stringValue)"
            guard !seen.contains(key) else { return false }
            seen.insert(key)
            return true
        }
    }

    private static func resolvedPercentage(
        taxProfile: StudioTaxProfile,
        settings: StudioInvoiceSettings
    ) -> Decimal? {
        if let override = taxProfile.estimatedIndirectTaxRatePercent, override > 0 {
            return override
        }

        if let ruleRate = taxProfile.vatRules.first?.rate, ruleRate > 0 {
            return percentageFromStoredRate(ruleRate)
        }

        if let catalogRate = catalogVATRate(for: taxProfile), catalogRate > 0 {
            return percentageFromStoredRate(catalogRate)
        }

        if let fallback = settings.defaultTaxRatePercent, fallback > 0 {
            return fallback
        }

        return nil
    }

    private static func catalogVATRate(for taxProfile: StudioTaxProfile) -> Decimal? {
        let code = taxProfile.selectedTaxCountry ?? taxProfile.countryCode
        guard let entry = TaxComputeCatalogStore.shared.entry(for: code) else { return nil }
        let block = entry.mergedBlock(forRegion: taxProfile.regionCode)
        return block.vat?.standardRate
    }

    private static func percentageFromStoredRate(_ rate: Decimal) -> Decimal {
        if rate > 0 && rate <= 1 {
            return rate * 100
        }
        return rate
    }

    private static func resolvedLabel(for taxProfile: StudioTaxProfile) -> String {
        IndirectTaxLabelResolver.shortName(from: taxProfile.effectiveIndirectTax)
    }

    private static func taxMode(from behavior: InvoiceTaxBehavior) -> InvoiceTaxMode {
        behavior == .taxIncluded ? .inclusive : .exclusive
    }

    private static func effectiveMode(
        for taxProfile: StudioTaxProfile,
        settings: StudioInvoiceSettings,
        rates: [InvoiceTaxRate]
    ) -> InvoiceTaxMode {
        if rates.isEmpty || settings.defaultTaxBehavior == .noTax {
            return .exclusive
        }
        return taxMode(from: settings.defaultTaxBehavior)
    }
}
