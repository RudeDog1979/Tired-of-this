//
//  TaxTranslationUX.swift
//  BuxMuse
//
//  Language-pack notice, availability checks, and English-fallback badge rules.
//

import Foundation
import Translation

struct TaxLocalizedPresetResult: Sendable {
    let preset: TaxInfo
    let usedEnglishFallback: Bool
}

enum TaxTranslationUX {
    static let packNoticeDismissedKey = "tax.translation.packNoticeDismissed"

    static func shouldShowPackNotice(interfaceLocale: Locale) -> Bool {
        guard TaxPresetTranslator.translationTargetTag(for: interfaceLocale) != nil else { return false }
        return !UserDefaults.standard.bool(forKey: packNoticeDismissedKey)
    }

    static func dismissPackNotice() {
        UserDefaults.standard.set(true, forKey: packNoticeDismissedKey)
    }

    @MainActor
    static func isLanguagePackInstalled(for interfaceLocale: Locale) async -> Bool {
        guard let tag = TaxPresetTranslator.translationTargetTag(for: interfaceLocale) else { return true }
        let availability = LanguageAvailability()
        let status = await availability.status(
            from: Locale.Language(identifier: "en"),
            to: Locale.Language(identifier: tag)
        )
        return status == .installed
    }

    static func usedEnglishFallback(source: TaxInfo, displayed: TaxInfo) -> Bool {
        guard hasTranslatableContent(source) else { return false }
        return source.income_tax == displayed.income_tax
            && source.self_employed_tax == displayed.self_employed_tax
            && source.vat == displayed.vat
            && source.notes == displayed.notes
    }

    static func shouldShowEnglishBadge(
        source: TaxInfo,
        displayed: TaxInfo,
        packInstalled: Bool,
        interfaceLocale: Locale
    ) -> Bool {
        guard TaxPresetTranslator.translationTargetTag(for: interfaceLocale) != nil else { return false }
        guard !packInstalled else { return false }
        return usedEnglishFallback(source: source, displayed: displayed)
    }

    private static func hasTranslatableContent(_ preset: TaxInfo) -> Bool {
        TaxPresetTranslationField.allCases.contains {
            !$0.sourceText(from: preset).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
}
