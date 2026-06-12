//
//  MicroCommitmentEngine.swift
//  BuxMuse
//
//  Generates micro-commitments for an expense.
//

import Foundation

struct MicroCommitmentEngine {
    static func generate(for record: ExpenseRecord) -> (type: String, value: Double, summary: String)? {
        let val = abs(NSDecimalNumber(decimal: record.amountValue).doubleValue)
        if val > 50 {
            return ("watch", val, "Commit to delaying your next large purchase in this category by 48 hours.")
        } else if val > 10 {
            return ("cap", val * 0.9, "Try capping your next visit here to 10% less.")
        }
        return nil
    }
}
