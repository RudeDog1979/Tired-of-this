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

    /// Loads bundled/cache catalog, then refreshes from remote when the monthly window allows.
    public static func ensureCatalogLoaded(force: Bool = false) async {
        await TaxManager.shared.ensureCatalogLoaded(force: force)
        await TaxComputeCatalogStore.shared.ensureCatalogLoaded(force: force)
    }

    public static func ensureComputeCatalogLoaded(force: Bool = false) async {
        await TaxComputeCatalogStore.shared.ensureCatalogLoaded(force: force)
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

    public static func countriesSorted(for locale: Locale) -> [TaxInfo] {
        allCountries.sorted {
            TaxCountryDisplayName.displayName(for: $0, locale: locale)
                .localizedStandardCompare(
                    TaxCountryDisplayName.displayName(for: $1, locale: locale)
                ) == .orderedAscending
        }
    }

    /// Filters countries by localized name, English name, ISO code, region, or alias (e.g. UK → GB).
    public static func filteredCountries(matching query: String, locale: Locale = Locale(identifier: "en")) -> [TaxInfo] {
        let sorted = countriesSorted(for: locale)
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return sorted }

        let q = trimmed.lowercased()
        return sorted.filter { matchesSearch(query: q, info: $0, locale: locale) }
    }

    private static func matchesSearch(query: String, info: TaxInfo, locale: Locale) -> Bool {
        if CountryDisplayL10n.matchesSearch(query: query, info: info, locale: locale) { return true }
        if let region = info.region?.lowercased(), region.contains(query) { return true }
        if let resolved = countryAliases.first(where: { $0.key.lowercased() == query })?.value,
           resolved == info.isoCode {
            return true
        }
        return false
    }
}
