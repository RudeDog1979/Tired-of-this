//
//  SubscriptionBillingCycle+Localization.swift
//  BuxMuse
//
//  Localize billing cycle chips on dashboard subscription cards.
//

import Foundation

extension SubscriptionBillingCycle {
    func localizedDisplayName(locale: Locale = BuxInterfaceLocale.currentInterfaceLocale) -> String {
        BuxLocalizedString.string(
            String.LocalizationValue(stringLiteral: displayName),
            locale: locale
        )
    }
}
