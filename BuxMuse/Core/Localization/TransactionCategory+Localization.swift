//
//  TransactionCategory+Localization.swift
//  BuxMuse
//
//  System expense categories use English keys in the catalog; localize at display.
//

import Foundation

extension TransactionCategory {
    /// English source key in `Localizable.xcstrings` (matches `displayName`).
    var catalogLabelKey: String { displayName }

    func localizedDisplayName(locale: Locale = BuxInterfaceLocale.currentInterfaceLocale) -> String {
        BuxLocalizedString.string(
            String.LocalizationValue(stringLiteral: catalogLabelKey),
            locale: locale
        )
    }
}

extension ExpenseCategoryRecord {
    /// Localized chip/list label; custom categories keep user-defined names.
    func localizedDisplayName(locale: Locale = BuxInterfaceLocale.currentInterfaceLocale) -> String {
        if isCustom { return name }
        if let raw = systemCategoryRaw, let system = TransactionCategory(rawValue: raw) {
            return system.localizedDisplayName(locale: locale)
        }
        return BuxLocalizedString.string(
            String.LocalizationValue(stringLiteral: name),
            locale: locale
        )
    }
}
