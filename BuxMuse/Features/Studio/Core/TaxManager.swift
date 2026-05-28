//
//  TaxManager.swift
//  BuxMuse
//
//  Serves global self-employed tax reference JSON (bundle + read-only cache only).
//

import Foundation
import Combine

@MainActor
public final class TaxManager: ObservableObject {
    public static let shared = TaxManager()

    public static let taxJSONURL = URL(string: "https://gist.githubusercontent.com/RudeDog1979/d450143a13ad1df94f99f11c5ffef863/raw/buxmuse_tax.json")!

    @Published public private(set) var countries: [String: TaxInfo] = [:]
    @Published public private(set) var isLoading = false
    @Published public private(set) var lastLoadError: String?

    private var appliedUpdatedAt: String?

    private static let cacheFileName = "buxmuse_tax_cache.json"

    private static let countryAliases: [String: String] = [
        "UK": "GB",
        "EL": "GR"
    ]

    private init() {
        loadCachedOrBundled()
    }

    /// Bundled / on-disk cache only — no network (Tax Studio policy).
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
}
