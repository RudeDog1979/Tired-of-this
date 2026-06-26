//
//  MerchantLabelParser.swift
//  BuxMuse
//
//  Turns messy bank / wallet labels into ordered resolution candidates.
//

import Foundation

enum MerchantLabelParser {
    private nonisolated static let categoryDescriptors: Set<String> = [
        "pizza", "coffee", "shop", "store", "market", "express", "mobile", "online",
        "restaurant", "cafe", "bakery", "pharmacy", "supermarket", "grocery", "foods",
        "kitchen", "grill", "burger", "chicken", "sushi", "delivery", "services",
        "hotel", "motors", "garage", "fuel", "petrol", "gas", "bank", "atm",
    ]

    private nonisolated static let structuralNoise: Set<String> = [
        "ltd", "limited", "inc", "llc", "corp", "plc", "gbr", "uk", "usa", "the", "and",
        "store", "branch", "outlet", "unit", "pos", "ecom", "online", "contactless",
    ]

    /// Ordered candidates — most specific first.
    nonisolated static func resolveCandidates(from rawLabel: String) -> [String] {
        var results: [String] = []
        var seen = Set<String>()

        func add(_ value: String) {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.count >= 2 else { return }
            let key = trimmed.lowercased()
            guard seen.insert(key).inserted else { return }
            results.append(trimmed)
        }

        let stripped = stripProcessorPrefixes(rawLabel)
        add(stripped)

        let lettersOnly = stripped.filter { $0.isLetter }
        let nonSpace = stripped.filter { !$0.isWhitespace }
        if !nonSpace.isEmpty,
           lettersOnly.count == nonSpace.count,
           stripped == stripped.uppercased(),
           (3 ... 6).contains(lettersOnly.count) {
            add(stripped.lowercased())
        }

        let normalized = MerchantLogoEngine.normalizeMerchantName(stripped)
        add(normalized)
        add(normalized.replacingOccurrences(of: " ", with: ""))

        var tokens = normalized
            .split(separator: " ")
            .map(String.init)
            .filter { !$0.isEmpty && !structuralNoise.contains($0) }
        tokens = stripTrailingLocationTokens(tokens)

        if tokens.count >= 2 {
            for size in stride(from: min(4, tokens.count), through: 2, by: -1) {
                if tokens.count >= size {
                    for start in 0 ... (tokens.count - size) {
                        let slice = tokens[start ..< (start + size)]
                        add(slice.joined(separator: " "))
                        add(slice.joined())
                    }
                }
            }
        }

        for token in tokens where token.count >= 3 {
            add(token)
        }

        let compact = normalized.replacingOccurrences(of: " ", with: "")
        if let embedded = MerchantBrandIndex.embeddedBrandToken(in: compact) {
            add(embedded)
        }

        return results
    }

    /// Significant brand tokens after stripping statement noise (for domain guessing).
    nonisolated static func brandTokens(from rawLabel: String) -> [String] {
        let stripped = stripProcessorPrefixes(rawLabel)
        let normalized = MerchantLogoEngine.normalizeMerchantName(stripped)
        var tokens = normalized
            .split(separator: " ")
            .map(String.init)
            .filter { token in
                guard token.count >= 3 else { return false }
                guard !structuralNoise.contains(token) else { return false }
                guard token.rangeOfCharacter(from: .decimalDigits) == nil else { return false }
                return true
            }
        tokens = stripTrailingLocationTokens(tokens)
        return tokens
    }

    private nonisolated static func stripTrailingLocationTokens(_ words: [String]) -> [String] {
        var trimmed = words
        while trimmed.count >= 3 {
            guard let last = trimmed.last else { break }
            if categoryDescriptors.contains(last) || structuralNoise.contains(last) { break }
            if last.count < 4 { break }
            trimmed.removeLast()
        }
        return trimmed
    }

    private nonisolated static func stripProcessorPrefixes(_ text: String) -> String {
        var working = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if let starRange = working.range(of: "*") {
            let tail = working[starRange.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
            if tail.count >= 3 { working = tail }
        }

        let wrapPrefixes = [
            "sq ", "sumup ", "amzn ", "amz ", "apple pay ", "google pay ",
            "visa debit ", "mc debit ", "contactless ", "pypl ", "paypal ",
        ]
        let lower = working.lowercased()
        for prefix in wrapPrefixes {
            if lower.hasPrefix(prefix) {
                working = String(working.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                break
            }
        }

        return working
    }
}
