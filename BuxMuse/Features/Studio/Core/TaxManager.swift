//
//  TaxManager.swift
//  BuxMuse
//
//  Global self-employed tax reference — bundled fallback + remote cache (monthly refresh).
//

import Foundation
import Combine

@MainActor
public final class TaxManager: ObservableObject {
    public static let shared = TaxManager()

    /// Always use `/raw/buxmuse_tax.json` — never pin a gist revision SHA or updates never arrive.
    public static let taxJSONURL = URL(string: "https://gist.githubusercontent.com/RudeDog1979/d450143a13ad1df94f99f11c5ffef863/raw/buxmuse_tax.json")!

    @Published public private(set) var countries: [String: TaxInfo] = [:]
    @Published public private(set) var isLoading = false
    @Published public private(set) var lastLoadError: String?

    private var appliedUpdatedAt: String?
    private var isFetching = false

    private static let cacheFileName = "buxmuse_tax_cache.json"
    private static let lastFetchMonthKey = "buxmuse.tax.lastFetchMonth"
    private static let lastFetchLastDayKey = "buxmuse.tax.lastFetchLastDay"

    private static let countryAliases: [String: String] = [
        "UK": "GB",
        "EL": "GR"
    ]

    private init() {
        loadCachedOrBundled()
    }

    public var catalogUpdatedAt: String? { appliedUpdatedAt }

    public func taxForUser(country: String) -> TaxInfo? {
        let normalized = Self.normalizeCountryCode(country)
        return countries[normalized]
    }

    public func preset(for code: String) -> TaxInfo? {
        taxForUser(country: code)
    }

    public var sortedCountryOptions: [(code: String, name: String)] {
        allCountriesSorted.map { ($0.isoCode, $0.name) }
    }

    public var allCountriesSorted: [TaxInfo] {
        countries.values.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    public static func normalizeCountryCode(_ code: String) -> String {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return countryAliases[trimmed] ?? trimmed
    }

    // MARK: - Remote refresh (mirrors BuxTipsEngine — monthly on last calendar day)

    /// True when a remote fetch is due (last day of month publish, or catch-up in a new month).
    public func shouldFetchRemote(force: Bool = false) -> Bool {
        if force { return true }

        let monthKey = Self.currentMonthKey(for: Date())
        let lastFetchMonth = UserDefaults.standard.string(forKey: Self.lastFetchMonthKey)

        if Self.isLastDayOfMonth(Date()) {
            let lastDayToken = "lastDay-\(monthKey)"
            if UserDefaults.standard.string(forKey: Self.lastFetchLastDayKey) != lastDayToken {
                return true
            }
        }

        if lastFetchMonth == nil { return true }

        if let lastFetchMonth, lastFetchMonth < monthKey { return true }

        return false
    }

    /// Fetches remote tax catalog at most once per calendar month — primary window is the last day (catalog publish day).
    public func refreshIfNeeded(force: Bool = false) async {
        guard !isFetching else { return }
        guard shouldFetchRemote(force: force) else { return }

        let monthKey = Self.currentMonthKey(for: Date())
        isFetching = true
        isLoading = true
        lastLoadError = nil
        defer {
            isFetching = false
            isLoading = false
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: Self.taxJSONURL)
            _ = try applyPayload(data: data, persist: true, force: force)
            UserDefaults.standard.set(monthKey, forKey: Self.lastFetchMonthKey)
            if Self.isLastDayOfMonth(Date()) {
                UserDefaults.standard.set("lastDay-\(monthKey)", forKey: Self.lastFetchLastDayKey)
            }
        } catch {
            lastLoadError = error.localizedDescription
            if countries.isEmpty {
                loadCachedOrBundled()
            }
        }
    }

    /// Ensures catalog is loaded locally, then refreshes from remote when the monthly window allows.
    public func ensureCatalogLoaded(force: Bool = false) async {
        if countries.isEmpty {
            loadCachedOrBundled()
        }
        await refreshIfNeeded(force: force)
    }

    // MARK: - Local payload

    private func loadCachedOrBundled() {
        if let cached = readData(from: cacheURL) {
            _ = try? applyPayload(data: cached, persist: false)
            if !countries.isEmpty { return }
        }
        if let bundled = bundledData() {
            _ = try? applyPayload(data: bundled, persist: false)
        }
    }

    @discardableResult
    private func applyPayload(data: Data, persist: Bool, force: Bool = false) throws -> TaxDatabasePayload {
        let payload = try JSONDecoder().decode(TaxDatabasePayload.self, from: data)
        if !force,
           let current = appliedUpdatedAt,
           payload.updatedAt.compare(current, options: .numeric) != .orderedDescending {
            return payload
        }
        countries = payload.countries
        appliedUpdatedAt = payload.updatedAt
        TaxTranslationCache.purgeStaleCatalogVersions(keeping: payload.updatedAt)
        if persist {
            try data.write(to: cacheURL, options: .atomic)
        }
        return payload
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

    private func bundledData() -> Data? {
        guard let url = Bundle.main.url(forResource: "buxmuse_tax", withExtension: "json") else { return nil }
        return try? Data(contentsOf: url)
    }

    // MARK: - Calendar helpers

    static func currentMonthKey(for date: Date, calendar: Calendar = .current) -> String {
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        return String(format: "%04d-%02d", year, month)
    }

    /// Last calendar day of the month — handles February (28/29) and all month lengths.
    static func isLastDayOfMonth(_ date: Date, calendar: Calendar = .current) -> Bool {
        let day = calendar.component(.day, from: date)
        guard let range = calendar.range(of: .day, in: .month, for: date) else { return false }
        return day == range.count
    }
}
