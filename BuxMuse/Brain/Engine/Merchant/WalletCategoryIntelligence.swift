//
//  WalletCategoryIntelligence.swift
//  BuxMuse
//
//  Worldwide on-device wallet transaction categorization.
//

import Foundation

public enum WalletTransactionKind: Sendable {
    case purchase
    case atm
    case transfer
    case standingOrder
    case refund
}

extension WalletTransactionKind: Equatable {
    nonisolated public static func == (lhs: WalletTransactionKind, rhs: WalletTransactionKind) -> Bool {
        switch (lhs, rhs) {
        case (.purchase, .purchase), (.atm, .atm), (.transfer, .transfer),
             (.standingOrder, .standingOrder), (.refund, .refund):
            return true
        default:
            return false
        }
    }
}

public enum WalletCategoryConfidence: Sendable {
    case high
    case medium
    case low

    nonisolated var persistedRaw: String {
        switch self {
        case .high: return "high"
        case .medium: return "medium"
        case .low: return "low"
        }
    }

    nonisolated init?(persistedRaw: String) {
        switch persistedRaw {
        case "high": self = .high
        case "medium": self = .medium
        case "low": self = .low
        default: return nil
        }
    }
}

extension WalletCategoryConfidence: Equatable {
    nonisolated public static func == (lhs: WalletCategoryConfidence, rhs: WalletCategoryConfidence) -> Bool {
        switch (lhs, rhs) {
        case (.high, .high), (.medium, .medium), (.low, .low):
            return true
        default:
            return false
        }
    }
}

public enum WalletCategorySource: Sendable {
    case financeKitType
    case userMemory
    case paymentProcessor
    case merchantCategoryCode
    case brandLexicon
    case structuralKeyword
    case merchantCatalog
    case fallback
}

extension WalletCategorySource: Equatable {
    nonisolated public static func == (lhs: WalletCategorySource, rhs: WalletCategorySource) -> Bool {
        switch (lhs, rhs) {
        case (.financeKitType, .financeKitType), (.userMemory, .userMemory),
             (.paymentProcessor, .paymentProcessor), (.merchantCategoryCode, .merchantCategoryCode),
             (.brandLexicon, .brandLexicon), (.structuralKeyword, .structuralKeyword),
             (.merchantCatalog, .merchantCatalog), (.fallback, .fallback):
            return true
        default:
            return false
        }
    }
}

public struct WalletCategoryDecision: Sendable {
    public let category: TransactionCategory
    public let confidence: WalletCategoryConfidence
    public let source: WalletCategorySource

    public nonisolated init(category: TransactionCategory, confidence: WalletCategoryConfidence, source: WalletCategorySource) {
        self.category = category
        self.confidence = confidence
        self.source = source
    }
}

extension WalletCategoryDecision: Equatable {
    nonisolated public static func == (lhs: WalletCategoryDecision, rhs: WalletCategoryDecision) -> Bool {
        lhs.category == rhs.category
            && lhs.confidence == rhs.confidence
            && lhs.source == rhs.source
    }
}

public struct WalletCategoryInput: Sendable {
    public let rawLabel: String
    public let displayName: String
    public let isCredit: Bool
    public let transactionKind: WalletTransactionKind
    public let mccCode: Int?
    /// Set when the user manually confirmed a category for this merchant (Step 2 memory table).
    public let userMemoryCategory: TransactionCategory?

    public nonisolated init(
        rawLabel: String,
        displayName: String,
        isCredit: Bool,
        transactionKind: WalletTransactionKind,
        mccCode: Int?,
        userMemoryCategory: TransactionCategory? = nil
    ) {
        self.rawLabel = rawLabel
        self.displayName = displayName
        self.isCredit = isCredit
        self.transactionKind = transactionKind
        self.mccCode = mccCode
        self.userMemoryCategory = userMemoryCategory
    }
}

extension WalletCategoryInput: Equatable {
    nonisolated public static func == (lhs: WalletCategoryInput, rhs: WalletCategoryInput) -> Bool {
        lhs.rawLabel == rhs.rawLabel
            && lhs.displayName == rhs.displayName
            && lhs.isCredit == rhs.isCredit
            && lhs.transactionKind == rhs.transactionKind
            && lhs.mccCode == rhs.mccCode
            && lhs.userMemoryCategory == rhs.userMemoryCategory
    }
}

