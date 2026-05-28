//
//  TaxPresetLoader.swift
//  BuxMuse
//
//  Loads global tax JSON presets for the editable self-employed tax profile picker.
//

import Foundation

@MainActor
public enum TaxPresetLoader {
    public static let countryAliases: [String: String] = [
        "UK": "GB",
        "EL": "GR"
    ]

    public static func normalizeCountryCode(_ code: String) -> String {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return countryAliases[trimmed] ?? trimmed
    }

    /// Ensures the global catalog is available for the preset picker (bundle / local cache only).
    public static func ensureCatalogLoaded() {
        _ = TaxManager.shared.allCountriesSorted
    }

    public static func preset(for code: String) -> TaxInfo? {
        TaxManager.shared.preset(for: normalizeCountryCode(code))
    }

    /// All countries from JSON, sorted by name — scales dynamically with catalog size.
    public static var allCountries: [TaxInfo] {
        TaxManager.shared.allCountriesSorted
    }

    public static var countryOptions: [(code: String, name: String)] {
        allCountries.map { ($0.isoCode, $0.name) }
    }

    /// Filters countries by name, ISO code, region, or alias (e.g. UK → GB).
    public static func filteredCountries(matching query: String) -> [TaxInfo] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return allCountries }

        let q = trimmed.lowercased()
        return allCountries.filter { matchesSearch(query: q, info: $0) }
    }

    private static func matchesSearch(query: String, info: TaxInfo) -> Bool {
        if info.name.lowercased().contains(query) { return true }
        if info.isoCode.lowercased().contains(query) { return true }
        if let region = info.region?.lowercased(), region.contains(query) { return true }

        for (alias, code) in countryAliases where code == info.isoCode {
            if alias.lowercased().contains(query) { return true }
        }

        if let resolved = countryAliases.first(where: { $0.key.lowercased() == query })?.value,
           resolved == info.isoCode {
            return true
        }

        return false
    }
}
