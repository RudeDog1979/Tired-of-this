//
//  MerchantBrandIndex.swift
//  BuxMuse
//
//  Offline token → domain index for wallet labels and merchant names.
//

import Foundation

struct MerchantBrandEntry: Sendable, Equatable {
    let displayName: String
    let domain: String
    let tokens: [String]
    /// ISO 3166-1 codes; empty = global brand.
    let countries: [String]

    nonisolated var normalizedTokens: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for raw in tokens + [displayName] {
            let norm = MerchantLogoEngine.normalizeMerchantName(raw)
            guard norm.count >= 3, !seen.contains(norm) else { continue }
            seen.insert(norm)
            result.append(norm)
            let compact = norm.replacingOccurrences(of: " ", with: "")
            if compact.count >= 3, !seen.contains(compact) {
                seen.insert(compact)
                result.append(compact)
            }
        }
        return result
    }
}

enum MerchantBrandIndex {
    private struct SubstringCandidate: Sendable {
        let token: String
        let domain: String
        let countries: Set<String>
        let tokenLength: Int
    }

    nonisolated private static let catalogEntries: [MerchantBrandEntry] = MerchantCatalog.entries.map {
        MerchantBrandEntry(
            displayName: $0.displayName,
            domain: $0.domain,
            tokens: $0.searchNames,
            countries: []
        )
    }

    nonisolated static let entries: [MerchantBrandEntry] = catalogEntries + MerchantBrandRegionalEntries.all

    nonisolated private static let exactTokenMap: [String: MerchantBrandEntry] = {
        var map: [String: MerchantBrandEntry] = [:]
        for entry in entries {
            for token in entry.normalizedTokens {
                if let existing = map[token], existing.domain != entry.domain {
                    if token.count < 5 { continue }
                }
                map[token] = entry
            }
        }
        return map
    }()

    nonisolated private static let substringCandidates: [SubstringCandidate] = {
        var seen = Set<String>()
        var result: [SubstringCandidate] = []
        for entry in entries {
            for token in entry.normalizedTokens where token.count >= 4 {
                let key = "\(token)|\(entry.domain)"
                guard seen.insert(key).inserted else { continue }
                result.append(
                    SubstringCandidate(
                        token: token,
                        domain: entry.domain,
                        countries: Set(entry.countries.map { $0.uppercased() }),
                        tokenLength: token.count
                    )
                )
            }
        }
        return result.sorted { lhs, rhs in
            if lhs.tokenLength != rhs.tokenLength { return lhs.tokenLength > rhs.tokenLength }
            return lhs.token < rhs.token
        }
    }()

    /// Best domain for a raw wallet / merchant label.
    nonisolated static func resolve(label: String, countryISO: String) -> String? {
        let normalized = MerchantLogoEngine.normalizeMerchantName(label)
        guard !normalized.isEmpty else { return nil }

        let country = countryISO.uppercased()
        let compact = normalized.replacingOccurrences(of: " ", with: "")

        if let hit = exactTokenMap[normalized] ?? exactTokenMap[compact] {
            return hit.domain
        }

        let words = normalized.split(separator: " ").map(String.init)
        for word in words where word.count >= 3 {
            if let hit = exactTokenMap[word] {
                return hit.domain
            }
        }

        var bestScore = 0
        var bestDomain: String?
        for candidate in substringCandidates {
            guard matchesToken(
                candidate.token,
                normalized: normalized,
                compact: compact
            ) else { continue }
            var score = candidate.tokenLength * 10
            if candidate.countries.isEmpty || candidate.countries.contains(country) {
                score += 60
            } else if !candidate.countries.isEmpty {
                score -= 20
            }
            if score > bestScore {
                bestScore = score
                bestDomain = candidate.domain
            }
        }
        return bestDomain
    }

    /// Wallet-mangled compact labels: `nq82famazon` → Amazon, `robloxcorp` → Roblox.
    nonisolated static func embeddedBrandToken(in compact: String) -> String? {
        let normalized = compact.lowercased().filter { $0.isLetter || $0.isNumber }
        guard normalized.count >= 5 else { return nil }

        var bestToken: String?
        var bestLength = 0
        for candidate in substringCandidates where candidate.token.count >= 4 {
            guard matchesEmbeddedToken(candidate.token, in: normalized) else { continue }
            if candidate.token.count > bestLength {
                bestLength = candidate.token.count
                bestToken = candidate.token
            }
        }
        return bestToken
    }

    nonisolated static func resolveEmbedded(in compact: String, countryISO: String) -> String? {
        guard let token = embeddedBrandToken(in: compact) else { return nil }
        return resolve(label: token, countryISO: countryISO)
    }

    /// Word-boundary token match — avoids `dino` ⊂ `dominos`, `super` ⊂ `supermarkets`, etc.
    private nonisolated static func matchesToken(
        _ token: String,
        normalized: String,
        compact: String
    ) -> Bool {
        if normalized == token || compact == token { return true }

        let words = normalized.split(separator: " ").map(String.init)
        if words.contains(token) { return true }

        let allowedSuffixes: Set<String> = ["s", "es", "co", "uk", "ie", "gb"]
        for word in words where word.hasPrefix(token) && word.count > token.count {
            let suffix = String(word.dropFirst(token.count))
            guard word.count - token.count <= 2, allowedSuffixes.contains(suffix) else { continue }
            return true
        }

        if compact.hasPrefix(token) {
            let remainder = String(compact.dropFirst(token.count))
            if remainder.isEmpty { return true }
            if remainder.count <= 2, allowedSuffixes.contains(remainder) { return true }
        }

        return false
    }

    private nonisolated static func matchesEmbeddedToken(_ token: String, in compact: String) -> Bool {
        guard let range = compact.range(of: token) else { return false }

        let before = String(compact[..<range.lowerBound])
        let after = String(compact[range.upperBound...])

        if before.count > 10 { return false }
        if before.filter(\.isNumber).count > 6 { return false }

        if after.isEmpty { return true }

        let allowedAfter: Set<String> = [
            "corp", "corporation", "ltd", "limited", "inc", "llc", "plc", "co", "uk", "com",
        ]
        if allowedAfter.contains(after) { return true }
        if after.count <= 2, after.allSatisfy(\.isLetter) { return true }
        return false
    }
}
