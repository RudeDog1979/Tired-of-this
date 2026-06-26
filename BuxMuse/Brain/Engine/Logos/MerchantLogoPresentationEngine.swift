//
//  MerchantLogoPresentationEngine.swift
//  BuxMuse
//
//  Single offline builder for expense-row merchant logos (list + detail).
//

import Foundation

struct MerchantLogoPresentation: Sendable, Equatable {
    let fetchLabel: String
    let logoDomain: String?
    let showMerchantLogo: Bool
}

enum MerchantLogoPresentationEngine {
    /// Builds the row logo slot — safe from background threads.
    nonisolated static func build(
        record: ExpenseRecord,
        linkedMerchant: ExpenseMerchantRecord?
    ) -> MerchantLogoPresentation {
        let fetchLabel = resolveFetchLabel(record: record, linkedMerchant: linkedMerchant)
        let show = ExpenseLedgerAvatarPolicy.shouldUseMerchantLogo(for: record)
        let domain: String?
        if show {
            domain = resolveLogoDomain(
                record: record,
                fetchLabel: fetchLabel,
                linkedMerchant: linkedMerchant
            )
        } else {
            domain = nil
        }
        return MerchantLogoPresentation(
            fetchLabel: fetchLabel,
            logoDomain: domain,
            showMerchantLogo: show
        )
    }

    nonisolated static func resolveFetchLabel(
        record: ExpenseRecord,
        linkedMerchant: ExpenseMerchantRecord?
    ) -> String {
        let merchantField = record.merchantName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !merchantField.isEmpty { return merchantField }

        if let linked = linkedMerchant?.name.trimmingCharacters(in: .whitespacesAndNewlines),
           !linked.isEmpty {
            return linked
        }

        let wallet = WalletStatementIntelligence.walletRawLabel(for: record)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !wallet.isEmpty { return wallet }

        return record.name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated private static func resolveLogoDomain(
        record: ExpenseRecord,
        fetchLabel: String,
        linkedMerchant: ExpenseMerchantRecord?
    ) -> String? {
        guard !fetchLabel.isEmpty else { return nil }

        let stored = linkedMerchant?.logoURL.flatMap {
            MerchantLogoEngine.domain(fromStoredLogoURL: $0)
        }
        let resolved = MerchantLogoEngine.resolveDomain(
            for: fetchLabel,
            currencyCode: record.currencyCode
        )
        return MerchantDomainResolver.preferredLogoDomain(stored: stored, resolved: resolved)
    }
}
