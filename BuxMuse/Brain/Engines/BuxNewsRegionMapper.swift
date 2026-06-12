//
//  BuxNewsRegionMapper.swift
//  BuxMuse
//
//  Loads ISO country → content locale map from buxmuse_country_map.json.
//  Gemini generates one block per locale (ES, PT, FR…), not per country.
//

import Foundation

enum BuxNewsRegionMapper {
    private struct CountryMapPayload: Decodable {
        var countries: [String: String]
        var localeLanguages: [String: String]?
    }

    private static let countryToContentRegion: [String: String] = {
        guard let url = Bundle.main.url(forResource: "buxmuse_country_map", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let payload = try? JSONDecoder().decode(CountryMapPayload.self, from: data) else {
            return [:]
        }
        return payload.countries.mapKeys { $0.uppercased() }
    }()

    /// Resolves which `regions` key to load from buxmuse_news.json.
    static func contentRegion(for countryCode: String, availableKeys: Set<String>) -> String {
        let country = countryCode.uppercased()

        if availableKeys.contains(country) {
            return country
        }

        if let mapped = countryToContentRegion[country], availableKeys.contains(mapped) {
            return mapped
        }

        if let deviceMapped = contentRegion(forDeviceLanguage: deviceLanguageCode()),
           availableKeys.contains(deviceMapped) {
            return deviceMapped
        }

        if availableKeys.contains("DEFAULT") {
            return "DEFAULT"
        }

        return availableKeys.sorted().first ?? "DEFAULT"
    }

    private static func deviceLanguageCode() -> String? {
        Locale.current.language.languageCode?.identifier
    }

    static func contentRegion(forDeviceLanguage languageCode: String?) -> String? {
        guard let lang = languageCode?.lowercased() else { return nil }
        return languageToContentRegion[lang]
    }

    static func moneyTipTitle(for contentRegion: String) -> String {
        switch contentRegion {
        case "ES": return "Consejo de Ahorro"
        case "FR": return "Conseil Économique"
        case "DE": return "Spartipp"
        case "PT": return "Dica de Economia"
        case "IT": return "Consiglio di Risparmio"
        case "NL": return "Bespaartip"
        case "PL": return "Porada Oszczędnościowa"
        case "SE": return "Spartips"
        case "NO": return "Sparetips"
        case "DK": return "Sparetips"
        case "FI": return "Säästövinkki"
        case "RU": return "Совет по Экономии"
        case "UA": return "Порада з Економії"
        case "TR": return "Tasarruf İpucu"
        case "JP": return "節約のヒント"
        case "KR": return "절약 팁"
        case "CN": return "省钱小贴士"
        case "AE": return "نصيحة توفير"
        case "IN": return "बचत सुझाव"
        case "US": return "Money-Saving Tip"
        default: return "Today's Money Tip"
        }
    }

    static func watchOutHeader(for contentRegion: String) -> String {
        switch contentRegion {
        case "ES": return "TAMBIÉN TEN CUIDADO"
        case "FR": return "SOYEZ AUSSI VIGILANT"
        case "DE": return "ACHTEN SIE AUCH DARAUF"
        case "PT": return "FIQUE ATENTO TAMBÉM"
        case "IT": return "FAI ANCHE ATTENZIONE"
        case "NL": return "PAS OOK OP"
        case "PL": return "UWAŻAJ RÓWNIEŻ"
        case "SE": return "VAR ÄVEN UPPMÄRKSAM"
        case "NO": return "VÆR OGSÅ OBS"
        case "DK": return "VÆR OGSÅ OPMÆRKSOM"
        case "FI": return "VARO MYÖS"
        case "RU": return "БУДЬТЕ ОСТОРОЖНЫ"
        case "UA": return "БУДЬТЕ ОБЕРЕЖНІ"
        case "TR": return "Ayrıca Dikkat"
        case "JP": return "こちらも注意"
        case "KR": return "주의하세요"
        case "CN": return "也要注意"
        case "AE": return "انتبه أيضًا"
        case "IN": return "सावधान रहें"
        default: return "ALSO WATCH OUT"
        }
    }

    private static let languageToContentRegion: [String: String] = [
        "es": "ES", "fr": "FR", "de": "DE", "pt": "PT", "it": "IT", "nl": "NL",
        "pl": "PL", "sv": "SE", "no": "NO", "nb": "NO", "nn": "NO", "da": "DK",
        "fi": "FI", "ru": "RU", "uk": "UA", "tr": "TR", "ja": "JP", "ko": "KR",
        "zh": "CN", "zh-hans": "CN", "zh-hant": "CN", "ar": "AE", "hi": "IN",
        "en": "DEFAULT", "en-us": "US", "en-gb": "DEFAULT", "en-au": "DEFAULT",
        "en-ca": "DEFAULT", "en-in": "IN",
    ]
}

private extension Dictionary {
    func mapKeys<T: Hashable>(_ transform: (Key) -> T) -> [T: Value] {
        Dictionary<T, Value>(uniqueKeysWithValues: map { (transform($0.key), $0.value) })
    }
}
