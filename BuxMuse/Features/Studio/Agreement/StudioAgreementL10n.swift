//
//  StudioAgreementL10n.swift
//  BuxMuse
//

import Foundation

extension StudioAgreementTermsCategory {
    func catalogLabel(locale: Locale) -> String {
        BuxCatalogLabel.string(label, locale: locale)
    }
}

extension StudioAgreementTermsPack {
    func catalogTitle(locale: Locale) -> String {
        BuxCatalogLabel.string(title, locale: locale)
    }

    func catalogSubtitle(locale: Locale) -> String {
        BuxCatalogLabel.string(subtitle, locale: locale)
    }
}

extension StudioAgreementTermsClause {
    func catalogTitle(locale: Locale) -> String {
        BuxCatalogLabel.string(title, locale: locale)
    }
}

enum StudioAgreementL10n {
    static func line(_ key: String, locale: Locale) -> String {
        BuxCatalogLabel.string(key, locale: locale)
    }

    static func format(_ key: String, locale: Locale, _ arguments: CVarArg...) -> String {
        BuxLocalizedString.format(key, locale: locale, arguments)
    }
}
