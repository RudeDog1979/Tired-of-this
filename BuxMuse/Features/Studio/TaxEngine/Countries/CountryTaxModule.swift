//
//  CountryTaxModule.swift
//  BuxMuse
//
//  Country-specific tax modules — T1: GB, US, ES, DO, FR, PL.
//

import Foundation

public protocol CountryTaxModule: Sendable {
    var isoCode: String { get }
    func compute(
        request: TaxComputationRequest,
        entry: TaxCountryComputeEntry,
        periodStart: Date?,
        periodEnd: Date?
    ) -> TaxComputationResult?
}

public enum CountryTaxModuleRegistry {

    private static let modules: [String: any CountryTaxModule] = [
        "GB": GBTaxModule(),
        "US": USTaxModule(),
        "ES": ESTaxModule(),
        "DO": DOTaxModule(),
        "FR": FRTaxModule(),
        "PL": PLTaxModule(),
    ]

    public static func module(for countryCode: String) -> (any CountryTaxModule)? {
        modules[TaxManager.normalizeCountryCode(countryCode)]
    }
}
