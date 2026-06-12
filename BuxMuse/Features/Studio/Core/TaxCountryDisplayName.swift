//
//  TaxCountryDisplayName.swift
//  BuxMuse
//
//  Tax preset picker — forwards to CountryDisplayL10n.
//

import Foundation

enum TaxCountryDisplayName {
    static func displayName(for preset: TaxInfo, locale: Locale) -> String {
        CountryDisplayL10n.displayName(for: preset, locale: locale)
    }

    static func pickerLabel(for preset: TaxInfo, locale: Locale) -> String {
        CountryDisplayL10n.pickerLabel(for: preset, locale: locale)
    }

    static func localizedRegionName(isoCode: String, locale: Locale) -> String? {
        CountryDisplayL10n.localizedRegionName(isoCode: isoCode, locale: locale)
    }
}
