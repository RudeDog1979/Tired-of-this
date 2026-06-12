//
//  BuxInterfaceLanguage.swift
//  BuxMuse
//
//  App UI language — independent of country/region and device language.
//

import Foundation

public enum AppInterfaceLanguage: String, Codable, CaseIterable, Identifiable, Sendable {
    case english = "en"
    case spanishLatinAmerica = "es-419"
    case spanishSpain = "es-ES"

    public nonisolated var id: String { rawValue }

    public nonisolated var locale: Locale { Locale(identifier: rawValue) }

    public nonisolated var catalogTitleKey: String {
        switch self {
        case .english: return "English"
        case .spanishLatinAmerica: return "Spanish (Latin America)"
        case .spanishSpain: return "Spanish (Spain)"
        }
    }

    public func catalogLabel(locale: Locale = BuxInterfaceLocale.currentInterfaceLocale) -> String {
        BuxCatalogLabel.string(catalogTitleKey, locale: locale)
    }

    public nonisolated static func migratedDefault(forCountryID countryID: String) -> AppInterfaceLanguage {
        switch BuxInterfaceLocale.legacyKind(forCountryID: countryID) {
        case .english: return .english
        case .latinAmericanSpanish: return .spanishLatinAmerica
        case .spainSpanish: return .spanishSpain
        }
    }
}