public enum WalletCategoryIntelligence {
    public nonisolated static func classify(_ input: WalletCategoryInput) -> WalletCategoryDecision {
        let haystack = searchableHaystack(rawLabel: input.rawLabel, displayName: input.displayName)
        let normalized = MerchantLogoEngine.normalizeMerchantName(haystack)

        // 1 — FinanceKit type & credit/debit
        if let typeDecision = classifyByFinanceKitType(input: input, haystack: haystack) {
            return typeDecision
        }

        // 2 — User-confirmed merchant memory
        if let memory = input.userMemoryCategory {
            return WalletCategoryDecision(category: memory, confidence: .high, source: .userMemory)
        }

        // 3 — Payment processor payee parse
        if let processorDecision = classifyPaymentProcessor(
            rawLabel: input.rawLabel,
            displayName: input.displayName,
            haystack: haystack
        ) {
            return processorDecision
        }

        // 3b — Banks & fintech (before MCC — institutions often report bogus merchant codes)
        if let financialDecision = classifyFinancialInstitution(input: input, haystack: haystack) {
            return financialDecision
        }

        // 4 — ISO MCC
        if let code = input.mccCode, let mccCategory = WalletCategoryLexicon.category(forMCC: code) {
            return WalletCategoryDecision(category: mccCategory, confidence: .high, source: .merchantCategoryCode)
        }

        // 4b — Subscription billing descriptors (before partial catalog brand hits like `apple`)
        if let billingDecision = classifySubscriptionBilling(haystack: haystack) {
            return billingDecision
        }

        // 5 — Merchant catalog + worldwide brand lexicon
        if let catalogDecision = classifyFromCatalogAndBrands(haystack: haystack, normalized: normalized) {
            return catalogDecision
        }

        // 6 — Structural multilingual keywords
        if let keywordDecision = classifyStructuralKeywords(haystack: haystack) {
            return keywordDecision
        }

        // 7 — Fuzzy merchant catalog search
        if let fuzzy = classifyFuzzyCatalog(rawLabel: input.rawLabel, displayName: input.displayName) {
            return fuzzy
        }

        return WalletCategoryDecision(category: .other, confidence: .low, source: .fallback)
    }

    // MARK: - Tier 1

    private nonisolated static func classifyByFinanceKitType(
        input: WalletCategoryInput,
        haystack: String
    ) -> WalletCategoryDecision? {
        if input.isCredit {
            let category: TransactionCategory = input.transactionKind == .refund ? .other : .income
            return WalletCategoryDecision(category: category, confidence: .high, source: .financeKitType)
        }

        switch input.transactionKind {
        case .atm:
            return WalletCategoryDecision(category: .personal, confidence: .high, source: .financeKitType)
        case .refund:
            return WalletCategoryDecision(category: .other, confidence: .high, source: .financeKitType)
        case .transfer, .standingOrder:
            if WalletCategoryLexicon.matchesAny(haystack, WalletCategoryLexicon.housing) {
                return WalletCategoryDecision(category: .housing, confidence: .high, source: .financeKitType)
            }
            if WalletCategoryLexicon.matchesAny(haystack, WalletCategoryLexicon.utilities) {
                return WalletCategoryDecision(category: .utilities, confidence: .high, source: .financeKitType)
            }
            if WalletCategoryLexicon.matchesAny(haystack, WalletCategoryLexicon.subscriptions) {
                return WalletCategoryDecision(category: .subscriptions, confidence: .medium, source: .financeKitType)
            }
            return WalletCategoryDecision(category: .personal, confidence: .high, source: .financeKitType)
        case .purchase:
            return nil
        }
    }

    // MARK: - Tier 3 — Processors

    private nonisolated static func classifyPaymentProcessor(
        rawLabel: String,
        displayName: String,
        haystack: String
    ) -> WalletCategoryDecision? {
        var seenLabels: Set<String> = []
        for label in [rawLabel, displayName] where !label.isEmpty {
            let folded = foldedLabel(label)
            guard seenLabels.insert(folded).inserted else { continue }
            if let payee = extractProcessorPayee(from: folded),
               let decision = classifyProcessorPayee(payee) {
                return decision
            }
        }

        if WalletCategoryLexicon.matchesAny(haystack, WalletCategoryLexicon.p2pAndMoneyMovement) {
            return WalletCategoryDecision(category: .personal, confidence: .medium, source: .paymentProcessor)
        }

        if WalletCategoryLexicon.isFinancialInstitution(haystack) {
            return financialInstitutionDecision(haystack: haystack)
        }

        return nil
    }

