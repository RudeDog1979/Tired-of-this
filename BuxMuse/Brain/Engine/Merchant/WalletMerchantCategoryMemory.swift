//
//  WalletMerchantCategoryMemory.swift
//  BuxMuse
//
//  On-device merchant → category memory from manual user corrections only.
//

import Foundation

enum WalletMerchantCategoryMemory {
    /// Normalized lookup keys for a merchant display name and optional wallet statement label.
    nonisolated static func normalizedKeys(merchantName: String, walletRawLabel: String?) -> [String] {
        var keys: [String] = []
        var seen = Set<String>()

        func append(_ value: String) {
            let key = MerchantLogoEngine.normalizeMerchantName(value)
            guard !key.isEmpty, seen.insert(key).inserted else { return }
            keys.append(key)
        }

        append(merchantName)
        if let walletRawLabel {
            append(walletRawLabel)
        }
        return keys
    }
}
