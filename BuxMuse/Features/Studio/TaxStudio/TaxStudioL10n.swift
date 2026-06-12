//
//  TaxStudioL10n.swift
//  BuxMuse
//
//  Tax Studio copy — English catalog keys resolved at display time.
//

import Foundation

enum TaxStudioL10n {
    static func line(_ key: String, locale: Locale) -> String {
        BuxCatalogLabel.string(key, locale: locale)
    }

    static func format(_ key: String, locale: Locale, _ arguments: CVarArg...) -> String {
        BuxLocalizedString.format(key, locale: locale, arguments)
    }
}

extension TaxStudioTab {
    func catalogLabel(locale: Locale) -> String {
        BuxCatalogLabel.string(rawValue, locale: locale)
    }
}

extension TaxIncomeType {
    func catalogSummaryLabel(locale: Locale) -> String {
        let key: String
        switch self {
        case .selfEmployed: key = "Self-employed tax rules"
        case .employed: key = "Employment tax rules"
        case .oneOff: key = "One-off / gig guidance"
        }
        return TaxStudioL10n.line(key, locale: locale)
    }
}
