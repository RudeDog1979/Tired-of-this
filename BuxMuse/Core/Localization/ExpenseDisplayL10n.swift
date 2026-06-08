//
//  ExpenseDisplayL10n.swift
//  BuxMuse
//
//  English keys are stored in SwiftData; localize at display time only.
//

import Foundation

enum ExpenseDisplayL10n {
    /// User-facing label for an expense/income `name` or `merchantName` field.
    static func label(_ stored: String, locale: Locale = BuxInterfaceLocale.currentInterfaceLocale) -> String {
        let trimmed = stored.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return stored }

        if let pick = IncomeSourceQuickPick.matchingStoredLabel(trimmed, locale: locale) {
            return pick.localizedLabel(locale: locale)
        }

        let catalog = BuxCatalogLabel.string(trimmed, locale: locale)
        if catalog != trimmed {
            return catalog
        }

        return trimmed
    }
}

extension ExpenseRecord {
    func localizedDisplayName(locale: Locale = BuxInterfaceLocale.currentInterfaceLocale) -> String {
        ExpenseDisplayL10n.label(name, locale: locale)
    }
}

extension DashboardRecentTransaction {
    func localizedMerchantLabel(locale: Locale = BuxInterfaceLocale.currentInterfaceLocale) -> String {
        ExpenseDisplayL10n.label(merchantName, locale: locale)
    }
}
