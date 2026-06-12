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

extension AgreementSignatureRole {
    func catalogTitle(locale: Locale) -> String {
        switch self {
        case .client: StudioAgreementL10n.line("Client signature", locale: locale)
        case .provider: StudioAgreementL10n.line("Your signature", locale: locale)
        }
    }

    func catalogShortLabel(locale: Locale) -> String {
        switch self {
        case .client: StudioAgreementL10n.line("Client", locale: locale)
        case .provider: StudioAgreementL10n.line("You", locale: locale)
        }
    }

    func catalogPrompt(locale: Locale) -> String {
        switch self {
        case .client:
            StudioAgreementL10n.line(
                "Hand the device to your client to sign with a finger or stylus.",
                locale: locale
            )
        case .provider:
            StudioAgreementL10n.line("Sign to confirm you agree to the terms above.", locale: locale)
        }
    }
}
