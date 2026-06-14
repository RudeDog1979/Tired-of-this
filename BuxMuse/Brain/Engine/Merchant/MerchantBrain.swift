//
//  MerchantBrain.swift
//  BuxMuse
//
//  Merchant suggestions, disambiguation, and canonical save — uses existing normalizers only.
//

import Foundation

// MARK: - Types

enum MerchantCandidateKind: Equatable, Sendable {
    case existingEntity
    case historyGroup
    /// Well-known retailer from offline catalog (Argos, Biedronka, Currys, …).
    case knownRetailer
    /// Well-known alternate spelling (e.g. M&S ↔ Marks & Spencer) — not necessarily in history yet.
    case aliasVariant
    case newMerchant
}

enum MerchantMatchConfidence: Equatable, Sendable {
    case high
    case medium
    case low
}

struct MerchantCandidate: Identifiable, Equatable, Sendable {
    let id: String
    let merchantId: UUID?
    let displayName: String
    let subtitle: String
    let matchKind: MerchantCandidateKind
    let confidence: MerchantMatchConfidence
    /// Exact statement label when picking a history group (may differ from displayName).
    let historyLabel: String?

    init(
        id: String,
        merchantId: UUID?,
        displayName: String,
        subtitle: String,
        matchKind: MerchantCandidateKind,
        confidence: MerchantMatchConfidence,
        historyLabel: String? = nil
    ) {
        self.id = id
        self.merchantId = merchantId
        self.displayName = displayName
        self.subtitle = subtitle
        self.matchKind = matchKind
        self.confidence = confidence
        self.historyLabel = historyLabel
    }
}

struct MerchantSelection: Equatable, Sendable {
    var merchantId: UUID?
    var displayName: String
    var disambiguator: String?
    var createNew: Bool
    var historyLabel: String?

    init(
        merchantId: UUID? = nil,
        displayName: String,
        disambiguator: String? = nil,
        createNew: Bool = false,
        historyLabel: String? = nil
    ) {
        self.merchantId = merchantId
        self.displayName = displayName
        self.disambiguator = disambiguator
        self.createNew = createNew
        self.historyLabel = historyLabel
    }
}

struct MerchantListDisplayInfo: Equatable, Sendable {
    var expenseCount: Int
    var variantCount: Int
    var canonicalLabel: String?
    var disambiguatorLabel: String?
}

struct MerchantCategorySuggestion: Equatable, Sendable {
    let category: TransactionCategory
    let sampleCount: Int
    let totalCount: Int
}

@MainActor
final class MerchantBrain {
    private let persistence: PersistenceController
    private let financialEngine: FinancialIntelligenceEngine

    init(persistence: PersistenceController, financialEngine: FinancialIntelligenceEngine) {
        self.persistence = persistence
        self.financialEngine = financialEngine
    }

    // MARK: - Normalize (delegates)

    func normalized(_ name: String) -> String {
        MerchantLogoEngine.normalizeMerchantName(name)
    }

