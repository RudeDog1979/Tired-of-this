//
//  GBTaxModule.swift
//  BuxMuse
//
//  UK self-employed / employed hypothetical — progressive income tax + NI (Phase 1+4).
//

import Foundation

public struct GBTaxModule: CountryTaxModule {
    public let isoCode = "GB"

    public func compute(
        request: TaxComputationRequest,
        entry: TaxCountryComputeEntry,
        periodStart: Date?,
        periodEnd: Date?
    ) -> TaxComputationResult? {
        let block = entry.mergedBlock(forRegion: request.regionCode)
        guard let incomeRules = CountryTaxComputeSupport.resolveIncomeRules(
            block: block,
            path: request.incomePath
        ) else { return nil }

        let invoices = CountryTaxComputeSupport.filteredInvoices(
            request.invoices, start: periodStart, end: periodEnd
        )
        let receipts = CountryTaxComputeSupport.filteredReceipts(
            request.receipts, start: periodStart, end: periodEnd
        )
        let mileage = CountryTaxComputeSupport.filteredMileage(
            request.mileageEntries, start: periodStart, end: periodEnd
        )

        let gross = CountryTaxComputeSupport.grossIncome(from: invoices)
        let deductions = CountryTaxComputeSupport.deductibleExpenses(
            receipts: receipts,
            mileageEntries: mileage,
            mileageRatePerUnit: request.mileageRatePerUnit
        )
        let tradingProfit = max(0, gross - deductions)

        let taxableIncome = TaxComputeKernel.taxableAfterAllowance(
            gross: gross,
            deductions: deductions,
            personalAllowance: incomeRules.personalAllowance
        )
        let incomeTax = TaxComputeKernel.progressiveTax(
            on: taxableIncome,
            brackets: incomeRules.brackets
        )

        let (socialTax, socialLines) = gbNationalInsurance(
            on: tradingProfit,
            rules: incomeRules.socialContributions
        )

        let advanceLines = (block.advancePayments ?? []).map { rule in
            (rule, gross * rule.rateOnGross)
        }
        let indirectNet = CountryTaxComputeSupport.indirectTaxNet(
            invoices: invoices,
            receipts: receipts,
            vatRegistered: request.taxProfile.vatRegistered
        )

        return CountryTaxComputeSupport.buildResult(
            countryCode: isoCode,
            regionCode: request.regionCode,
            entry: entry,
            source: .countryModule,
            gross: gross,
            deductions: deductions,
            taxableIncome: taxableIncome,
            incomeTax: incomeTax,
            socialTax: socialTax,
            indirectNet: indirectNet,
            socialLines: socialLines,
            advanceLines: advanceLines,
            incomeRules: incomeRules,
            periodStart: periodStart,
            periodEnd: periodEnd
        )
    }

    // MARK: - UK NI (Class 1 employed + Class 4 self-employed band slices)

    private func gbNationalInsurance(
        on profit: Decimal,
        rules: [TaxComputeSocialRule]
    ) -> (Decimal, [(rule: TaxComputeSocialRule, amount: Decimal)]) {
        guard profit > 0, !rules.isEmpty else { return (0, []) }

        var lines: [(rule: TaxComputeSocialRule, amount: Decimal)] = []
        var total: Decimal = 0

        for rule in rules {
            let amount: Decimal?
            switch rule.id {
            case "class4-main", "class1-main":
                amount = gbNISlice(
                    profit: profit,
                    lower: rule.lowerProfitBound ?? 12_570,
                    upper: rule.upperProfitBound ?? 50_270,
                    rate: rule.rate
                )
            case "class4-addl", "class1-addl":
                amount = gbNIAbove(
                    profit: profit,
                    threshold: rule.lowerProfitBound ?? 50_270,
                    rate: rule.rate
                )
            default:
                let computed = TaxComputeKernel.socialContributions(on: profit, rules: [rule])
                amount = computed.first?.amount
            }

            guard let amount, amount > 0 else { continue }
            lines.append((rule, amount))
            total += amount
        }

        return (total, lines)
    }

    private func gbNISlice(
        profit: Decimal,
        lower: Decimal,
        upper: Decimal,
        rate: Decimal
    ) -> Decimal? {
        guard profit > lower else { return nil }
        let band = min(profit, upper) - lower
        guard band > 0 else { return nil }
        return band * rate
    }

    private func gbNIAbove(
        profit: Decimal,
        threshold: Decimal,
        rate: Decimal
    ) -> Decimal? {
        guard profit > threshold else { return nil }
        return (profit - threshold) * rate
    }
}
