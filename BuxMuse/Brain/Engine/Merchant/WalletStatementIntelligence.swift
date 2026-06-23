//
//  WalletStatementIntelligence.swift
//  BuxMuse
//
//  Algorithmic Apple Wallet / card-statement label resolution — no hardcoded merchant lists.
//

import Foundation

// MARK: - Types

public enum WalletMatchConfidence: Sendable {
    case high
    case medium
    case low

    public nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.high, .high), (.medium, .medium), (.low, .low): return true
        default: return false
        }
    }
}

public enum WalletMatchSource: Sendable {
    case extractedDomain
    case existingMerchant
    case fuzzyMerchant
    case tokenHeuristic
    case unresolved

    public nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.extractedDomain, .extractedDomain),
             (.existingMerchant, .existingMerchant),
             (.fuzzyMerchant, .fuzzyMerchant),
             (.tokenHeuristic, .tokenHeuristic),
             (.unresolved, .unresolved):
            return true
        default:
            return false
        }
    }
}

public struct WalletMerchantContext: Sendable {
    public let id: UUID
    public let displayName: String
    public let normalizedName: String
    public let domain: String?
    public let statementLabels: [String]

    public nonisolated init(
        id: UUID,
        displayName: String,
        normalizedName: String,
        domain: String?,
        statementLabels: [String]
    ) {
        self.id = id
        self.displayName = displayName
        self.normalizedName = normalizedName
        self.domain = domain
        self.statementLabels = statementLabels
    }

    public nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
            && lhs.displayName == rhs.displayName
            && lhs.normalizedName == rhs.normalizedName
            && lhs.domain == rhs.domain
            && lhs.statementLabels == rhs.statementLabels
    }
}

public struct WalletStatementResolution: Sendable {
    public let canonicalName: String
    public let domain: String?
    public let matchedMerchantId: UUID?
    public let confidence: WalletMatchConfidence
    public let rawLabel: String
    public let matchSource: WalletMatchSource

    public nonisolated init(
        canonicalName: String,
        domain: String?,
        matchedMerchantId: UUID?,
        confidence: WalletMatchConfidence,
        rawLabel: String,
        matchSource: WalletMatchSource
    ) {
        self.canonicalName = canonicalName
        self.domain = domain
        self.matchedMerchantId = matchedMerchantId
        self.confidence = confidence
        self.rawLabel = rawLabel
        self.matchSource = matchSource
    }

    public nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.canonicalName == rhs.canonicalName
            && lhs.domain == rhs.domain
            && lhs.matchedMerchantId == rhs.matchedMerchantId
            && lhs.confidence == rhs.confidence
            && lhs.rawLabel == rhs.rawLabel
            && lhs.matchSource == rhs.matchSource
    }
}

// MARK: - Engine

public enum WalletStatementIntelligence {
    /// Generic payment / descriptor words — structural, not brand names.
    private nonisolated static let noiseTokens: Set<String> = [
        "payment", "purchase", "transaction", "debit", "credit", "card", "visa", "mastercard",
        "amex", "contactless", "online", "store", "shop", "services", "service", "transfer",
        "withdrawal", "deposit", "auth", "ref", "reference", "ltd", "inc", "llc", "corp",
        "co", "sa", "limited", "incorporated", "gbr", "gbp", "usd", "eur", "pln", "chf",
        "london", "uk", "usa", "the", "and", "for", "from", "via", "bill", "billing",
        "subscription", "monthly", "annual", "recurring", "merchant", "retail", "ecom",
        "iat", "pos", "pending", "completed", "approved", "declined", "wallet", "digital",
        "mobile", "app", "com", "www", "http", "https", "pay", "pro", "plus", "premium",
        "business", "personal", "account", "checking", "savings", "fee", "charge", "total",
        "amount", "sale", "direct", "order", "invoice", "receipt", "member", "customer",
        "processing", "processor", "authorization", "authorised", "authorized", "settlement",
    ]

