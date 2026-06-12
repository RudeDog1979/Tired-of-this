//
//  BuxInterfaceLocale.swift
//  BuxMuse
//
//  Maps Settings → Country/Region to the SwiftUI interface locale (string catalog).
//  Independent of the device language and Simulator system locale.
//

import Foundation

public enum BuxInterfaceLocale {
    public enum Kind: Equatable {
        case english
        case latinAmericanSpanish
        case spainSpanish
    }

    /// ISO 3166-1 countries where Spanish is the primary UI language (Latin America & Caribbean).
    nonisolated private static let latinAmericanSpanishCountryIDs: Set<String> = [
        "AR", "BO", "CL", "CO", "CR", "CU", "DO", "EC", "SV", "GQ", "GT", "HN",
        "MX", "NI", "PA", "PY", "PE", "PR", "UY", "VE"
    ]

    nonisolated static let languageDefaultsKey = "interface_language_id"
    nonisolated private static let countryDefaultsKey = "selected_country_id"

    public nonisolated static func kind(for country: CountrySetting) -> Kind {
        legacyKind(forCountryID: country.id)
    }

    public nonisolated static func locale(for country: CountrySetting) -> Locale {
        currentInterfaceLanguage(forCountryID: country.id).locale
    }

    public nonisolated static func legacyKind(forCountryID countryID: String) -> Kind {
        let id = countryID.uppercased()
        if id == "ES" { return .spainSpanish }
        if latinAmericanSpanishCountryIDs.contains(id) { return .latinAmericanSpanish }
        return .english
    }

    public nonisolated static func currentInterfaceLanguage() -> AppInterfaceLanguage {
        if let stored = UserDefaults.standard.string(forKey: languageDefaultsKey),
           let language = AppInterfaceLanguage(rawValue: stored) {
            return language
        }
        let countryID = UserDefaults.standard.string(forKey: countryDefaultsKey) ?? "US"
        let migrated = AppInterfaceLanguage.migratedDefault(forCountryID: countryID)
        UserDefaults.standard.set(migrated.rawValue, forKey: languageDefaultsKey)
        return migrated
    }

    public nonisolated static func persistInterfaceLanguage(_ language: AppInterfaceLanguage) {
        UserDefaults.standard.set(language.rawValue, forKey: languageDefaultsKey)
    }

    public nonisolated static func currentInterfaceLanguage(forCountryID countryID: String) -> AppInterfaceLanguage {
        if let stored = UserDefaults.standard.string(forKey: languageDefaultsKey),
           let language = AppInterfaceLanguage(rawValue: stored) {
            return language
        }
        return AppInterfaceLanguage.migratedDefault(forCountryID: countryID)
    }

    /// UI string-catalog locale from **Settings → App language** (not device language or country alone).
    public nonisolated static var currentInterfaceLocale: Locale {
        currentInterfaceLanguage().locale
    }
}
