//
//  TaxComputeKernel.swift
//  BuxMuse
//
//  Pure tax math primitives — country-agnostic (Phase 0).
//

import Foundation

public enum TaxComputeKernel {

    /// Progressive tax on `amount` using ordered brackets (rate as fraction, e.g. 0.20).
    public static func progressiveTax(on amount: Decimal, brackets: [TaxComputeBracket]) -> Decimal {
        guard amount > 0, !brackets.isEmpty else { return 0 }

        let sorted = brackets.sorted { $0.from < $1.from }
        var remaining = amount
        var cursor = sorted[0].from
        var tax: Decimal = 0

        for bracket in sorted {
            guard remaining > 0 else { break }
            let upper = bracket.to ?? amount
            let spanStart = max(cursor, bracket.from)
            guard upper > spanStart else { continue }
            let taxableSlice = min(remaining, upper - spanStart)
            guard taxableSlice > 0 else { continue }
            tax += taxableSlice * bracket.rate
            remaining -= taxableSlice
            cursor = upper
        }

        if remaining > 0, let last = sorted.last {
            tax += remaining * last.rate
        }

        return max(0, tax)
    }

    public static func taxableAfterAllowance(
        gross: Decimal,
        deductions: Decimal,
        personalAllowance: Decimal?
    ) -> Decimal {
        let base = max(0, gross - deductions)
        guard let allowance = personalAllowance, allowance > 0 else { return base }
        return max(0, base - allowance)
    }

    public static func socialContributions(
        on profit: Decimal,
        rules: [TaxComputeSocialRule]
    ) -> [(rule: TaxComputeSocialRule, amount: Decimal)] {
        guard profit > 0, !rules.isEmpty else { return [] }

        return rules.compactMap { rule in
            var base = profit
            if let lower = rule.lowerProfitBound, base < lower { return nil }
            if let upper = rule.upperProfitBound { base = min(base, upper) }
            if let multiplier = rule.profitRateMultiplier { base *= multiplier }
            var amount = base * rule.rate
            if let cap = rule.annualCap { amount = min(amount, cap) }
            guard amount > 0 else { return nil }
            return (rule, amount)
        }
    }

    public static func advancePayments(
        on gross: Decimal,
        rules: [TaxComputeAdvancePayment]
    ) -> [(rule: TaxComputeAdvancePayment, amount: Decimal)] {
        guard gross > 0, !rules.isEmpty else { return [] }
        return rules.map { rule in
            (rule, gross * rule.rateOnGross)
        }
    }

    /// Marginal bracket rate (fraction) at `amount` — for flat regional invoice estimates.
    public static func marginalRateFraction(
        at amount: Decimal,
        brackets: [TaxComputeBracket]
    ) -> Decimal {
        guard amount >= 0, !brackets.isEmpty else { return 0 }
        let sorted = brackets.sorted { $0.from < $1.from }
        for bracket in sorted {
            let upper = bracket.to ?? Decimal.greatestFiniteMagnitude
            if amount >= bracket.from && amount < upper {
                return bracket.rate
            }
        }
        return sorted.last?.rate ?? 0
    }

    public static func rounded(_ value: Decimal, scale: Int) -> Decimal {
        var result = Decimal()
        var copy = value
        NSDecimalRound(&result, &copy, scale, .bankers)
        return result
    }

    public static func indirectTaxNet(
        invoiceTaxCollected: Decimal,
        receiptTaxPaid: Decimal,
        registered: Bool
    ) -> Decimal {
        guard registered else { return 0 }
        return max(0, invoiceTaxCollected - receiptTaxPaid)
    }

    public static func effectiveRate(totalTax: Decimal, gross: Decimal) -> Decimal {
        guard gross > 0 else { return 0 }
        return totalTax / gross
    }

    public static func marginalRate(
        taxable: Decimal,
        brackets: [TaxComputeBracket]
    ) -> Decimal {
        guard taxable > 0, !brackets.isEmpty else { return 0 }
        let sorted = brackets.sorted { $0.from < $1.from }
        for bracket in sorted.reversed() {
            if taxable >= bracket.from {
                return bracket.rate
            }
        }
        return sorted.first?.rate ?? 0
    }
}
