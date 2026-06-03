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

    nonisolated private static let countryDefaultsKey = "selected_country_id"

    public static func kind(for country: CountrySetting) -> Kind {
        kind(forCountryID: country.id)
    }

    public static func locale(for country: CountrySetting) -> Locale {
        locale(forCountryID: country.id)
    }

    public nonisolated static func kind(forCountryID countryID: String) -> Kind {
        let id = countryID.uppercased()
        if id == "ES" { return .spainSpanish }
        if latinAmericanSpanishCountryIDs.contains(id) { return .latinAmericanSpanish }
        return .english
    }

    public nonisolated static func locale(forCountryID countryID: String) -> Locale {
        switch kind(forCountryID: countryID) {
        case .english:
            return Locale(identifier: "en")
        case .latinAmericanSpanish:
            return Locale(identifier: "es-419")
        case .spainSpanish:
            return Locale(identifier: "es-ES")
        }
    }

    /// Resolves UI locale from persisted country (same key as `AppSettingsManager`).
    /// `nonisolated` so engines and default parameters can read it off the main actor.
    /// Does not use `Locale.current` (main-actor isolated in Swift 6).
    public nonisolated static var currentInterfaceLocale: Locale {
        if let stored = UserDefaults.standard.string(forKey: countryDefaultsKey) {
            return locale(forCountryID: stored)
        }
        return locale(forCountryID: "US")
    }
}