    private nonisolated static func classifyFinancialInstitution(
        input: WalletCategoryInput,
        haystack: String
    ) -> WalletCategoryDecision? {
        guard !input.isCredit else { return nil }
        guard WalletCategoryLexicon.isFinancialInstitution(haystack) else { return nil }
        return financialInstitutionDecision(haystack: haystack)
    }

    private nonisolated static func financialInstitutionDecision(haystack: String) -> WalletCategoryDecision {
        if WalletCategoryLexicon.matchesAny(haystack, WalletCategoryLexicon.housing) {
            return WalletCategoryDecision(category: .housing, confidence: .high, source: .paymentProcessor)
        }
        if WalletCategoryLexicon.matchesAny(haystack, WalletCategoryLexicon.utilities) {
            return WalletCategoryDecision(category: .utilities, confidence: .high, source: .paymentProcessor)
        }
        return WalletCategoryDecision(category: .personal, confidence: .high, source: .paymentProcessor)
    }

    private nonisolated static func classifyProcessorPayee(_ payee: String) -> WalletCategoryDecision? {
        let payeeHaystack = payee.lowercased()
        let payeeNorm = MerchantLogoEngine.normalizeMerchantName(payee)
        if let category = WalletCategoryLexicon.category(forBrandToken: payeeNorm, haystack: payeeHaystack) {
            return WalletCategoryDecision(category: category, confidence: .high, source: .paymentProcessor)
        }
        if let keyword = classifyStructuralKeywords(haystack: payeeHaystack) {
            return WalletCategoryDecision(
                category: keyword.category,
                confidence: .medium,
                source: .paymentProcessor
            )
        }
        return nil
    }

