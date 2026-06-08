//
//  CountrySearchAliasStore.swift
//  BuxMuse
//
//  Bundled search aliases per ISO code — display names stay in CLDR via CountryDisplayL10n.
//

import Foundation

struct CountrySearchAliasPayload: Decodable {
    var version: Int
    var batch: Int
    var complete: Bool
    var totalRegions: Int
    var includedRegions: Int
    var countries: [String: [String]]
}

enum CountrySearchAliasStore {
    private static let resourceName = "country_search_aliases"

    private static let payload: CountrySearchAliasPayload? = {
        guard let url = Bundle.main.url(forResource: resourceName, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(CountrySearchAliasPayload.self, from: data) else {
            return nil
        }
        return decoded
    }()

    static var isComplete: Bool { payload?.complete ?? false }

    static func aliases(for isoCode: String) -> [String] {
        let code = TaxPresetLoader.normalizeCountryCode(isoCode).uppercased()
        return payload?.countries[code] ?? []
    }
}
