//
//  TaxPresetTranslator.swift
//  BuxMuse
//
//  Localizes tax preset rule boxes via Apple Translation (on-device), with disk cache.
//

import Foundation
import Translation

enum TaxPresetTranslator {
    /// BCP-47 tag for Apple Translation target, or nil when UI should stay English.
    static func translationTargetTag(for interfaceLocale: Locale) -> String? {
        let tag = BuxStringCatalog.resourceTag(for: interfaceLocale)
        if tag == "en" || tag.hasPrefix("en-") { return nil }
        if tag.hasPrefix("es") { return "es" }
        return nil
    }

    /// Returns cached or freshly translated preset rule text for the user's app language.
    @MainActor
    static func localizedPreset(
        _ preset: TaxInfo,
        catalogUpdatedAt: String?,
        interfaceLocale: Locale,
        session: TranslationSession
    ) async -> TaxLocalizedPresetResult {
        guard let targetTag = translationTargetTag(for: interfaceLocale),
              let catalogUpdatedAt,
              !catalogUpdatedAt.isEmpty else {
            return TaxLocalizedPresetResult(preset: preset, usedEnglishFallback: false)
        }

        let cacheKey = TaxTranslationCache.cacheKey(
            catalogUpdatedAt: catalogUpdatedAt,
            isoCode: preset.isoCode,
            targetLanguage: targetTag
        )
        let currentHashes = TaxTranslationCache.sourceHashes(for: preset)

        if let cached = TaxTranslationCache.loadEntry(for: cacheKey),
           cached.sourceHashes == currentHashes {
            let localized = apply(cached.translated, to: preset)
            return TaxLocalizedPresetResult(
                preset: localized,
                usedEnglishFallback: TaxTranslationUX.usedEnglishFallback(source: preset, displayed: localized)
            )
        }

        do {
            let translated = try await translateFields(
                of: preset,
                session: session,
                existing: TaxTranslationCache.loadEntry(for: cacheKey),
                currentHashes: currentHashes
            )
            let entry = TaxTranslationCacheEntry(
                catalogUpdatedAt: catalogUpdatedAt,
                isoCode: preset.isoCode,
                targetLanguage: targetTag,
                sourceHashes: currentHashes,
                translated: translated
            )
            TaxTranslationCache.saveEntry(entry, for: cacheKey)
            let localized = apply(translated, to: preset)
            let fallback = TaxTranslationUX.usedEnglishFallback(source: preset, displayed: localized)
            if !fallback {
                TaxTranslationUX.dismissPackNotice()
            }
            return TaxLocalizedPresetResult(preset: localized, usedEnglishFallback: fallback)
        } catch {
            #if DEBUG
            print("TaxPresetTranslator: translation failed for \(preset.isoCode): \(error)")
            #endif
            if let cached = TaxTranslationCache.loadEntry(for: cacheKey) {
                let localized = apply(cached.translated, to: preset)
                return TaxLocalizedPresetResult(
                    preset: localized,
                    usedEnglishFallback: TaxTranslationUX.usedEnglishFallback(source: preset, displayed: localized)
                )
            }
            return TaxLocalizedPresetResult(preset: preset, usedEnglishFallback: true)
        }
    }

    // Session must come from SwiftUI `.translationTask` (iOS 18+). See `TaxTranslationSessionBridge`.

    // MARK: - Private

    @MainActor
    private static func translateFields(
        of preset: TaxInfo,
        session: TranslationSession,
        existing: TaxTranslationCacheEntry?,
        currentHashes: [String: String]
    ) async throws -> [String: String] {
        var result = existing?.translated ?? [:]

        for field in TaxPresetTranslationField.allCases {
            let source = field.sourceText(from: preset).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !source.isEmpty else {
                result[field.rawValue] = ""
                continue
            }

            if let hash = currentHashes[field.rawValue],
               existing?.sourceHashes[field.rawValue] == hash,
               let cached = existing?.translated[field.rawValue] {
                result[field.rawValue] = cached
                continue
            }

            let response = try await session.translate(source)
            result[field.rawValue] = response.targetText
        }

        return result
    }

    private static func apply(_ translated: [String: String], to preset: TaxInfo) -> TaxInfo {
        var updated = preset
        for field in TaxPresetTranslationField.allCases {
            if let value = translated[field.rawValue] {
                updated = field.apply(value, to: updated)
            }
        }
        return updated
    }
}
