//
//  TaxIdentitySync.swift
//  BuxMuse
//
//  Keeps Studio profile aligned with the canonical Tax Profile identity.
//

import Foundation

public enum TaxIdentitySync {

    /// Tax Profile is the source of truth for registration, country, and region.
    public static func applyCanonicalIdentity(
        taxProfile: StudioTaxProfile,
        to profile: inout StudioProfile
    ) {
        let country = taxProfile.selectedTaxCountry
            ?? TaxManager.normalizeCountryCode(taxProfile.countryCode)
        if !country.isEmpty {
            profile.countryCode = country
        }
        profile.regionCode = taxProfile.regionCode
        profile.vatRegistered = taxProfile.vatRegistered
    }
}
