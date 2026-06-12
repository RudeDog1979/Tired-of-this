//
//  CountryDisplayL10n.swift
//  BuxMuse
//
//  Localized country/region names + search for every ISO territory in CountryCatalog.
//  ISO codes unchanged — tax JSON untouched.
//

import Foundation

enum CountryDisplayL10n {
    private static let searchLocales: [Locale] = [
        Locale(identifier: "en"),
        Locale(identifier: "es"),
        Locale(identifier: "es-419"),
        Locale(identifier: "es-ES"),
        Locale(identifier: "fr"),
        Locale(identifier: "de"),
        Locale(identifier: "pt"),
        Locale(identifier: "it"),
        Locale(identifier: "pl"),
        Locale(identifier: "ru"),
        Locale(identifier: "ar"),
        Locale(identifier: "zh-Hans")
    ]

    static func displayName(isoCode: String, locale: Locale, englishFallback: String? = nil) -> String {
        localizedRegionName(isoCode: isoCode, locale: locale)
            ?? englishFallback
            ?? localizedRegionName(isoCode: isoCode, locale: Locale(identifier: "en"))
            ?? TaxPresetLoader.normalizeCountryCode(isoCode).uppercased()
    }

    static func displayName(for country: CountrySetting, locale: Locale) -> String {
        displayName(isoCode: country.id, locale: locale, englishFallback: country.name)
    }

    static func displayName(for preset: TaxInfo, locale: Locale) -> String {
        displayName(isoCode: preset.isoCode, locale: locale, englishFallback: preset.name)
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

    static func sorted(_ countries: [CountrySetting], locale: Locale) -> [CountrySetting] {
        countries.sorted {
            displayName(for: $0, locale: locale)
                .localizedStandardCompare(displayName(for: $1, locale: locale)) == .orderedAscending
        }
    }

    static func filtered(_ countries: [CountrySetting], matching query: String, locale: Locale) -> [CountrySetting] {
        let sorted = sorted(countries, locale: locale)
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return sorted }
        let q = trimmed.lowercased()
        let folded = foldDiacritics(q)
        return sorted.filter { matchesSearch(query: q, foldedQuery: folded, country: $0, locale: locale) }
    }

    static func matchesSearch(query: String, info: TaxInfo, locale: Locale) -> Bool {
        let folded = foldDiacritics(query)
        return matchesSearch(
            query: query,
            foldedQuery: folded,
            isoCode: info.isoCode,
            englishFallback: info.name,
            locale: locale
        )
    }

    // MARK: - Private

    private static func matchesSearch(
        query: String,
        foldedQuery: String,
        country: CountrySetting,
        locale: Locale
    ) -> Bool {
        matchesSearch(
            query: query,
            foldedQuery: foldedQuery,
            isoCode: country.id,
            englishFallback: country.name,
            locale: locale
        )
    }

    private static func matchesSearch(
        query: String,
        foldedQuery: String,
        isoCode: String,
        englishFallback: String?,
        locale: Locale
    ) -> Bool {
        for term in searchTerms(isoCode: isoCode, englishFallback: englishFallback, locale: locale) {
            if term.contains(query) || term.contains(foldedQuery) { return true }
        }
        return false
    }

    private static func searchTerms(
        isoCode: String,
        englishFallback: String?,
        locale: Locale
    ) -> [String] {
        let normalized = TaxPresetLoader.normalizeCountryCode(isoCode).uppercased()
        var terms = Set<String>()
        terms.insert(normalized.lowercased())

        var locales = searchLocales
        if !locales.contains(where: { $0.identifier == locale.identifier }) {
            locales.insert(locale, at: 0)
        }

        for loc in locales {
            if let name = localizedRegionName(isoCode: normalized, locale: loc) {
                addSearchTerm(name, to: &terms)
            }
        }

        if let englishFallback {
            addSearchTerm(englishFallback, to: &terms)
        }

        for alias in CountrySearchAliasStore.aliases(for: normalized) {
            addSearchTerm(alias, to: &terms)
        }

        for (alias, code) in TaxPresetLoader.countryAliases where code == normalized {
            addSearchTerm(alias, to: &terms)
        }

        return Array(terms)
    }

    private static func addSearchTerm(_ raw: String, to terms: inout Set<String>) {
        let low = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !low.isEmpty else { return }
        terms.insert(low)
        terms.insert(foldDiacritics(low))
    }

    private static func foldDiacritics(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en"))
            .lowercased()
    }
}