    private nonisolated static func foldedLabel(_ label: String) -> String {
        label
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private nonisolated static func extractProcessorPayee(from haystack: String) -> String? {
        let patterns = [
            #"paypal\s*\*\s*(.+?)$"#,
            #"paypal\s+(.+?)$"#,
            #"sq\s*\*\s*(.+?)$"#,
            #"square\s*\*\s*(.+?)$"#,
            #"sp\s*\*\s*(.+?)$"#,
            #"stripe\s*\*\s*(.+?)$"#,
            #"klarna\s*\*\s*(.+?)$"#,
            #"pp\s*\*\s*(.+?)$"#,
            #"amzn\s*mktp\s*\*\s*(.+?)$"#,
            #"amazon\s*mktp\s*\*\s*(.+?)$"#
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
               let match = regex.firstMatch(in: haystack, range: NSRange(haystack.startIndex..., in: haystack)),
               match.numberOfRanges > 1,
               let range = Range(match.range(at: 1), in: haystack) {
                let payee = String(haystack[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                if payee.count >= 2 { return payee }
            }
        }
        return nil
    }

    // MARK: - Tier 4b — Subscription billing

    private nonisolated static func classifySubscriptionBilling(haystack: String) -> WalletCategoryDecision? {
        let billingTokens = [
            "apple.com/bill", "icloud", "google one", "google storage",
            "youtube premium", "amazon prime", "microsoft 365", "office 365"
        ]
        guard WalletCategoryLexicon.matchesAny(haystack, billingTokens) else { return nil }
        return WalletCategoryDecision(category: .subscriptions, confidence: .high, source: .brandLexicon)
    }

    // MARK: - Tier 5 — Catalog & brands

    private nonisolated static func classifyFromCatalogAndBrands(
        haystack: String,
        normalized: String
    ) -> WalletCategoryDecision? {
        guard !WalletCategoryLexicon.isFinancialInstitution(haystack) else { return nil }
        if let category = WalletCategoryLexicon.category(forBrandToken: normalized, haystack: haystack) {
            let source: WalletCategorySource = WalletCategoryLexicon.catalogBrandCategories[normalized] != nil
                ? .merchantCatalog
                : .brandLexicon
            return WalletCategoryDecision(category: category, confidence: .high, source: source)
        }
        return nil
    }

    private nonisolated static func classifyFuzzyCatalog(
        rawLabel: String,
        displayName: String
    ) -> WalletCategoryDecision? {
        let haystack = searchableHaystack(rawLabel: rawLabel, displayName: displayName)
        guard !WalletCategoryLexicon.isFinancialInstitution(haystack) else { return nil }
        let query = rawLabel.count >= displayName.count ? rawLabel : displayName
        guard query.count >= 3 else { return nil }
        let matches = MerchantCatalog.matchingEntries(for: query, limit: 1)
        guard let entry = matches.first else { return nil }
        let key = MerchantLogoEngine.normalizeMerchantName(entry.displayName)
        if let category = WalletCategoryLexicon.catalogBrandCategories[key] {
            return WalletCategoryDecision(category: category, confidence: .medium, source: .merchantCatalog)
        }
        let blob = (entry.displayName + " " + entry.searchNames.joined(separator: " ")).lowercased()
        if let category = WalletCategoryLexicon.category(forBrandToken: key, haystack: blob) {
            return WalletCategoryDecision(category: category, confidence: .medium, source: .merchantCatalog)
        }
        return nil
    }

    // MARK: - Tier 6 — Keywords

    private nonisolated static func classifyStructuralKeywords(haystack: String) -> WalletCategoryDecision? {
        guard !WalletCategoryLexicon.isFinancialInstitution(haystack) else { return nil }
        let checks: [(TransactionCategory, [String])] = [
            (.groceries, WalletCategoryLexicon.groceries),
            (.restaurants, WalletCategoryLexicon.restaurants),
            (.transport, WalletCategoryLexicon.transport),
            (.subscriptions, WalletCategoryLexicon.subscriptions),
            (.housing, WalletCategoryLexicon.housing),
            (.utilities, WalletCategoryLexicon.utilities),
            (.entertainment, WalletCategoryLexicon.entertainment),
            (.shopping, WalletCategoryLexicon.shopping),
            (.health, WalletCategoryLexicon.health),
            (.travel, WalletCategoryLexicon.travel),
            (.education, WalletCategoryLexicon.education),
            (.personal, WalletCategoryLexicon.personal)
        ]
        var best: (category: TransactionCategory, tokenLength: Int)?
        for (category, tokens) in checks {
            for token in tokens where WalletCategoryLexicon.containsLexiconToken(haystack, token) {
                if best == nil || token.count > best!.tokenLength {
                    best = (category, token.count)
                }
            }
        }
        guard let best else { return nil }
        return WalletCategoryDecision(category: best.category, confidence: .medium, source: .structuralKeyword)
    }

    // MARK: - Helpers

    private nonisolated static func searchableHaystack(rawLabel: String, displayName: String) -> String {
        let combined = "\(rawLabel) \(displayName)"
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
        return combined.replacingOccurrences(of: "  ", with: " ")
    }

    /// Classify from a persisted wallet row when FinanceKit transaction data is unavailable.
    public nonisolated static func input(
        rawLabel: String,
        displayName: String,
        amountValue: Decimal,
        userMemoryCategory: TransactionCategory? = nil
    ) -> WalletCategoryInput {
        let haystack = rawLabel.lowercased()
        let transactionKind: WalletTransactionKind = {
            if haystack.contains("atm") || haystack.contains("cash withdrawal") || haystack.contains("cashpoint") {
                return .atm
            }
            if haystack.contains("standing order") || haystack.contains("direct debit") {
                return .standingOrder
            }
            if haystack.contains("transfer") || haystack.contains("sepa") || haystack.contains("ach")
                || haystack.contains("wire") || haystack.contains("fps") {
                return .transfer
            }
            if haystack.contains("refund") || haystack.contains("reversal") {
                return .refund
            }
            return .purchase
        }()
        return WalletCategoryInput(
            rawLabel: rawLabel,
            displayName: displayName,
            isCredit: amountValue > 0,
            transactionKind: transactionKind,
            mccCode: nil,
            userMemoryCategory: userMemoryCategory
        )
    }
}

#if canImport(FinanceKit)
import FinanceKit

public extension WalletCategoryIntelligence {
  nonisolated static func transactionKind(from type: FinanceKit.TransactionType) -> WalletTransactionKind {
        switch type {
        case .atm:
            return .atm
        case .transfer:
            return .transfer
        case .standingOrder:
            return .standingOrder
        case .refund:
            return .refund
        default:
            return .purchase
        }
    }

    nonisolated static func input(
        from tx: FinanceKit.Transaction,
        rawLabel: String,
        displayName: String,
        userMemoryCategory: TransactionCategory? = nil
    ) -> WalletCategoryInput {
        WalletCategoryInput(
            rawLabel: rawLabel,
            displayName: displayName,
            isCredit: tx.creditDebitIndicator == .credit,
            transactionKind: transactionKind(from: tx.transactionType),
            mccCode: tx.merchantCategoryCode.map { Int($0.rawValue) },
            userMemoryCategory: userMemoryCategory
        )
    }
}
#endif
