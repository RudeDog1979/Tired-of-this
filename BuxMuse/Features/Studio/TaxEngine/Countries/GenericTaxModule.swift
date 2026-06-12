//
//  GenericTaxModule.swift
//  BuxMuse
//
//  Phase E — catalog-driven compute for T2 (structured) countries.
//

import Foundation

public struct GenericTaxModule: CountryTaxModule {
    public let isoCode: String

    public init(isoCode: String) {
        self.isoCode = TaxManager.normalizeCountryCode(isoCode)
    }

    public func compute(
        request: TaxComputationRequest,
        entry: TaxCountryComputeEntry,
        periodStart: Date?,
        periodEnd: Date?
    ) -> TaxComputationResult? {
        guard WorldTaxEngine.catalogHasIncomeBrackets(entry) else { return nil }
        let source: TaxComputationSource = entry.meta.coverageTier == .structured
            ? .structuredCatalog
            : .countryModule
        return CountryTaxComputeSupport.compute(
            isoCode: isoCode,
            request: request,
            entry: entry,
            periodStart: periodStart,
            periodEnd: periodEnd,
            source: source
        )
    }
}