    func canonicalDisplayName(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }
        return trimmed
    }

    // MARK: - Suggestions

    func candidates(
        for query: String,
        expenseRecords: [ExpenseRecord],
        locale: Locale = .current
    ) -> [MerchantCandidate] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 1 else { return [] }

        let normalizedQuery = normalized(trimmed)
        var results: [MerchantCandidate] = []
        var usedEntityIds = Set<UUID>()
        var usedLabelKeys = Set<String>()

        let merchants = (try? persistence.fetchAllMerchantRecords()) ?? []

        for merchant in merchants {
            let norm = merchant.normalizedName
            let title = merchant.displayTitle
            let matchName = merchant.name
            guard matchesQuery(
                normalizedQuery: normalizedQuery,
                rawQuery: trimmed,
                normalizedName: norm,
                displayName: matchName
            ) else {
                continue
            }
            let stats = statsForMerchant(id: merchant.id, displayNames: [merchant.name], records: expenseRecords)
            let subtitle = listSubtitle(
                expenseCount: stats.count,
                category: stats.topCategory,
                lastDate: stats.lastDate,
                locale: locale
            )
            let confidence: MerchantMatchConfidence = norm.hasPrefix(normalizedQuery)
                || matchName.lowercased().hasPrefix(trimmed.lowercased())
                ? .high : .medium
            appendCandidate(
                MerchantCandidate(
                    id: "entity:\(merchant.id.uuidString)",
                    merchantId: merchant.id,
                    displayName: title,
                    subtitle: subtitle,
                    matchKind: .existingEntity,
                    confidence: confidence,
                    historyLabel: matchName
                ),
                to: &results,
                usedLabelKeys: &usedLabelKeys
            )
            usedEntityIds.insert(merchant.id)
        }

        let historyGroups = Self.groupHistoryRecords(expenseRecords)
        let transactionNames = financialEngine.allTransactions().map(\.merchantName)
        let knownLabels = Self.collectKnownLabels(
            merchants: merchants,
            expenseRecords: expenseRecords,
            transactionNames: transactionNames
        )

        for (exactName, records) in historyGroups.sorted(by: { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }) {
            let norm = normalized(exactName)
            guard matchesQuery(normalizedQuery: normalizedQuery, rawQuery: trimmed, normalizedName: norm, displayName: exactName) else {
                continue
            }
            let key = "hist:\(exactName)"
            guard !usedLabelKeys.contains(labelKey(exactName)) else { continue }

            if let linkedId = records.compactMap(\.merchantId).first,
               let linked = merchants.first(where: { $0.id == linkedId }),
               historyLabelDuplicatesEntity(exactName: exactName, merchant: linked) {
                continue
            }

            let stats = statsForRecords(records)
            let subtitle = listSubtitle(
                expenseCount: stats.count,
                category: stats.topCategory,
                lastDate: stats.lastDate,
                locale: locale
            )
            appendCandidate(
                MerchantCandidate(
                    id: key,
                    merchantId: records.compactMap(\.merchantId).first,
                    displayName: exactName,
                    subtitle: subtitle,
                    matchKind: .historyGroup,
                    confidence: .medium,
                    historyLabel: exactName
                ),
                to: &results,
                usedLabelKeys: &usedLabelKeys
            )
        }

        for label in knownLabels.sorted(by: { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }) {
            let norm = normalized(label)
            guard matchesQuery(normalizedQuery: normalizedQuery, rawQuery: trimmed, normalizedName: norm, displayName: label) else {
                continue
            }
            let key = labelKey(label)
            guard !usedLabelKeys.contains(key) else { continue }

            let related = expenseRecords.filter {
                $0.merchantName.caseInsensitiveCompare(label) == .orderedSame
                    || $0.name.caseInsensitiveCompare(label) == .orderedSame
            }
            let stats = statsForRecords(related)
            let subtitle = stats.count > 0
                ? listSubtitle(
                    expenseCount: stats.count,
                    category: stats.topCategory,
                    lastDate: stats.lastDate,
                    locale: locale
                )
                : BuxLocalizedString.string("Past label in your data", locale: locale)
            appendCandidate(
                MerchantCandidate(
                    id: "label:\(key)",
                    merchantId: related.compactMap(\.merchantId).first,
                    displayName: label,
                    subtitle: subtitle,
                    matchKind: .historyGroup,
                    confidence: .medium,
                    historyLabel: label
                ),
                to: &results,
                usedLabelKeys: &usedLabelKeys
            )
        }

        for entry in MerchantCatalog.matchingEntries(for: trimmed, limit: 12) {
            let key = labelKey(entry.displayName)
            guard !usedLabelKeys.contains(key) else { continue }
            appendCandidate(
                MerchantCandidate(
                    id: "catalog:\(key)",
                    merchantId: nil,
                    displayName: entry.displayName,
                    subtitle: BuxLocalizedString.format(
                        "Known retailer · %@",
                        locale: locale,
                        entry.domain
                    ),
                    matchKind: .knownRetailer,
                    confidence: .high,
                    historyLabel: entry.displayName
                ),
                to: &results,
                usedLabelKeys: &usedLabelKeys
            )
        }

        for aliasLabel in aliasLabels(matchingQuery: trimmed, normalizedQuery: normalizedQuery) {
            let key = labelKey(aliasLabel)
            guard !usedLabelKeys.contains(key) else { continue }
            appendCandidate(
                MerchantCandidate(
                    id: "alias:\(key)",
                    merchantId: nil,
                    displayName: aliasLabel,
                    subtitle: BuxLocalizedString.string("Common name — tap to use", locale: locale),
                    matchKind: .aliasVariant,
                    confidence: .medium,
                    historyLabel: aliasLabel
                ),
                to: &results,
                usedLabelKeys: &usedLabelKeys
            )
        }

        results.sort { lhs, rhs in
            let order: [MerchantCandidateKind] = [.existingEntity, .historyGroup, .knownRetailer, .aliasVariant, .newMerchant]
            let li = order.firstIndex(of: lhs.matchKind) ?? 99
            let ri = order.firstIndex(of: rhs.matchKind) ?? 99
            if li != ri { return li < ri }
            if lhs.confidence != rhs.confidence {
                return confidenceRank(lhs.confidence) < confidenceRank(rhs.confidence)
            }
            return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }

        if !trimmed.isEmpty {
            results.append(MerchantCandidate(
                id: "new:\(normalizedQuery)",
                merchantId: nil,
                displayName: trimmed,
                subtitle: BuxLocalizedString.string("Add as new merchant", locale: locale),
                matchKind: .newMerchant,
                confidence: .low
            ))
        }

        return results
    }

    func mergeHintCandidate(from candidates: [MerchantCandidate]) -> MerchantCandidate? {
        let choosable = candidates.filter {
            $0.matchKind != .newMerchant && $0.matchKind != .aliasVariant
        }
        guard choosable.count == 1, choosable[0].confidence == .high else { return nil }
        return choosable[0]
    }

    func isAmbiguous(
        query: String,
        candidates: [MerchantCandidate],
        selectedCandidateId: String?,
        selectedMerchantId: UUID?
    ) -> Bool {
        if selectedCandidateId != nil || selectedMerchantId != nil { return false }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let choosable = candidates.filter { $0.matchKind != .newMerchant }
        return choosable.count > 1
    }

    /// True when the user typed a short form (e.g. M&S) that maps to several well-known names.
    func shouldOfferExplicitPick(for query: String, candidates: [MerchantCandidate]) -> Bool {
        let choosable = candidates.filter { $0.matchKind != .newMerchant }
        if choosable.count > 1 { return true }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let norm = normalized(trimmed)
        let aliases = aliasLabels(matchingQuery: trimmed, normalizedQuery: norm)
        guard aliases.count > 1 else { return false }
        let compact = compactNormalized(norm)
        guard compact.count <= 4 else { return false }
        return aliases.contains { label in
            matchesQuery(normalizedQuery: norm, rawQuery: trimmed, normalizedName: normalized(label), displayName: label)
        }
    }

    func selection(
        from candidate: MerchantCandidate,
        disambiguator: String? = nil
    ) -> MerchantSelection {
        MerchantSelection(
            merchantId: candidate.merchantId,
            displayName: candidate.historyLabel ?? candidate.displayName,
            disambiguator: disambiguator,
            createNew: candidate.matchKind == .newMerchant,
            historyLabel: candidate.historyLabel
        )
    }

    func listDisplayInfo(
        for merchant: ExpenseMerchantRecord,
        expenseRecords: [ExpenseRecord]
    ) -> MerchantListDisplayInfo {
        let related = expenseRecords.filter { $0.merchantId == merchant.id }
        let names = Set(related.map(\.merchantName))
        let variantCount = max(1, names.count)
        let cluster = merchant.cluster.flatMap { $0.isEmpty ? nil : $0 }
            ?? MerchantIntelligence.normalize(merchant.name)
        return MerchantListDisplayInfo(
            expenseCount: related.count,
            variantCount: variantCount,
            canonicalLabel: cluster,
            disambiguatorLabel: merchant.disambiguatorDisplay
        )
    }

    func suggestedCategory(
        for label: String,
        merchantId: UUID?,
        expenseRecords: [ExpenseRecord],
        excludeRecordId: UUID? = nil
    ) -> MerchantCategorySuggestion? {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let merchants = (try? persistence.fetchAllMerchantRecords()) ?? []
        let isSubscriptionMerchant = merchantIsSubscriptionFlagged(
            merchantId: merchantId,
            label: trimmed,
            merchants: merchants
        )
        let related = matchingExpenseRecords(
            for: trimmed,
            merchantId: merchantId,
            in: expenseRecords,
            excludeRecordId: excludeRecordId
        )
        let eligible = related.filter { record in
            let category = record.transactionCategory
            if category == .income { return false }
            if category == .subscriptions, !isSubscriptionMerchant { return false }
            return true
        }
        guard eligible.count >= 2 else { return nil }

        let grouped = Dictionary(grouping: eligible, by: \.transactionCategory)
        guard let top = grouped.max(by: { $0.value.count < $1.value.count }) else { return nil }
        let share = Double(top.value.count) / Double(eligible.count)
        guard share >= 0.6 else { return nil }

        return MerchantCategorySuggestion(
            category: top.key,
            sampleCount: top.value.count,
            totalCount: eligible.count
        )
    }

    func needsDisambiguatorLabel(
        for displayName: String,
        disambiguator: String?
    ) -> Bool {
        let norm = normalized(displayName)
        let trimmedDisambiguator = disambiguator?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard trimmedDisambiguator.isEmpty else { return false }
        let merchants = (try? persistence.fetchAllMerchantRecords()) ?? []
        return merchants.contains { $0.normalizedName == norm }
    }

    // MARK: - Private

    private struct RecordStats {
        var count: Int
        var topCategory: TransactionCategory?
        var lastDate: Date?
    }

    /// Legacy alias groups — catalog covers these; kept as empty fallback hook.
    private static let retailAliasGroups: [[String]] = []

    private static func collectKnownLabels(
        merchants: [ExpenseMerchantRecord],
        expenseRecords: [ExpenseRecord],
        transactionNames: [String]
    ) -> Set<String> {
        var labels = Set<String>()
        for merchant in merchants {
            let name = merchant.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty { labels.insert(name) }
        }
        for record in expenseRecords {
            let merchantName = record.merchantName.trimmingCharacters(in: .whitespacesAndNewlines)
            let title = record.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if !merchantName.isEmpty { labels.insert(merchantName) }
            if !title.isEmpty { labels.insert(title) }
        }
        for name in transactionNames {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { labels.insert(trimmed) }
        }
        return labels
    }

    private func labelKey(_ label: String) -> String {
        normalized(label)
    }

    private func appendCandidate(
        _ candidate: MerchantCandidate,
        to results: inout [MerchantCandidate],
        usedLabelKeys: inout Set<String>
    ) {
        let key = labelKey(candidate.historyLabel ?? candidate.displayName)
        guard !usedLabelKeys.contains(key) else { return }
        usedLabelKeys.insert(key)
        results.append(candidate)
    }

    private func aliasLabels(matchingQuery rawQuery: String, normalizedQuery: String) -> [String] {
        let catalogAlternates = MerchantCatalog.alternateLabels(for: rawQuery)
        if !catalogAlternates.isEmpty {
            return catalogAlternates
        }
        for group in Self.retailAliasGroups {
            let groupMatches = group.contains { label in
                matchesQuery(
                    normalizedQuery: normalizedQuery,
                    rawQuery: rawQuery,
                    normalizedName: normalized(label),
                    displayName: label
                )
            }
            if groupMatches {
                return group
            }
        }
        return []
    }

    private static func groupHistoryRecords(_ records: [ExpenseRecord]) -> [String: [ExpenseRecord]] {
        var groups: [String: [ExpenseRecord]] = [:]
        for record in records {
            let key = record.merchantName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty else { continue }
            groups[key, default: []].append(record)
        }
        return groups
    }

    private func statsForMerchant(id: UUID, displayNames: [String], records: [ExpenseRecord]) -> RecordStats {
        let related = records.filter { $0.merchantId == id }
        if !related.isEmpty { return statsForRecords(related) }
        let names = Set(displayNames.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) })
        let fallback = records.filter { names.contains($0.merchantName) }
        return statsForRecords(fallback)
    }

    private func matchingExpenseRecords(
        for label: String,
        merchantId: UUID?,
        in expenseRecords: [ExpenseRecord],
        excludeRecordId: UUID?
    ) -> [ExpenseRecord] {
        let normalizedLabel = normalized(label)
        return expenseRecords.filter { record in
            if let excludeRecordId, record.id == excludeRecordId { return false }
            if let merchantId, record.merchantId == merchantId { return true }
            let merchantName = record.merchantName.trimmingCharacters(in: .whitespacesAndNewlines)
            let title = record.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if normalized(merchantName) == normalizedLabel { return true }
            if normalized(title) == normalizedLabel { return true }
            return false
        }
    }

    private func merchantIsSubscriptionFlagged(
        merchantId: UUID?,
        label: String,
        merchants: [ExpenseMerchantRecord]
    ) -> Bool {
        if let merchantId, let merchant = merchants.first(where: { $0.id == merchantId }) {
            return merchant.isSubscriptionMerchant
        }
        let normalizedLabel = normalized(label)
        return merchants.contains {
            $0.isSubscriptionMerchant && $0.normalizedName == normalizedLabel
        }
    }

    private func statsForRecords(_ records: [ExpenseRecord]) -> RecordStats {
        guard !records.isEmpty else { return RecordStats(count: 0, topCategory: nil, lastDate: nil) }
        let categories = records.map(\.transactionCategory)
        let top = Dictionary(grouping: categories, by: { $0 }).max(by: { $0.value.count < $1.value.count })?.key
        let last = records.map(\.date).max()
        return RecordStats(count: records.count, topCategory: top, lastDate: last)
    }

    private func listSubtitle(
        expenseCount: Int,
        category: TransactionCategory?,
        lastDate: Date?,
        locale: Locale
    ) -> String {
        var parts: [String] = []
        if expenseCount > 0 {
            let countKey = expenseCount == 1 ? "%lld expense" : "%lld expenses"
            parts.append(BuxLocalizedString.format(countKey, locale: locale, expenseCount))
        }
        if let category {
            parts.append(category.localizedDisplayName(locale: locale))
        }
        if let lastDate {
            let formatter = DateFormatter()
            formatter.locale = locale
            formatter.dateStyle = .medium
            parts.append(
                BuxLocalizedString.format(
                    "last %@",
                    locale: locale,
                    formatter.string(from: lastDate)
                )
            )
        }
        return parts.isEmpty
            ? BuxLocalizedString.string("No expenses yet", locale: locale)
            : parts.joined(separator: " · ")
    }

    private func historyLabelDuplicatesEntity(exactName: String, merchant: ExpenseMerchantRecord) -> Bool {
        let label = exactName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !label.isEmpty else { return false }
        if merchant.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == label { return true }
        if merchant.displayTitle.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == label { return true }
        return false
    }

    private func matchesQuery(
        normalizedQuery: String,
        rawQuery: String,
        normalizedName: String,
        displayName: String
    ) -> Bool {
        let compactQuery = compactNormalized(normalizedQuery)
        let compactName = compactNormalized(normalizedName)

        if displayName.localizedCaseInsensitiveContains(rawQuery) { return true }

        if !compactQuery.isEmpty {
            if compactName.contains(compactQuery) { return true }
            if compactName.hasPrefix(compactQuery) { return true }
            if merchantAcronym(from: normalizedName) == compactQuery { return true }
            if merchantAcronym(from: displayName) == compactQuery { return true }
        }

        if normalizedQuery.count >= 2, normalizedName.contains(normalizedQuery) { return true }
        if normalizedName.hasPrefix(normalizedQuery) { return true }

        if normalizedQuery.count >= 3 {
            let distance = MerchantIntelligence.levenshteinDistance(between: normalizedQuery, and: normalizedName)
            if distance <= 2 { return true }
        }

        return false
    }

    private func compactNormalized(_ value: String) -> String {
        normalized(value).replacingOccurrences(of: " ", with: "")
    }

    private static let acronymStopWords: Set<String> = [
        "and", "the", "of", "for", "at", "in", "on", "a", "an", "to", "by", "or", "uk", "gb", "ltd", "plc"
    ]

    private func merchantAcronym(from name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        let words = trimmed
            .split { $0.isWhitespace || !$0.isLetter }
            .map { String($0).lowercased() }
            .filter { !$0.isEmpty && !Self.acronymStopWords.contains($0) }
        if words.count >= 2 {
            return String(words.compactMap(\.first))
        }

        let letters = trimmed.filter(\.isLetter)
        if letters.count >= 2, letters.count <= 4, !trimmed.contains(where: \.isWhitespace) {
            return String(letters).lowercased()
        }
        return ""
    }

    private func confidenceRank(_ confidence: MerchantMatchConfidence) -> Int {
        switch confidence {
        case .high: return 0
        case .medium: return 1
        case .low: return 2
        }
    }
}

// MARK: - Merchant record display

extension ExpenseMerchantRecord {
    var disambiguatorDisplay: String? {
        let trimmed = disambiguator.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var displayTitle: String {
        if let label = disambiguatorDisplay {
            return "\(name) · \(label)"
        }
        return name
    }
}
