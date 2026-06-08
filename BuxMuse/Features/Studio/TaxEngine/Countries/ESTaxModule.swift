//
//  ESTaxModule.swift
//  BuxMuse
//
//  Spain autónomo — progressive IRPF + simplified social (Phase 2).
//

import Foundation

public struct ESTaxModule: CountryTaxModule {
    public let isoCode = "ES"

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
