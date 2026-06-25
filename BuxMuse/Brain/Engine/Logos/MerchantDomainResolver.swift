//
//  MerchantDomainResolver.swift
//  BuxMuse
//
//  Country-aware merchant domain resolution for logos and wallet imports.
//

import Foundation

enum MerchantDomainResolver {
    nonisolated private static let countryDefaultsKey = "selected_country_id"

    /// ISO 4217 → primary ISO 3166-1 country (offline; safe from background threads).
    nonisolated private static let countryISOByCurrency: [String: String] = [
        "AED": "AE", "ARS": "AR", "AUD": "AU", "BOB": "BO", "BRL": "BR", "BSD": "BS",
        "CAD": "CA", "CHF": "CH", "CLP": "CL", "COP": "CO", "CRC": "CR",
        "CUP": "CU", "CZK": "CZ", "DKK": "DK", "DOP": "DO", "EGP": "EG", "EUR": "DE",
        "GBP": "GB", "GTQ": "GT", "HKD": "HK", "HNL": "HN", "HTG": "HT", "HUF": "HU",
        "IDR": "ID", "ILS": "IL", "INR": "IN", "JMD": "JM", "JPY": "JP", "KES": "KE",
        "KRW": "KR", "MXN": "MX", "MYR": "MY", "NGN": "NG", "NIO": "NI", "NOK": "NO",
        "NZD": "NZ", "PAB": "PA", "PEN": "PE", "PHP": "PH", "PLN": "PL", "PYG": "PY",
        "RON": "RO", "RUB": "RU", "SAR": "SA", "SEK": "SE", "SGD": "SG", "TTD": "TT",
        "TRY": "TR", "UAH": "UA", "USD": "US", "UYU": "UY", "VES": "VE", "VND": "VN",
        "ZAR": "ZA",
    ]

    nonisolated static func currentCountryISO() -> String {
        if let stored = UserDefaults.standard.string(forKey: countryDefaultsKey),
           !stored.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return stored.uppercased()
        }
        return fallbackDeviceRegionCode().uppercased()
    }

    nonisolated static func resolveCountryFromCurrency(_ currencyCode: String?) -> String? {
        guard let currencyCode, !currencyCode.isEmpty else { return nil }
        return countryISOByCurrency[currencyCode.uppercased()]
    }

    /// iOS 18-safe device region — no MainActor `CountryCatalog` hop.
    nonisolated private static func fallbackDeviceRegionCode() -> String {
        var candidates: [String] = []
        if #available(iOS 16, *) {
            if let id = Locale.current.region?.identifier, !id.isEmpty {
                candidates.append(id)
            }
        }
        if let code = (Locale.current as NSLocale).object(forKey: .countryCode) as? String,
           !code.isEmpty {
            candidates.append(code)
        }
        for raw in candidates {
            let code = raw.uppercased() == "UK" ? "GB" : raw.uppercased()
            if code.count == 2 { return code }
        }
        return "US"
    }

    /// Primary resolver used by logo fetch + merchant persistence.
    /// Brand catalog always wins; never squish wallet garbage into fake `.com` hosts.
    nonisolated static func resolveDomain(
        for merchantName: String,
        countryISO: String? = nil,
        currencyCode: String? = nil
    ) -> String? {
        let country = (
            countryISO
                ?? resolveCountryFromCurrency(currencyCode)
                ?? currentCountryISO()
        ).uppercased()

        if let brandDomain = MerchantBrandIndex.resolve(label: merchantName, countryISO: country) {
            return brandDomain
        }

        if let catalogDomain = MerchantCatalog.domain(for: merchantName) {
            return catalogDomain
        }

        if let legacy = legacyKnownMerchants[MerchantLogoEngine.normalizeMerchantName(merchantName)] {
            return legacy
        }

        let intelligence = WalletStatementIntelligence.resolve(
            rawLabel: merchantName,
            contexts: []
        )
        if intelligence.confidence == .high, let domain = intelligence.domain, isPlausibleLogoHost(domain) {
            return domain
        }

        return nil
    }

    /// Rejects wallet-mangled hosts like `nq82famazon.co.uk` or `wasabi161victorialondon.com`.
    nonisolated static func isPlausibleLogoHost(_ host: String) -> Bool {
        let clean = host
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .replacingOccurrences(of: "www.", with: "")
        guard clean.count >= 4, clean.contains(".") else { return false }

        let label = clean.split(separator: ".").first.map(String.init) ?? clean
        guard label.count >= 2, label.count <= 22 else { return false }

        let digits = label.filter(\.isNumber).count
        if digits > 0 {
            if digits >= 2, digits * 2 >= label.count { return false }
            if label.range(of: #"\d{3,}"#, options: .regularExpression) != nil { return false }
        }

        return true
    }

    /// Prefer a freshly resolved catalog domain over a stale heuristic host on the merchant record.
    nonisolated static func preferredLogoDomain(stored: String?, resolved: String?) -> String? {
        if let resolved, isPlausibleLogoHost(resolved) { return resolved }
        if let stored, isPlausibleLogoHost(stored) { return stored }
        return nil
    }

    private nonisolated static let legacyKnownMerchants: [String: String] = [
        "starbucks": "starbucks.com",
        "apple": "apple.com",
        "netflix": "netflix.com",
        "spotify": "spotify.com",
        "uber": "uber.com",
        "amazon": "amazon.co.uk",
        "amzn": "amazon.co.uk",
        "mcdonalds": "mcdonalds.com",
        "nike": "nike.com",
        "google": "google.com",
        "microsoft": "microsoft.com",
        "airbnb": "airbnb.com",
        "walmart": "walmart.com",
        "target": "target.com",
        "steam": "steampowered.com",
        "playstation": "playstation.com",
        "xbox": "xbox.com",
        "roblox": "roblox.com",
        "cursor": "cursor.com",
    ]
}
