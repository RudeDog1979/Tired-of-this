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

        for candidate in MerchantLabelParser.resolveCandidates(from: merchantName) {
            if let domain = resolveCandidate(candidate, countryISO: country) {
                return domain
            }
        }

        return guessDomainFromBrandTokens(
            MerchantLabelParser.brandTokens(from: merchantName),
            countryISO: country
        )
    }

    private nonisolated static func resolveCandidate(_ label: String, countryISO: String) -> String? {
        if let domain = MerchantAliasIndex.domain(for: label), isPlausibleLogoHost(domain) {
            return domain
        }
        if let domain = MerchantBrandIndex.resolve(label: label, countryISO: countryISO),
           isPlausibleLogoHost(domain) {
            return domain
        }
        if let domain = MerchantCatalog.domain(for: label, allowFuzzy: false), isPlausibleLogoHost(domain) {
            return domain
        }

        let normalized = MerchantLogoEngine.normalizeMerchantName(label)
        if let legacy = legacyKnownMerchants[normalized], isPlausibleLogoHost(legacy) {
            return legacy
        }

        let intelligence = WalletStatementIntelligence.resolve(
            rawLabel: label,
            contexts: []
        )
        if intelligence.confidence == .high,
           let domain = intelligence.domain,
           isPlausibleLogoHost(domain) {
            return domain
        }

        return nil
    }

    /// Brand-led statement labels → token + country TLD (Domino Pizza Milton → dominos.co.uk).
    private nonisolated static func guessDomainFromBrandTokens(
        _ words: [String],
        countryISO: String
    ) -> String? {
        guard !words.isEmpty, words.count <= 6 else { return nil }
        let joined = words.joined(separator: " ")
        guard joined.rangeOfCharacter(from: .decimalDigits) == nil else { return nil }

        let qualifies: Bool
        if words.count == 1 {
            qualifies = words[0].count >= 4 && !categoryDescriptorTokens.contains(words[0])
        } else {
            qualifies = words.contains { categoryDescriptorTokens.contains($0) }
        }
        guard qualifies else { return nil }

        let primary = words[0]
        guard primary.count >= 4, primary.count <= 18, primary.allSatisfy(\.isLetter) else { return nil }

        for stem in domainStems(
            for: primary,
            preferPlural: words.contains { categoryDescriptorTokens.contains($0) }
        ) {
            for suffix in MerchantDomainTLDTable.suffixes(for: countryISO) {
                let host = stem + suffix
                if isPlausibleLogoHost(host) { return host }
            }
        }
        return nil
    }

    private nonisolated static let categoryDescriptorTokens: Set<String> = [
        "pizza", "coffee", "shop", "store", "market", "express", "mobile", "online",
        "restaurant", "cafe", "bakery", "pharmacy", "supermarket", "grocery", "foods",
        "kitchen", "grill", "burger", "chicken", "sushi", "delivery", "services",
    ]

    private nonisolated static func domainStems(for primary: String, preferPlural: Bool = false) -> [String] {
        var stems: [String] = []
        func append(_ value: String) {
            guard !value.isEmpty, !stems.contains(value) else { return }
            stems.append(value)
        }

        if preferPlural, !primary.hasSuffix("s") {
            append(primary + "s")
            append(primary)
            append(primary + "es")
        } else {
            append(primary)
            if !primary.hasSuffix("s") {
                append(primary + "s")
                append(primary + "es")
            }
        }
        if primary.hasSuffix("s"), primary.count > 3 {
            append(String(primary.dropLast()))
        }
        return stems
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
