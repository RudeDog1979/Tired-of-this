//
//  TaxCountryDisplayName.swift
//  BuxMuse
//
//  Localized country names for tax preset picker, search, and labels.
//

import Foundation

enum TaxCountryDisplayName {
    static func displayName(for preset: TaxInfo, locale: Locale) -> String {
        localizedRegionName(isoCode: preset.isoCode, locale: locale) ?? preset.name
    }

    static func pickerLabel(for preset: TaxInfo, locale: Locale) -> String {
        "\(displayName(for: preset, locale: locale)) (\(preset.isoCode))"
    }

    static func localizedRegionName(isoCode: String, locale: Locale) -> String? {
        let normalized = TaxPresetLoader.normalizeCountryCode(isoCode)
        guard let name = locale.localizedString(forRegionCode: normalized),
              !name.isEmpty,
              name.uppercased() != normalized else {
            return nil
        }
        return name
    }
}
