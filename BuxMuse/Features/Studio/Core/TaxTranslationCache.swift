//
//  TaxTranslationCache.swift
//  BuxMuse
//
//  On-device cache for Apple-translated tax preset rule text (lazy, versioned).
//

import CryptoKit
import Foundation

enum TaxPresetTranslationField: String, Codable, CaseIterable, Sendable {
    case vat
    case income_tax
    case self_employed_tax
    case notes
}

struct TaxTranslationCacheEntry: Codable, Equatable, Sendable {
    var catalogUpdatedAt: String
    var isoCode: String
    var targetLanguage: String
    /// Field raw value → SHA256 prefix of English source at translation time.
    var sourceHashes: [String: String]
    /// Field raw value → translated text.
    var translated: [String: String]
}

struct TaxTranslationCachePayload: Codable, Equatable, Sendable {
    var entries: [String: TaxTranslationCacheEntry]
}

enum TaxTranslationCache {
    private static let fileName = "tax_translation_cache.json"

    static func cacheKey(
        catalogUpdatedAt: String,
        isoCode: String,
        targetLanguage: String
    ) -> String {
        "\(catalogUpdatedAt)|\(isoCode.uppercased())|\(targetLanguage)"
    }

    static func contentHash(_ text: String) -> String {
        let digest = SHA256.hash(data: Data(text.utf8))
        return digest.prefix(8).map { String(format: "%02x", $0) }.joined()
    }

    static func sourceHashes(for preset: TaxInfo) -> [String: String] {
        var hashes: [String: String] = [:]
        for field in TaxPresetTranslationField.allCases {
            let source = field.sourceText(from: preset)
            if !source.isEmpty {
                hashes[field.rawValue] = contentHash(source)
            }
        }
        return hashes
    }

    static func loadEntry(for key: String) -> TaxTranslationCacheEntry? {
        loadPayload().entries[key]
    }

    static func saveEntry(_ entry: TaxTranslationCacheEntry, for key: String) {
        var payload = loadPayload()
        payload.entries[key] = entry
        persist(payload)
    }

    /// Drops cached translations from older monthly catalog versions.
    static func purgeStaleCatalogVersions(keeping currentUpdatedAt: String) {
        var payload = loadPayload()
        let before = payload.entries.count
        payload.entries = payload.entries.filter { $0.value.catalogUpdatedAt == currentUpdatedAt }
        guard payload.entries.count != before else { return }
        persist(payload)
    }

    static func clearAll() {
        persist(TaxTranslationCachePayload(entries: [:]))
    }

    // MARK: - Private

    private static var cacheURL: URL {
        let fm = FileManager.default
        let dir = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("TaxReference", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir.appendingPathComponent(fileName)
    }

    private static func loadPayload() -> TaxTranslationCachePayload {
        guard let data = try? Data(contentsOf: cacheURL),
              let payload = try? JSONDecoder().decode(TaxTranslationCachePayload.self, from: data) else {
            return TaxTranslationCachePayload(entries: [:])
        }
        return payload
    }

    private static func persist(_ payload: TaxTranslationCachePayload) {
        guard let data = try? JSONEncoder().encode(payload) else { return }
        try? data.write(to: cacheURL, options: .atomic)
    }
}

extension TaxPresetTranslationField {
    func sourceText(from preset: TaxInfo) -> String {
        switch self {
        case .vat: return preset.vat
        case .income_tax: return preset.income_tax
        case .self_employed_tax: return preset.self_employed_tax
        case .notes: return preset.notes
        }
    }

    func apply(_ value: String, to preset: TaxInfo) -> TaxInfo {
        switch self {
        case .vat:
            return preset.replacing(vat: value)
        case .income_tax:
            return preset.replacing(incomeTax: value)
        case .self_employed_tax:
            return preset.replacing(selfEmployedTax: value)
        case .notes:
            return preset.replacing(notes: value)
        }
    }
}

extension TaxInfo {
    func replacing(
        vat: String? = nil,
        incomeTax: String? = nil,
        selfEmployedTax: String? = nil,
        notes: String? = nil
    ) -> TaxInfo {
        TaxInfo(
            name: name,
            isoCode: isoCode,
            currency: currency,
            region: region,
            vat: vat ?? self.vat,
            income_tax: incomeTax ?? income_tax,
            self_employed_tax: selfEmployedTax ?? self_employed_tax,
            notes: notes ?? self.notes,
            lastVerified: lastVerified
        )
    }
}
