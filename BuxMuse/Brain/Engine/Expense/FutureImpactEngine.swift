//
//  FutureImpactEngine.swift
//  BuxMuse
//
//  Projects 1-year and 5-year costs.
//

import Foundation

struct FutureImpactEngine {
    static func project(
        amount: Decimal,
        currencyCode: String,
        locale: Locale = BuxInterfaceLocale.currentInterfaceLocale
    ) -> (impact1Y: Double, impact5Y: Double, summary: String) {
        let val = abs(NSDecimalNumber(decimal: amount).doubleValue)
        let cost1Y = val * 12
        let cost5Y = val * 60

        let currency = AppSettingsManager.currencySetting(for: currencyCode)
        let display1Y = formatProjectedAmount(cost1Y, currency: currency)
        let display5Y = formatProjectedAmount(cost5Y, currency: currency)

        let summary = BuxLocalizedString.format(
            "If repeated monthly, this costs %@ a year and %@ over 5 years.",
            locale: locale,
            display1Y,
            display5Y
        )
        return (cost1Y, cost5Y, summary)
    }

    private static func formatProjectedAmount(_ amount: Double, currency: CurrencySetting) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency.id
        formatter.locale = Locale(identifier: currency.localeIdentifier)
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount))
            ?? AppSettingsManager.format(amount: Decimal(amount), currency: currency)
    }
}
