//
//  StudioPlannerL10n.swift
//  BuxMuse
//

import Foundation

enum StudioPlannerL10n {
    static func line(_ key: String, locale: Locale) -> String {
        BuxCatalogLabel.string(key, locale: locale)
    }

    static func format(_ key: String, locale: Locale, _ arguments: CVarArg...) -> String {
        BuxLocalizedString.format(key, locale: locale, arguments)
    }
}
