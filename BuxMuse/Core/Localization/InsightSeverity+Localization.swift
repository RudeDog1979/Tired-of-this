//
//  InsightSeverity+Localization.swift
//  BuxMuse
//

import Foundation

extension InsightSeverity {
    func localizedDisplayName(locale: Locale = BuxInterfaceLocale.currentInterfaceLocale) -> String {
        switch self {
        case .low:
            return BuxLocalizedString.string("low", locale: locale)
        case .medium:
            return BuxLocalizedString.string("medium", locale: locale)
        case .high:
            return BuxLocalizedString.string("high", locale: locale)
        }
    }
}
