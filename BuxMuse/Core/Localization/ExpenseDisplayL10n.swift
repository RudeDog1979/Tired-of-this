//
//  ExpenseDisplayL10n.swift
//  BuxMuse
//
//  English keys are stored in SwiftData; localize at display time only.
//

import Foundation

enum ExpenseDisplayL10n {
    static func note(_ stored: String?, locale: Locale = BuxInterfaceLocale.currentInterfaceLocale) -> String {
        guard let stored else { return "" }
        let trimmed = stored.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        if WalletStatementIntelligence.isWalletImportNote(trimmed) {
            return WalletStatementIntelligence.localizedWalletImportNote(stored: trimmed, locale: locale)
        }
        return trimmed
    }

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

    private static let signedPrefixSeparator = "\u{00A0}"

    /// Ledger sign prefix: outflows −, inflows +.
    static func signedAmount(
        for record: ExpenseRecord,
        currency: CurrencySetting
    ) -> String {
        let magnitude = AppSettingsManager.format(
            amount: abs(record.amountDouble),
            currency: currency
        )
        if record.amountValue > 0 {
            return "+\(signedPrefixSeparator)\(magnitude)"
        }
        if record.amountValue < 0 {
            return "−\(signedPrefixSeparator)\(magnitude)"
        }
        return magnitude
    }

    static func signedOutflow(amount: Double, currency: CurrencySetting) -> String {
        guard amount > 0 else {
            return AppSettingsManager.format(amount: Decimal(amount), currency: currency)
        }
        return "−\(signedPrefixSeparator)\(AppSettingsManager.format(amount: Decimal(amount), currency: currency))"
    }

    static func signedInflow(amount: Double, currency: CurrencySetting) -> String {
        guard amount > 0 else {
            return AppSettingsManager.format(amount: Decimal(amount), currency: currency)
        }
        return "+\(signedPrefixSeparator)\(AppSettingsManager.format(amount: Decimal(amount), currency: currency))"
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
