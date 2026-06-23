//
//  WalletTransactionClassifier.swift
//  BuxMuse
//
//  Shared wallet transaction classification + update refresh rules.
//

import Foundation

struct WalletTransactionClassification: Sendable {
    let rawLabel: String
    let displayName: String
    let resolution: WalletStatementResolution
    let decision: WalletCategoryDecision
    let userMemoryCategory: TransactionCategory?

    nonisolated var category: TransactionCategory {
        userMemoryCategory ?? decision.category
    }

    nonisolated var categoryRaw: String {
        category.rawValue
    }
}

/// Primitive snapshot for nonisolated wallet refresh checks (ExpenseRecord is MainActor-isolated).
struct WalletCategoryRefreshSnapshot: Sendable {
    let categoryRaw: String
    let walletCategoryUserConfirmed: Bool
    let walletCategoryConfidence: String?
    let notes: String?

    init(record: ExpenseRecord) {
        categoryRaw = record.categoryRaw
        walletCategoryUserConfirmed = record.walletCategoryUserConfirmed
        walletCategoryConfidence = record.walletCategoryConfidence
        notes = record.notes
    }

    init(
        categoryRaw: String,
        walletCategoryUserConfirmed: Bool,
        walletCategoryConfidence: String?,
        notes: String?
    ) {
        self.categoryRaw = categoryRaw
        self.walletCategoryUserConfirmed = walletCategoryUserConfirmed
        self.walletCategoryConfidence = walletCategoryConfidence
        self.notes = notes
    }
}

enum WalletTransactionClassifier {
    nonisolated static func shouldRefreshCategory(
        existing: WalletCategoryRefreshSnapshot,
        classification: WalletTransactionClassification
    ) -> Bool {
        if existing.walletCategoryUserConfirmed { return false }
        if classification.userMemoryCategory != nil { return true }
        if existing.categoryRaw != classification.categoryRaw {
            return true
        }
        if existing.categoryRaw == TransactionCategory.other.rawValue { return true }
        if let stored = existing.walletCategoryConfidence.flatMap({ WalletCategoryConfidence(persistedRaw: $0) }),
           stored == .low {
            return true
        }
        if walletRawLabelChanged(notes: existing.notes, newRawLabel: classification.rawLabel) {
            return true
        }
        return false
    }

    nonisolated static func walletRawLabelChanged(notes: String?, newRawLabel: String) -> Bool {
        guard let notes,
              let oldRaw = WalletStatementIntelligence.rawLabelFromStoredNote(notes) else {
            return false
        }
        let oldNorm = MerchantLogoEngine.normalizeMerchantName(oldRaw)
        let newNorm = MerchantLogoEngine.normalizeMerchantName(newRawLabel)
        return oldNorm != newNorm
    }
}

#if canImport(FinanceKit)
import FinanceKit

extension WalletTransactionClassifier {
    nonisolated static func classify(
        tx: FinanceKit.Transaction,
        merchantContexts: [WalletMerchantContext],
        userMemoryLookup: (String, String?) throws -> TransactionCategory?
    ) throws -> WalletTransactionClassification? {
        let rawLabel = (tx.merchantName ?? tx.transactionDescription)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawLabel.isEmpty else { return nil }

        let resolution = WalletStatementIntelligence.resolve(
            rawLabel: rawLabel,
            contexts: merchantContexts
        )
        let displayName = resolution.canonicalName.isEmpty ? rawLabel : resolution.canonicalName
        let userMemoryCategory = try userMemoryLookup(displayName, rawLabel)
        let decision = WalletCategoryIntelligence.classify(
            WalletCategoryIntelligence.input(
                from: tx,
                rawLabel: rawLabel,
                displayName: displayName,
                userMemoryCategory: userMemoryCategory
            )
        )
        return WalletTransactionClassification(
            rawLabel: rawLabel,
            displayName: displayName,
            resolution: resolution,
            decision: decision,
            userMemoryCategory: userMemoryCategory
        )
    }
}
#endif
