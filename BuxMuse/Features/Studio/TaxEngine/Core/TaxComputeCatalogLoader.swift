//
//  TaxComputeCatalogLoader.swift
//  BuxMuse
//
//  Loads structured compute catalog — bundled fallback + remote cache (monthly refresh).
//

import Combine
import Foundation

public enum TaxComputeCatalogLoader {

    private static let bundledResourceName = "buxmuse_tax_compute"

    public static func loadBundled() -> TaxComputeCatalogPayload? {
        guard let url = Bundle.main.url(forResource: bundledResourceName, withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            return nil
        }
        return decodePayload(data)
    }

    public static func decodePayload(_ data: Data) -> TaxComputeCatalogPayload? {
        try? JSONDecoder().decode(TaxComputeCatalogPayload.self, from: data)
    }

    /// Merges remote catalog with bundled T1 entries so verified modules never regress.
    public static func mergePreservingBundledVerified(
        remote: TaxComputeCatalogPayload,
        bundled: TaxComputeCatalogPayload?
    ) -> TaxComputeCatalogPayload {
        guard let bundled else { return remote }
        var countries = remote.countries
        for (code, entry) in bundled.countries where entry.meta.coverageTier == .verified {
            if let remoteEntry = countries[code],
               remoteEntry.meta.coverageTier != .verified,
               !hasIncomeBrackets(remoteEntry) {
                countries[code] = entry
            } else if countries[code] == nil {
                countries[code] = entry
            }
        }
        let updatedAt = max(remote.updatedAt, bundled.updatedAt)
        return TaxComputeCatalogPayload(
            schemaVersion: remote.schemaVersion,
            updatedAt: updatedAt,
            countries: countries
        )
    }

    private static func hasIncomeBrackets(_ entry: TaxCountryComputeEntry) -> Bool {
        !(entry.national.selfEmployed?.brackets.isEmpty ?? true)
    }

    public static func sharedEntry(
        for countryCode: String,
        catalog: TaxComputeCatalogPayload? = nil
    ) -> TaxCountryComputeEntry? {
        let resolved = catalog ?? TaxComputeCatalogStore.shared.payload
        let code = TaxManager.normalizeCountryCode(countryCode)
        return resolved?.countries[code]
    }
}

public final class TaxComputeCatalogStore: ObservableObject {
    public static let shared = TaxComputeCatalogStore()

    /// Same gist host as prose catalog — `/raw/buxmuse_tax_compute.json`.
    public static let computeJSONURL = URL(
        string: "https://gist.githubusercontent.com/RudeDog1979/d450143a13ad1df94f99f11c5ffef863/raw/buxmuse_tax_compute.json"
    )!

    @Published public private(set) var payload: TaxComputeCatalogPayload?
    @Published public private(set) var isLoading = false
    @Published public private(set) var lastLoadError: String?

    private var appliedUpdatedAt: String?
    private var isFetching = false

    private static let cacheFileName = "buxmuse_tax_compute_cache.json"
    private static let lastFetchMonthKey = "buxmuse.taxCompute.lastFetchMonth"
    private static let lastFetchLastDayKey = "buxmuse.taxCompute.lastFetchLastDay"

    private init() {
        loadCachedOrBundled()
    }

    public var catalogUpdatedAt: String? { payload?.updatedAt }

    public func entry(for countryCode: String) -> TaxCountryComputeEntry? {
        let code = TaxManager.normalizeCountryCode(countryCode)
        return payload?.countries[code]
    }

    public func regions(for countryCode: String) -> [TaxComputeRegion] {
        entry(for: countryCode)?.meta.regions ?? []
    }

    public func coverageTier(for countryCode: String) -> TaxCoverageTier {
        entry(for: countryCode)?.meta.coverageTier ?? .manualOverride
    }

    // MARK: - Remote refresh (mirrors TaxManager)

    public func shouldFetchRemote(force: Bool = false) -> Bool {
        if force { return true }

        let monthKey = TaxManager.currentMonthKey(for: Date())
        let lastFetchMonth = UserDefaults.standard.string(forKey: Self.lastFetchMonthKey)

        if TaxManager.isLastDayOfMonth(Date()) {
            let lastDayToken = "lastDay-\(monthKey)"
            if UserDefaults.standard.string(forKey: Self.lastFetchLastDayKey) != lastDayToken {
                return true
            }
        }

        if lastFetchMonth == nil { return true }
        if let lastFetchMonth, lastFetchMonth < monthKey { return true }
        return false
    }

    @MainActor
    public func refreshIfNeeded(force: Bool = false) async {
        guard !isFetching else { return }
        guard shouldFetchRemote(force: force) else { return }

        let monthKey = TaxManager.currentMonthKey(for: Date())
        isFetching = true
        isLoading = true
        lastLoadError = nil
        defer {
            isFetching = false
            isLoading = false
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: Self.computeJSONURL)
            _ = try applyPayload(data: data, persist: true, force: force)
            UserDefaults.standard.set(monthKey, forKey: Self.lastFetchMonthKey)
            if TaxManager.isLastDayOfMonth(Date()) {
                UserDefaults.standard.set("lastDay-\(monthKey)", forKey: Self.lastFetchLastDayKey)
            }
        } catch {
            lastLoadError = error.localizedDescription
            if payload == nil {
                loadCachedOrBundled()
            }
        }
    }

    @MainActor
    public func ensureCatalogLoaded(force: Bool = false) async {
        if payload == nil {
            loadCachedOrBundled()
        }
        await refreshIfNeeded(force: force)
    }

    // MARK: - Local payload

    private func loadCachedOrBundled() {
        if let cached = readData(from: cacheURL),
           let decoded = TaxComputeCatalogLoader.decodePayload(cached) {
            payload = decoded
            appliedUpdatedAt = decoded.updatedAt
            return
        }
        if let bundled = TaxComputeCatalogLoader.loadBundled() {
            payload = bundled
            appliedUpdatedAt = bundled.updatedAt
        }
    }

    @discardableResult
    private func applyPayload(data: Data, persist: Bool, force: Bool = false) throws -> TaxComputeCatalogPayload {
        guard let decoded = TaxComputeCatalogLoader.decodePayload(data) else {
            throw URLError(.cannotDecodeContentData)
        }
        let merged = TaxComputeCatalogLoader.mergePreservingBundledVerified(
            remote: decoded,
            bundled: TaxComputeCatalogLoader.loadBundled()
        )
        if !force,
           let current = appliedUpdatedAt,
           merged.updatedAt.compare(current, options: .numeric) != .orderedDescending {
            return merged
        }
        payload = merged
        appliedUpdatedAt = merged.updatedAt
        if persist {
            try data.write(to: cacheURL, options: .atomic)
        }
        return decoded
    }

    private var cacheURL: URL {
        let fm = FileManager.default
        let dir = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("TaxReference", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir.appendingPathComponent(Self.cacheFileName)
    }

    private func readData(from url: URL) -> Data? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try? Data(contentsOf: url)
    }
}
