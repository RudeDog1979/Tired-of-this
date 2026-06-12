//
//  BuxInsightCopy.swift
//  BuxMuse
//
//  Localizes insight titles/descriptions stored as English source keys.
//

import Foundation

enum BuxInsightCopy {
    static func title(_ sourceKey: String, locale: Locale = BuxInterfaceLocale.currentInterfaceLocale) -> String {
        BuxLocalizedString.string(String.LocalizationValue(stringLiteral: sourceKey), locale: locale)
    }

    static func description(_ sourceKey: String, locale: Locale = BuxInterfaceLocale.currentInterfaceLocale) -> String {
        BuxLocalizedString.string(String.LocalizationValue(stringLiteral: sourceKey), locale: locale)
    }

    static func subtitle(_ sourceKey: String, locale: Locale = BuxInterfaceLocale.currentInterfaceLocale) -> String {
        BuxLocalizedString.string(String.LocalizationValue(stringLiteral: sourceKey), locale: locale)
    }

    /// Full sentences stored as English source keys (`fullExplanation`, `suggestedActions`, `dataBehind`).
    static func copy(_ sourceKey: String, locale: Locale = BuxInterfaceLocale.currentInterfaceLocale) -> String {
        BuxLocalizedString.string(String.LocalizationValue(stringLiteral: sourceKey), locale: locale)
    }
}

extension FinancialInsight {
    func localizedTitle(locale: Locale = BuxInterfaceLocale.currentInterfaceLocale) -> String {
        if title.hasSuffix(" Overspend") {
            let name = String(title.dropLast(" Overspend".count))
            return BuxLocalizedString.format("%@ Overspend", locale: locale, name)
        }
        if title.hasSuffix(" Optimization") {
            let name = String(title.dropLast(" Optimization".count))
            return BuxLocalizedString.format("%@ Optimization", locale: locale, name)
        }
        return BuxInsightCopy.title(title, locale: locale)
    }

    func localizedDescription(locale: Locale = BuxInterfaceLocale.currentInterfaceLocale) -> String {
        BuxInsightCopy.description(description, locale: locale)
    }

    func localizedFullExplanation(locale: Locale = BuxInterfaceLocale.currentInterfaceLocale) -> String {
        BuxInsightCopy.copy(fullExplanation, locale: locale)
    }

    func localizedDataBehind(locale: Locale = BuxInterfaceLocale.currentInterfaceLocale) -> String {
        BuxInsightCopy.copy(dataBehind, locale: locale)
    }

    func localizedSuggestedAction(_ action: String, locale: Locale = BuxInterfaceLocale.currentInterfaceLocale) -> String {
        BuxInsightCopy.copy(action, locale: locale)
    }

    func localizedValue(locale: Locale = BuxInterfaceLocale.currentInterfaceLocale) -> String {
        BuxInsightCopy.title(value, locale: locale)
    }
}

extension FeatureInsightStrip {
    func localizedTitle(locale: Locale = BuxInterfaceLocale.currentInterfaceLocale) -> String {
        BuxInsightCopy.title(title, locale: locale)
    }

    func localizedSubtitle(locale: Locale = BuxInterfaceLocale.currentInterfaceLocale) -> String {
        BuxInsightCopy.subtitle(subtitle, locale: locale)
    }
}
