//
//  SubscriptionBillingChannelDetector.swift
//  BuxMuse — cancellation links: always App Store + provider website when known.
//

import Foundation

enum SubscriptionBillingChannelDetector {

    /// Opens the system Subscriptions UI on iPhone/iPad (Settings → Apple ID → Subscriptions).
    static let appStoreManageURL = URL(string: "https://apps.apple.com/account/subscriptions")!

    private static let appleBillingTokens = [
        "apple.com/bill",
        "apple.com bill",
        "app store",
        "itunes",
        "icloud",
        "apple pay",
        "apl*",
        "apple *",
    ]

    /// Hint only — never used to hide cancellation actions.
    static func detectChannel(merchantName: String, transactions: [Transaction]) -> SubscriptionBillingChannel {
        let haystack = searchableHaystack(merchantName: merchantName, transactions: transactions)
        if containsAppleBillingSignal(haystack) {
            return .apple
        }
        if trustedProviderDomain(for: merchantName) != nil {
            return .direct
        }
        return .unknown
    }

    static func providerWebsiteURL(for merchantName: String) -> URL? {
        guard let domain = trustedProviderDomain(for: merchantName) else { return nil }
        if isAppleHost(domain) { return nil }
        return URL(string: "https://\(domain)")
    }

    static func buildCancellationGuide(
        merchantName: String,
        transactions: [Transaction],
        locale: Locale
    ) -> SubscriptionCancellationGuide {
        let channel = detectChannel(merchantName: merchantName, transactions: transactions)
        let instructions = BuxLocalizedString.string(
            "If you subscribed through Apple, use Manage in App Store. Otherwise cancel on the provider's website.",
            locale: locale
        )

        return SubscriptionCancellationGuide(
            instructions: instructions,
            channel: channel,
            appStoreManageURL: appStoreManageURL,
            providerWebsiteURL: providerWebsiteURL(for: merchantName)
        )
    }

    /// Trusted domains only — skips heuristic `merchant.com` guessing.
    static func trustedProviderDomain(for merchantName: String) -> String? {
        let intelligence = WalletStatementIntelligence.resolve(
            rawLabel: merchantName,
            contexts: []
        )
        if let domain = intelligence.domain {
            switch intelligence.confidence {
            case .high, .medium:
                return sanitizeHost(domain)
            case .low:
                break
            }
        }

        if let catalogDomain = MerchantCatalog.domain(for: merchantName) {
            return sanitizeHost(catalogDomain)
        }

        let normalized = MerchantLogoEngine.normalizeMerchantName(merchantName)
        let knownMerchants: [String: String] = [
            "starbucks": "starbucks.com",
            "netflix": "netflix.com",
            "spotify": "spotify.com",
            "uber": "uber.com",
            "amazon": "amazon.co.uk",
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
            "voxi": "voxi.com",
            "chatgpt": "openai.com",
        ]
        if let direct = knownMerchants[normalized] {
            return direct
        }

        if let embedded = embeddedDomain(in: merchantName) {
            return embedded
        }

        return nil
    }

    private static func isAppleHost(_ domain: String) -> Bool {
        let host = sanitizeHost(domain)
        return host == "apple.com" || host.hasSuffix(".apple.com")
    }

    private static func searchableHaystack(merchantName: String, transactions: [Transaction]) -> String {
        var parts = [merchantName.lowercased()]
        for transaction in transactions {
            parts.append(transaction.merchantName.lowercased())
            if let notes = transaction.notes {
                parts.append(notes.lowercased())
                if let raw = WalletStatementIntelligence.rawLabelFromStoredNote(notes) {
                    parts.append(raw.lowercased())
                }
            }
        }
        return parts.joined(separator: " ")
    }

    private static func containsAppleBillingSignal(_ haystack: String) -> Bool {
        appleBillingTokens.contains { haystack.contains($0) }
    }

    private static func embeddedDomain(in merchantName: String) -> String? {
        let trimmed = merchantName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "www.", with: "")
        guard trimmed.contains(".") else { return nil }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: ".-"))
        let cleaned = String(trimmed.unicodeScalars.filter { allowed.contains($0) })
        guard cleaned.contains("."), !cleaned.hasPrefix(".") else { return nil }
        if isAppleHost(cleaned) { return nil }
        return cleaned
    }

    private static func sanitizeHost(_ domain: String) -> String {
        domain
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .replacingOccurrences(of: "www.", with: "")
    }
}
