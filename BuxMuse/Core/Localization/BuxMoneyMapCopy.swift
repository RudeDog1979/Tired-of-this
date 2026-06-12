//
//  BuxMoneyMapCopy.swift
//  BuxMuse
//
//  Localizes Money Map territory copy stored as English source keys.
//

import Foundation

enum MoneyMapL10n {
    static func string(_ key: String, locale: Locale = BuxInterfaceLocale.currentInterfaceLocale) -> String {
        BuxLocalizedString.string(String.LocalizationValue(stringLiteral: key), locale: locale)
    }

    static func format(_ key: String, locale: Locale = BuxInterfaceLocale.currentInterfaceLocale, _ arguments: CVarArg...) -> String {
        BuxLocalizedString.format(String.LocalizationValue(stringLiteral: key), locale: locale, arguments)
    }
}

extension MoneyMapNode {
    func localizedTitle(locale: Locale = BuxInterfaceLocale.currentInterfaceLocale) -> String {
        MoneyMapL10n.string(title, locale: locale)
    }

    func localizedSubtitle(locale: Locale = BuxInterfaceLocale.currentInterfaceLocale) -> String {
        MoneyMapL10n.string(subtitle, locale: locale)
    }
}

extension MoneyMapTerritoryDetail {
    func localizedExplanation(locale: Locale = BuxInterfaceLocale.currentInterfaceLocale) -> String {
        MoneyMapL10n.string(explanation, locale: locale)
    }

    func localizedDeepLinkLabel(locale: Locale = BuxInterfaceLocale.currentInterfaceLocale) -> String? {
        deepLinkLabel.map { MoneyMapL10n.string($0, locale: locale) }
    }

    func localizedMetricLines(locale: Locale = BuxInterfaceLocale.currentInterfaceLocale) -> [(String, String)] {
        metricLines.map { (MoneyMapL10n.string($0.0, locale: locale), $0.1) }
    }
}

extension MoneyMapGraph {
    func localizedCenterTitle(locale: Locale = BuxInterfaceLocale.currentInterfaceLocale) -> String {
        MoneyMapL10n.string(centerTitle, locale: locale)
    }

    func localizedCenterSubtitle(locale: Locale = BuxInterfaceLocale.currentInterfaceLocale) -> String {
        MoneyMapL10n.string(centerSubtitle, locale: locale)
    }
}
