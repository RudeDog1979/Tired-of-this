//
//  MerchantDomainTLDTable.swift
//  BuxMuse
//
//  ISO 3166-1 → ordered public-suffix candidates for heuristic domain resolution.
//

import Foundation

enum MerchantDomainTLDTable {
    /// Ordered suffixes including the leading dot (e.g. `.co.uk`).
    nonisolated static func suffixes(for countryISO: String) -> [String] {
        let code = countryISO.uppercased()
        if let mapped = byCountry[code] {
            return mapped
        }
        return defaultSuffixes
    }

    private nonisolated static let defaultSuffixes = [".com", ".net", ".org"]

    private nonisolated static let byCountry: [String: [String]] = [
        "US": [".com", ".us"],
        "CA": [".ca", ".com"],
        "MX": [".com.mx", ".mx", ".com"],
        "GT": [".com.gt", ".gt", ".com"],
        "HN": [".com.hn", ".hn", ".com"],
        "SV": [".com.sv", ".sv", ".com"],
        "NI": [".com.ni", ".ni", ".com"],
        "CR": [".co.cr", ".cr", ".com"],
        "PA": [".com.pa", ".pa", ".com"],
        "BZ": [".com.bz", ".bz", ".com"],
        "DO": [".com.do", ".do", ".com"],
        "PR": [".com", ".pr"],
        "CU": [".com.cu", ".cu", ".com"],
        "HT": [".ht", ".com"],
        "JM": [".com.jm", ".jm", ".com"],
        "TT": [".co.tt", ".tt", ".com"],
        "BB": [".bb", ".com"],
        "BS": [".bs", ".com"],
        "AW": [".com", ".aw"],
        "CW": [".com", ".cw"],
        "KY": [".com", ".ky"],
        "BM": [".com", ".bm"],
        "AR": [".com.ar", ".ar", ".com"],
        "BO": [".com.bo", ".bo", ".com"],
        "BR": [".com.br", ".br", ".com"],
        "CL": [".cl", ".com"],
        "CO": [".com.co", ".co", ".com"],
        "EC": [".com.ec", ".ec", ".com"],
        "GY": [".gy", ".com"],
        "PY": [".com.py", ".py", ".com"],
        "PE": [".com.pe", ".pe", ".com"],
        "SR": [".sr", ".com"],
        "UY": [".com.uy", ".uy", ".com"],
        "VE": [".com.ve", ".ve", ".com"],
        "GB": [".co.uk", ".uk", ".com"],
        "IE": [".ie", ".com"],
        "ES": [".es", ".com"],
        "PT": [".pt", ".com"],
        "FR": [".fr", ".com"],
        "DE": [".de", ".com"],
        "IT": [".it", ".com"],
        "NL": [".nl", ".com"],
        "BE": [".be", ".com"],
        "AT": [".at", ".com"],
        "CH": [".ch", ".com"],
        "PL": [".pl", ".com"],
        "CZ": [".cz", ".com"],
        "SK": [".sk", ".com"],
        "HU": [".hu", ".com"],
        "RO": [".ro", ".com"],
        "BG": [".bg", ".com"],
        "GR": [".gr", ".com"],
        "SE": [".se", ".com"],
        "NO": [".no", ".com"],
        "DK": [".dk", ".com"],
        "FI": [".fi", ".com"],
        "UA": [".ua", ".com"],
        "AU": [".com.au", ".au", ".com"],
        "NZ": [".co.nz", ".nz", ".com"],
        "JP": [".co.jp", ".jp", ".com"],
        "IN": [".co.in", ".in", ".com"],
        "SG": [".com.sg", ".sg", ".com"],
        "HK": [".com.hk", ".hk", ".com"],
        "KR": [".co.kr", ".kr", ".com"],
        "AE": [".ae", ".com"],
        "SA": [".com.sa", ".sa", ".com"],
        "ZA": [".co.za", ".za", ".com"],
    ]
}
