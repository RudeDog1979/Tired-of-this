//
//  DOTaxModule.swift
//  BuxMuse
//
//  Dominican Republic — progressive ISR + pagos a cuenta (Phase 2).
//

import Foundation

public struct DOTaxModule: CountryTaxModule {
    public let isoCode = "DO"

    public func compute(
        request: TaxComputationRequest,
        entry: TaxCountryComputeEntry,
        periodStart: Date?,
        periodEnd: Date?
    ) -> TaxComputationResult? {
        CountryTaxComputeSupport.compute(
            isoCode: isoCode,
            request: request,
            entry: entry,
            periodStart: periodStart,
            periodEnd: periodEnd
        )
    }
}
