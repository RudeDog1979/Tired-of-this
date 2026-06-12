//
//  PLTaxModule.swift
//  BuxMuse
//
//  Poland — flat-scale income tax + ZUS simplified (Phase 2).
//

import Foundation

public struct PLTaxModule: CountryTaxModule {
    public let isoCode = "PL"

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
