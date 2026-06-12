//
//  TaxPresetTranslator.swift
//  BuxMuse
//
//  Localizes tax preset rule boxes via Apple Translation (on-device), with disk cache.
//

import Foundation
import Translation

struct TaxProfileTextFields: Equatable, Sendable {
    var incomeTax: String
    var selfEmployedTax: String
    var indirectTax: String
    var notes: String

    init(
        incomeTax: String = "",
        selfEmployedTax: String = "",
        indirectTax: String = "",
        notes: String = ""
    ) {
        self.incomeTax = incomeTax
        self.selfEmployedTax = selfEmployedTax
        self.indirectTax = indirectTax
        self.notes = notes
    }

    init(profile: StudioTaxProfile) {
        incomeTax = profile.customIncomeTax ?? ""
        selfEmployedTax = profile.customSelfEmployedTax ?? ""
        indirectTax = profile.customIndirectTax ?? ""
        notes = profile.customNotes ?? ""
    }
}

enum TaxPresetTranslator {
    static let canonicalSourceTag = "en"

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

    /// Display profile rule text in the user's app language (canonical English in storage).
    @MainActor
    static func localizedProfileFields(
        _ fields: TaxProfileTextFields,
        interfaceLocale: Locale
    ) async -> TaxProfileTextFields {
        guard let targetTag = translationTargetTag(for: interfaceLocale) else {
            return fields
        }
        return TaxProfileTextFields(
            incomeTax: await translateText(fields.incomeTax, from: canonicalSourceTag, to: targetTag),
            selfEmployedTax: await translateText(fields.selfEmployedTax, from: canonicalSourceTag, to: targetTag),
            indirectTax: await translateText(fields.indirectTax, from: canonicalSourceTag, to: targetTag),
            notes: await translateText(fields.notes, from: canonicalSourceTag, to: targetTag)
        )
    }

    /// Persist profile rule text as canonical English regardless of current UI language.
    @MainActor
    static func canonicalProfileFields(
        _ fields: TaxProfileTextFields,
        interfaceLocale: Locale
    ) async -> TaxProfileTextFields {
        guard let uiTag = translationTargetTag(for: interfaceLocale) else {
            return fields
        }
        return TaxProfileTextFields(
            incomeTax: await translateText(fields.incomeTax, from: uiTag, to: canonicalSourceTag),
            selfEmployedTax: await translateText(fields.selfEmployedTax, from: uiTag, to: canonicalSourceTag),
            indirectTax: await translateText(fields.indirectTax, from: uiTag, to: canonicalSourceTag),
            notes: await translateText(fields.notes, from: uiTag, to: canonicalSourceTag)
        )
    }

    /// Repairs profiles that previously saved translated preset copy instead of English source.
    @MainActor
    static func recoverEnglishFromLegacyTranslation(
        _ fields: TaxProfileTextFields,
        presetCode: String?,
        catalogUpdatedAt: String?
    ) async -> TaxProfileTextFields {
        guard let presetCode,
              !presetCode.isEmpty,
              let preset = TaxPresetLoader.preset(for: presetCode),
              let catalogUpdatedAt,
              !catalogUpdatedAt.isEmpty,
              let targetTag = translationTargetTag(for: Locale(identifier: "es")) else {
            return fields
        }

        let cacheKey = TaxTranslationCache.cacheKey(
            catalogUpdatedAt: catalogUpdatedAt,
            isoCode: preset.isoCode,
            targetLanguage: targetTag
        )
        guard let cached = TaxTranslationCache.loadEntry(for: cacheKey) else {
            return fields
        }

        var recovered = fields
        for field in TaxPresetTranslationField.allCases {
            let stored = field.profileText(from: recovered).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !stored.isEmpty,
                  let translated = cached.translated[field.rawValue],
                  stored == translated.trimmingCharacters(in: .whitespacesAndNewlines) else {
                continue
            }
            recovered = field.apply(field.sourceText(from: preset), to: recovered)
        }
        return recovered
    }

    @MainActor
    static func translateText(_ text: String, from sourceTag: String, to targetTag: String) async -> String {
        await TaxTranslationSessionBridge.shared.translate(text, sourceTag: sourceTag, targetTag: targetTag)
    }

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
