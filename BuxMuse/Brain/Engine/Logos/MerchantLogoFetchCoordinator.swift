//
//  MerchantLogoFetchCoordinator.swift
//  BuxMuse
//
//  Global bounded queue for merchant favicon fetches — dedupes in-flight work
//  and caps concurrent network requests so expense lists never storm URLSession.
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif

public actor MerchantLogoFetchCoordinator {
    public static let shared = MerchantLogoFetchCoordinator()

    private var inFlight: [String: Task<UIImage?, Never>] = [:]
    private var activeFetches = 0
    private var slotWaiters: [CheckedContinuation<Void, Never>] = []
    private let maxConcurrentFetches = 8

    private init() {}

    /// Disk/RAM only — safe for scroll hot paths.
    public nonisolated func cachedImage(forCacheKey cacheKey: String) -> UIImage? {
        LightweightLogoCache.shared.getImage(forKey: cacheKey)
    }

    /// Returns cached image immediately; otherwise enqueues a deduped background fetch.
    public func image(
        for plan: MerchantLogoEngine.FetchPlan,
        shouldFetch: Bool
    ) async -> UIImage? {
        let key = plan.cacheKey
        if let cached = cachedImage(forCacheKey: key) {
            return cached
        }
        guard shouldFetch else { return nil }

        if let existing = inFlight[key] {
            return await existing.value
        }

        let task = Task<UIImage?, Never> { [plan] in
            await self.performFetch(plan: plan)
        }
        inFlight[key] = task
        let result = await task.value
        inFlight[key] = nil
        return result
    }

    /// Fire-and-forget warm-up after merchant persistence — never blocks callers.
    public func prefetch(plan: MerchantLogoEngine.FetchPlan, shouldFetch: Bool) async {
        guard shouldFetch else { return }
        if cachedImage(forCacheKey: plan.cacheKey) != nil { return }
        _ = await image(for: plan, shouldFetch: true)
    }

    /// Deduped parallel warm-up after wallet import — fills disk cache before list cells ask.
    public func prefetchPlans(_ plans: [MerchantLogoEngine.FetchPlan], shouldFetch: Bool) async {
        guard shouldFetch else { return }
        var seen = Set<String>()
        await withTaskGroup(of: Void.self) { group in
            for plan in plans {
                guard seen.insert(plan.cacheKey).inserted else { continue }
                guard cachedImage(forCacheKey: plan.cacheKey) == nil else { continue }
                group.addTask {
                    _ = await self.image(for: plan, shouldFetch: true)
                }
            }
        }
    }

    private func performFetch(plan: MerchantLogoEngine.FetchPlan) async -> UIImage? {
        await acquireSlot()
        defer { releaseSlot() }
        return await MerchantLogoEngine.fetchRemoteLogo(plan: plan)
    }

    private func acquireSlot() async {
        if activeFetches < maxConcurrentFetches {
            activeFetches += 1
            return
        }
        await withCheckedContinuation { continuation in
            slotWaiters.append(continuation)
        }
        activeFetches += 1
    }

    private func releaseSlot() {
        activeFetches = max(0, activeFetches - 1)
        if !slotWaiters.isEmpty {
            let next = slotWaiters.removeFirst()
            next.resume()
        }
    }
}
