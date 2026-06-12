//
//  AppTheme+Localization.swift
//  BuxMuse
//

import Foundation

extension AppTheme {
    func localizedName(locale: Locale = BuxInterfaceLocale.currentInterfaceLocale) -> String {
        BuxCatalogLabel.string(name, locale: locale)
    }
}
