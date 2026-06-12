//
//  TaxCountryPresetL10n.swift
//  BuxMuse
//

import Foundation

enum TaxCountryPresetL10n {
    static func vatSummary(countryCode: String, locale: Locale) -> String {
        let code = countryCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !code.isEmpty else { return "" }
        return BuxCatalogLabel.string("tax.vat.\(code)", locale: locale)
    }
}
