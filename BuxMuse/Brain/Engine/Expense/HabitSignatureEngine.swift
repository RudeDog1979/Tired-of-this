//
//  HabitSignatureEngine.swift
//  BuxMuse
//
//  Computes habit signatures based on frequent identical purchases.
//

import Foundation

struct HabitSignatureEngine {
    static func generateSignature(for record: ExpenseRecord, history: [ExpenseRecord]) -> (id: String?, summary: String?) {
        let sameMerchant = history.filter { 
            MerchantLogoEngine.normalizeMerchantName($0.name) == MerchantLogoEngine.normalizeMerchantName(record.name)
        }
        
        let matchingAmounts = sameMerchant.filter { abs(abs($0.amountValue) - abs(record.amountValue)) < 2.0 }
        
        if matchingAmounts.count >= 3 {
            let id = "habit_\(MerchantLogoEngine.normalizeMerchantName(record.name))_amount"
            return (id, "You frequently spend this amount at \(record.name).")
        }
        
        return (nil, nil)
    }
}
