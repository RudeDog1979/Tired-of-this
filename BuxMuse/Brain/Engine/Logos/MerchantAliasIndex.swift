//
//  MerchantAliasIndex.swift
//  BuxMuse
//
//  Auto-generated aliases (compact, acronym, consonant skeleton, domain stem) for catalog brands.
//

import Foundation

enum MerchantAliasIndex {
    private struct AliasHit: Sendable {
        let domain: String
        let aliasLength: Int
    }

    private nonisolated static let aliasMap: [String: AliasHit] = buildAliasMap()

    /// Resolves statement abbreviations like PYPL → paypal.com without per-merchant hardcoding.
    nonisolated static func domain(for alias: String) -> String? {
        let trimmed = alias.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let normalized = MerchantLogoEngine.normalizeMerchantName(trimmed)
        let compact = normalized.replacingOccurrences(of: " ", with: "")
        let skeleton = consonantSkeleton(trimmed)
        let uppercaseCompact = trimmed
            .filter { $0.isLetter }
            .lowercased()

        let keys = [normalized, compact, uppercaseCompact]
            .filter { $0.count >= 2 }
        for key in keys {
            if let hit = aliasMap[key] { return hit.domain }
        }

        if skeleton.count >= 4, let hit = aliasMap[skeleton] { return hit.domain }
        return nil
    }

    /// Consonant skeleton for tickers / bank abbreviations (PayPal → pypl, Amazon → amzn).
    nonisolated static func consonantSkeleton(_ text: String) -> String {
        let normalized = MerchantLogoEngine.normalizeMerchantName(text)
        let compact = normalized.replacingOccurrences(of: " ", with: "")
        guard !compact.isEmpty else { return "" }

        let words = normalized.split(separator: " ").map(String.init)
        if words.count >= 2 {
            let initials = words.compactMap(\.first).map { String($0) }.joined()
            if initials.count >= 2 { return initials }
        }

        let vowels: Set<Character> = ["a", "e", "i", "o", "u"]
        var result = ""
        for (index, char) in compact.enumerated() {
            if index == 0 {
                result.append(char)
            } else if !vowels.contains(char) {
                result.append(char)
            }
        }
        return result
    }

    private nonisolated static func buildAliasMap() -> [String: AliasHit] {
        var map: [String: AliasHit] = [:]

        func register(_ alias: String, domain: String) {
            let key = alias.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard key.count >= 2 else { return }
            let hit = AliasHit(domain: domain, aliasLength: key.count)
            if let existing = map[key], existing.aliasLength > hit.aliasLength { return }
            map[key] = hit
        }

        for entry in MerchantBrandIndex.entries {
            register(domainStem(entry.domain), domain: entry.domain)
            for token in entry.normalizedTokens {
                register(token, domain: entry.domain)
                register(token.replacingOccurrences(of: " ", with: ""), domain: entry.domain)
                let skeleton = consonantSkeleton(token)
                if skeleton.count >= 4 {
                    register(skeleton, domain: entry.domain)
                }
            }
        }

        for entry in MerchantCatalog.entries {
            register(domainStem(entry.domain), domain: entry.domain)
            for name in entry.searchNames + [entry.displayName] {
                let normalized = MerchantLogoEngine.normalizeMerchantName(name)
                register(normalized, domain: entry.domain)
                register(normalized.replacingOccurrences(of: " ", with: ""), domain: entry.domain)
                let skeleton = consonantSkeleton(name)
                if skeleton.count >= 4 {
                    register(skeleton, domain: entry.domain)
                }
                let rawLetters = name.filter { $0.isLetter }
                if rawLetters.count >= 2, name == name.uppercased() {
                    register(rawLetters.lowercased(), domain: entry.domain)
                }
            }
        }

        return map
    }

    private nonisolated static func domainStem(_ domain: String) -> String {
        domain
            .lowercased()
            .replacingOccurrences(of: "www.", with: "")
            .split(separator: ".")
            .first
            .map(String.init) ?? domain
    }
}
