//
//  CountrySetting.swift
//  BuxMuse
//
//  ISO 3166-1 region catalog for global locale identity.
//

import Foundation

public struct CountrySetting: Identifiable, Equatable, Hashable {
    public let id: String
    public let name: String
    public let flag: String
    public let defaultCurrencyCode: String
    public let localeIdentifier: String

    public init(id: String, name: String, flag: String, defaultCurrencyCode: String, localeIdentifier: String) {
        self.id = id
        self.name = name
        self.flag = flag
        self.defaultCurrencyCode = defaultCurrencyCode
        self.localeIdentifier = localeIdentifier
    }
}

public enum CountryCatalog {
    private static let displayLocale = Locale(identifier: "en")

    /// All ISO country regions, sorted by localized name.
    public static let allCountries: [CountrySetting] = {
        countryRegions
            .map { region in
                let code = region.identifier
                return CountrySetting(
                    id: code,
                    name: displayLocale.localizedString(forRegionCode: code) ?? code,
                    flag: flagEmoji(for: code),
                    defaultCurrencyCode: defaultCurrencyCode(for: code),
                    localeIdentifier: "en_\(code)"
                )
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }()

    /// ISO countries only — excludes macro-regions like "001".
    private static var countryRegions: [Locale.Region] {
        if #available(iOS 26, *) {
            return Locale.Region.isoRegions(ofCategory: .territory)
                .filter { $0.identifier.count == 2 }
        }
        return Locale.Region.isoRegions.filter { $0.identifier.count == 2 }
    }

    public static func country(for isoCode: String) -> CountrySetting? {
        let normalized = isoCode.uppercased()
        return allCountries.first { $0.id == normalized }
    }

    public static func filtered(matching query: String) -> [CountrySetting] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return allCountries }
        return allCountries.filter {
            $0.name.lowercased().contains(q) ||
            $0.id.lowercased().contains(q)
        }
    }

    private static func normalizeRegionCode(_ raw: String) -> String {
        switch raw.uppercased() {
        case "UK": return "GB"
        default: return raw.uppercased()
        }
    }

    /// Device region (Settings → General → Region), with iOS 18-safe fallbacks.
    public static func deviceRegionCode() -> String {
        var candidates: [String] = []
        for locale in [Locale.autoupdatingCurrent, Locale.current] {
            if #available(iOS 16, *) {
                if let id = locale.region?.identifier, !id.isEmpty {
                    candidates.append(id)
                }
                if let id = locale.language.region?.identifier, !id.isEmpty {
                    candidates.append(id)
                }
            }
            if let code = (locale as NSLocale).object(forKey: .countryCode) as? String, !code.isEmpty {
                candidates.append(code)
            }
        }
        for raw in candidates {
            let code = normalizeRegionCode(raw)
            if code.count == 2, country(for: code) != nil {
                return code
            }
        }
        if let first = candidates.first {
            return normalizeRegionCode(first)
        }
        return "US"
    }

    public static func detectedFromDevice() -> CountrySetting {
        let code = normalizeRegionCode(deviceRegionCode())
        if let match = country(for: code) {
            return match
        }
        return synthesizedCountry(for: code) ?? country(for: "US") ?? allCountries[0]
    }

    /// When ISO catalog omits a device region (edge cases), still honor region + currency.
    private static func synthesizedCountry(for code: String) -> CountrySetting? {
        guard code.count == 2 else { return nil }
        return CountrySetting(
            id: code,
            name: displayLocale.localizedString(forRegionCode: code) ?? code,
            flag: flagEmoji(for: code),
            defaultCurrencyCode: defaultCurrencyCode(for: code),
            localeIdentifier: "en_\(code)"
        )
    }

    public static func flagEmoji(for countryCode: String) -> String {
        let code = countryCode.uppercased()
        guard code.count == 2 else { return "🏳️" }
        let base: UInt32 = 127397
        var flag = ""
        for scalar in code.unicodeScalars {
            guard let regional = UnicodeScalar(base + scalar.value) else { return "🏳️" }
            flag.unicodeScalars.append(regional)
        }
        return flag
    }

    public static func defaultCurrencyCode(for regionCode: String) -> String {
        if let mapped = regionCurrencyOverrides[regionCode.uppercased()] {
            return mapped
        }
        let locale = Locale(identifier: "en_\(regionCode.uppercased())")
        if let currency = locale.currency?.identifier {
            return currency
        }
        return "USD"
    }

    /// Common region → currency mappings (ISO 4217).
    private static let regionCurrencyOverrides: [String: String] = [
        "US": "USD", "GB": "GBP", "EU": "EUR", "DE": "EUR", "FR": "EUR", "ES": "EUR",
        "IT": "EUR", "NL": "EUR", "BE": "EUR", "IE": "EUR", "PT": "EUR", "AT": "EUR",
        "FI": "EUR", "GR": "EUR", "CA": "CAD", "AU": "AUD", "NZ": "NZD", "JP": "JPY",
        "CN": "CNY", "IN": "INR", "MX": "MXN", "BR": "BRL", "ZA": "ZAR", "CH": "CHF",
        "SE": "SEK", "NO": "NOK", "DK": "DKK", "PL": "PLN", "TR": "TRY", "RU": "RUB",
        "KR": "KRW", "SG": "SGD", "HK": "HKD", "TW": "TWD", "TH": "THB", "MY": "MYR",
        "ID": "IDR", "PH": "PHP", "VN": "VND", "AE": "AED", "SA": "SAR", "IL": "ILS",
        "EG": "EGP", "NG": "NGN", "KE": "KES", "AR": "ARS", "CL": "CLP", "CO": "COP",
        "DO": "DOP", "PR": "USD", "UA": "UAH", "CZ": "CZK", "HU": "HUF", "RO": "RON"
    ]
}