    public nonisolated static func resolve(
        rawLabel: String,
        contexts: [WalletMerchantContext]
    ) -> WalletStatementResolution {
        let trimmed = rawLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return WalletStatementResolution(
                canonicalName: "",
                domain: nil,
                matchedMerchantId: nil,
                confidence: .low,
                rawLabel: rawLabel,
                matchSource: .unresolved
            )
        }

        let stripped = stripProcessorPrefixes(trimmed)
        if let extracted = extractDomain(from: stripped) {
            let canonical = titleCaseDomainBrand(extracted)
            return WalletStatementResolution(
                canonicalName: canonical,
                domain: extracted,
                matchedMerchantId: matchExistingMerchant(
                    canonicalName: canonical,
                    domain: extracted,
                    tokens: tokenize(stripped),
                    contexts: contexts
                )?.id,
                confidence: .high,
                rawLabel: rawLabel,
                matchSource: .extractedDomain
            )
        }

        let tokens = significantTokens(from: stripped)
        let normalizedFull = MerchantLogoEngine.normalizeMerchantName(stripped)

        if let exact = matchByNormalizedLabel(normalizedFull, contexts: contexts) {
            return resolution(
                for: exact,
                canonicalName: exact.displayName,
                domain: exact.domain ?? domainHeuristic(from: tokens, fallbackName: exact.displayName),
                rawLabel: rawLabel,
                source: .existingMerchant,
                confidence: .high
            )
        }

        if let statementMatch = matchByStatementLabels(stripped, normalizedFull: normalizedFull, contexts: contexts) {
            return resolution(
                for: statementMatch,
                canonicalName: statementMatch.displayName,
                domain: statementMatch.domain ?? domainHeuristic(from: tokens, fallbackName: statementMatch.displayName),
                rawLabel: rawLabel,
                source: .existingMerchant,
                confidence: .high
            )
        }

        if let fuzzy = fuzzyMatchMerchant(tokens: tokens, normalizedFull: normalizedFull, contexts: contexts) {
            return resolution(
                for: fuzzy.context,
                canonicalName: fuzzy.context.displayName,
                domain: fuzzy.context.domain ?? domainHeuristic(from: tokens, fallbackName: fuzzy.context.displayName),
                rawLabel: rawLabel,
                source: .fuzzyMerchant,
                confidence: fuzzy.distance <= 1 ? .high : .medium
            )
        }

        let canonical = canonicalName(from: tokens, fallback: stripped)
        let domain = domainHeuristic(from: tokens, fallbackName: canonical)
        let confidence: WalletMatchConfidence = domain == nil ? .low : .medium

