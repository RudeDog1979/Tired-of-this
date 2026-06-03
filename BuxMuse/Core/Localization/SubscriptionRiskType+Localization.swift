//
//  SubscriptionRiskType+Localization.swift
//  BuxMuse
//

import Foundation

extension SubscriptionRiskType {
    func localizedDisplayName(locale: Locale = BuxInterfaceLocale.currentInterfaceLocale) -> String {
        BuxLocalizedString.string(
            String.LocalizationValue(stringLiteral: displayName),
            locale: locale
        )
    }
}

