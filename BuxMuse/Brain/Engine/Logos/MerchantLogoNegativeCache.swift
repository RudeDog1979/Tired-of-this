//
//  MerchantLogoNegativeCache.swift
//  BuxMuse
//
//  Short-lived memory of domains that failed favicon fetch — avoids repeat network storms.
//

import Foundation

enum MerchantLogoNegativeCache {
    nonisolated private static let ttl: TimeInterval = 24 * 60 * 60
    nonisolated private static let queue = DispatchQueue(label: "com.buxmuse.app.merchant-logo-negative-cache")
    private nonisolated(unsafe) static var failures: [String: Date] = [:]

    nonisolated static func isFailure(_ cacheKey: String) -> Bool {
        let key = normalized(cacheKey)
        guard !key.isEmpty else { return false }
        return queue.sync {
            pruneExpiredLocked()
            guard let expiry = failures[key] else { return false }
            if expiry > Date() { return true }
            failures.removeValue(forKey: key)
            return false
        }
    }

    nonisolated static func markFailure(_ cacheKey: String) {
        let key = normalized(cacheKey)
        guard !key.isEmpty else { return }
        queue.async {
            pruneExpiredLocked()
            failures[key] = Date().addingTimeInterval(ttl)
        }
    }

    nonisolated static func clearAll() {
        queue.async {
            failures.removeAll()
        }
    }

    private nonisolated static func normalized(_ key: String) -> String {
        key.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private nonisolated static func pruneExpiredLocked() {
        let now = Date()
        failures = failures.filter { $0.value > now }
    }
}
