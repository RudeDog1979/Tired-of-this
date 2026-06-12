//
//  FRTaxModule.swift
//  BuxMuse
//
//  France micro/progressive income tax + URSSAF simplified (Phase 2).
//

import Foundation

public struct FRTaxModule: CountryTaxModule {
    public let isoCode = "FR"

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
