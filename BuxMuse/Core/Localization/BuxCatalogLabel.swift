//
//  BuxCatalogLabel.swift
//  BuxMuse
//
//  Localize English source keys stored as String / enum rawValue at display time.
//

import Foundation

enum BuxCatalogLabel {
    static func string(_ englishKey: String, locale: Locale) -> String {
        BuxStringCatalog.localized(englishKey, locale: locale)
    }
}

extension RawRepresentable where RawValue == String {
    func catalogLabel(locale: Locale = BuxInterfaceLocale.currentInterfaceLocale) -> String {
        BuxCatalogLabel.string(rawValue, locale: locale)
    }
}

extension FeatureInsightStrip {
    func localizedValue(locale: Locale = BuxInterfaceLocale.currentInterfaceLocale) -> String {
        BuxCatalogLabel.string(value, locale: locale)
    }
}

extension ProStudioSearchEngine.Section {
    func catalogLabel(locale: Locale = BuxInterfaceLocale.currentInterfaceLocale) -> String {
        BuxCatalogLabel.string(rawValue, locale: locale)
    }
}