        return WalletStatementResolution(
            canonicalName: canonical,
            domain: domain,
            matchedMerchantId: nil,
            confidence: confidence,
            rawLabel: rawLabel,
            matchSource: domain == nil ? .unresolved : .tokenHeuristic
        )
    }

    public nonisolated static let walletImportNotePrefix = "wallet_import:"

    private nonisolated static let legacyWalletImportOnly = "Imported from Apple Wallet"
    private nonisolated static let legacyWalletImportMarker = "Imported from Apple Wallet · "

    /// Language-neutral persisted note for wallet imports (`wallet_import:STATEMENT_LABEL`).
    public nonisolated static func walletImportNotes(rawLabel: String) -> String {
        let trimmed = rawLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return walletImportNotePrefix }
        return walletImportNotePrefix + trimmed
    }

    public nonisolated static func isWalletImportNote(_ notes: String) -> Bool {
        let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix(walletImportNotePrefix) { return true }
        if trimmed == legacyWalletImportOnly { return true }
        return trimmed.hasPrefix(legacyWalletImportMarker)
    }

    /// Parses the raw statement label from stored wallet import notes (new + legacy English).
    public nonisolated static func rawLabelFromStoredNote(_ notes: String) -> String? {
        let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix(walletImportNotePrefix) {
            let raw = String(trimmed.dropFirst(walletImportNotePrefix.count))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return raw.isEmpty ? nil : raw
        }
        if trimmed.hasPrefix(legacyWalletImportMarker) {
            let raw = String(trimmed.dropFirst(legacyWalletImportMarker.count))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return raw.isEmpty ? nil : raw
        }
        if trimmed == legacyWalletImportOnly { return nil }
        return nil
    }

    public nonisolated static func localizedWalletImportNote(stored: String, locale: Locale) -> String {
        guard isWalletImportNote(stored) else { return stored }
        if let raw = rawLabelFromStoredNote(stored) {
            return BuxLocalizedString.format("Imported from Apple Wallet · %@", locale: locale, raw)
        }
        return BuxLocalizedString.string("Imported from Apple Wallet", locale: locale)
    }

    /// Best-effort wallet statement label for reconcile — notes first, then merchant/name.
    nonisolated static func walletRawLabel(for record: ExpenseRecord) -> String {
        if let notes = record.notes,
           let raw = rawLabelFromStoredNote(notes) {
            return raw
        }
        let merchant = record.merchantName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !merchant.isEmpty { return merchant }
        return record.name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Domain extraction

    private nonisolated static func extractDomain(from text: String) -> String? {
        let candidates = [
            #"(?i)https?://([^/\s]+)"#,
            #"(?i)www\.([^/\s]+)"#,
            #"(?i)\b([a-z0-9][a-z0-9-]*\.(?:co\.uk|com\.pl|co\.pl|com|net|org|io|app|pl|uk|de|fr|eu))\b"#,
        ]

        for pattern in candidates {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            guard let match = regex.firstMatch(in: text, range: range),
                  match.numberOfRanges > 1,
                  let capture = Range(match.range(at: 1), in: text) else { continue }
            let host = String(text[capture])
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
                .replacingOccurrences(of: "www.", with: "")
            if isPlausibleDomain(host) { return host }
        }

        // Glued URL labels like WWW.VOXI.COM after punctuation removal in other paths.
        let compact = text.lowercased().replacingOccurrences(of: " ", with: "")
        if let regex = try? NSRegularExpression(pattern: #"(?i)(?:www\.)?([a-z0-9-]+\.(?:co\.uk|com\.pl|co\.pl|com|net|org|io|app|pl|uk))"#),
           let match = regex.firstMatch(in: compact, range: NSRange(compact.startIndex..<compact.endIndex, in: compact)),
           match.numberOfRanges > 1,
           let capture = Range(match.range(at: 1), in: compact) {
            let host = String(compact[capture])
            if isPlausibleDomain(host) { return host }
        }

        return nil
    }

    private nonisolated static func isPlausibleDomain(_ host: String) -> Bool {
        guard host.count >= 4, host.contains(".") else { return false }
        let parts = host.split(separator: ".")
        guard parts.count >= 2, parts.allSatisfy({ !$0.isEmpty }) else { return false }
        return !host.hasPrefix(".") && !host.hasSuffix(".")
    }

    // MARK: - Tokenization

    private nonisolated static func stripProcessorPrefixes(_ text: String) -> String {
        var working = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if let starRange = working.range(of: "*") {
            let tail = working[starRange.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
            if tail.count >= 3 { working = tail }
        }

        let wrapPrefixes = [
            "sq ", "sumup ", "amzn ", "amz ", "apple pay ", "google pay ",
            "visa debit ", "mc debit ", "contactless ",
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

    private nonisolated static func tokenize(_ text: String) -> [String] {
        MerchantLogoEngine.normalizeMerchantName(text)
            .split(separator: " ")
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    private nonisolated static func significantTokens(from text: String) -> [String] {
        tokenize(text).filter { token in
            guard token.count >= 2 else { return false }
            guard !noiseTokens.contains(token) else { return false }
            guard token.rangeOfCharacter(from: .decimalDigits) == nil || token.count >= 5 else { return false }
            return true
        }
    }

    private nonisolated static func canonicalName(from tokens: [String], fallback: String) -> String {
        guard !tokens.isEmpty else {
            return titleCase(fallback.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        let joined = tokens.prefix(3).joined(separator: " ")
        return titleCase(joined)
    }

    private nonisolated static func domainHeuristic(from tokens: [String], fallbackName: String) -> String? {
        if let domain = extractDomain(from: fallbackName) { return domain }
        guard let primary = tokens.first(where: { $0.count >= 3 }) ?? tokens.first else { return nil }
        let squished = primary.replacingOccurrences(of: " ", with: "")
        guard squished.count >= 3 else { return nil }
        return "\(squished).com"
    }

    // MARK: - Merchant matching

    private nonisolated static func matchByNormalizedLabel(
        _ normalized: String,
        contexts: [WalletMerchantContext]
    ) -> WalletMerchantContext? {
        guard !normalized.isEmpty else { return nil }
        return contexts.first { $0.normalizedName == normalized }
    }

    private nonisolated static func matchByStatementLabels(
        _ raw: String,
        normalizedFull: String,
        contexts: [WalletMerchantContext]
    ) -> WalletMerchantContext? {
        let rawLower = raw.lowercased()
        for context in contexts {
            for label in context.statementLabels {
                let norm = MerchantLogoEngine.normalizeMerchantName(label)
                if norm == normalizedFull || label.caseInsensitiveCompare(raw) == .orderedSame {
                    return context
                }
                if rawLower.contains(label.lowercased()) || label.lowercased().contains(rawLower) {
                    return context
                }
            }
        }
        return nil
    }

    private nonisolated static func fuzzyMatchMerchant(
        tokens: [String],
        normalizedFull: String,
        contexts: [WalletMerchantContext]
    ) -> (context: WalletMerchantContext, distance: Int)? {
        var best: (WalletMerchantContext, Int)?

        for context in contexts {
            let candidates = [context.normalizedName, MerchantLogoEngine.normalizeMerchantName(context.displayName)] + context.statementLabels.map {
                MerchantLogoEngine.normalizeMerchantName($0)
            }

            for candidate in candidates where !candidate.isEmpty {
                let distance = MerchantIntelligence.levenshteinDistance(between: normalizedFull, and: candidate)
                if distance <= 2, best == nil || distance < best!.1 {
                    best = (context, distance)
                }
            }

            for token in tokens where token.count >= 4 {
                for candidate in candidates where candidate.count >= 3 {
                    if candidate.contains(token) || token.contains(candidate) {
                        let distance = MerchantIntelligence.levenshteinDistance(between: token, and: candidate)
                        if distance <= 2, best == nil || distance < best!.1 {
                            best = (context, distance)
                        }
                    }
                }
            }
        }

        return best
    }

    private nonisolated static func matchExistingMerchant(
        canonicalName: String,
        domain: String?,
        tokens: [String],
        contexts: [WalletMerchantContext]
    ) -> WalletMerchantContext? {
        let normalized = MerchantLogoEngine.normalizeMerchantName(canonicalName)
        if let hit = matchByNormalizedLabel(normalized, contexts: contexts) { return hit }
        if let domain,
           let hit = contexts.first(where: { $0.domain?.lowercased() == domain.lowercased() }) {
            return hit
        }
        return fuzzyMatchMerchant(tokens: tokens, normalizedFull: normalized, contexts: contexts)?.context
    }

    private nonisolated static func resolution(
        for context: WalletMerchantContext,
        canonicalName: String,
        domain: String?,
        rawLabel: String,
        source: WalletMatchSource,
        confidence: WalletMatchConfidence
    ) -> WalletStatementResolution {
        WalletStatementResolution(
            canonicalName: canonicalName,
            domain: domain,
            matchedMerchantId: context.id,
            confidence: confidence,
            rawLabel: rawLabel,
            matchSource: source
        )
    }

    // MARK: - Formatting

    private nonisolated static func titleCaseDomainBrand(_ domain: String) -> String {
        let label = domain
            .split(separator: ".")
            .first
            .map(String.init)?
            .replacingOccurrences(of: "-", with: " ") ?? domain
        return titleCase(label)
    }

    private nonisolated static func titleCase(_ value: String) -> String {
        value
            .split(separator: " ")
            .map { part in
                let word = String(part)
                guard let first = word.first else { return word }
                return String(first).uppercased() + word.dropFirst()
            }
            .joined(separator: " ")
    }
}
