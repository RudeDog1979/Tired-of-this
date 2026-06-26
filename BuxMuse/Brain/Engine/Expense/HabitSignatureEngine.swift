//
//  HabitSignatureEngine.swift
//  BuxMuse
//
//  Computes habit signatures based on frequent identical purchases.
//

import Foundation

struct HabitSignatureEngine {
    static func generateSignature(
        for record: ExpenseRecord,
        history: [ExpenseRecord],
        locale: Locale = BuxInterfaceLocale.currentInterfaceLocale
    ) -> (id: String?, summary: String?) {
        let sameMerchant = history.filter {
            MerchantLogoEngine.normalizeMerchantName($0.name) == MerchantLogoEngine.normalizeMerchantName(record.name)
        }

        let matchingAmounts = sameMerchant.filter { abs(abs($0.amountValue) - abs(record.amountValue)) < 2.0 }

        if matchingAmounts.count >= 3 {
            let id = "habit_\(MerchantLogoEngine.normalizeMerchantName(record.name))_amount"
            return (
                id,
                BuxLocalizedString.format(
                    "You frequently spend this amount at %@.",
                    locale: locale,
                    record.name
                )
            )
        }

        return (nil, nil)
    }
}
