//
//  USTaxModule.swift
//  BuxMuse
//
//  US federal + state — progressive income tax + SECA (self-employed only).
//

import Foundation

public struct USTaxModule: CountryTaxModule {
    public let isoCode = "US"

    public func compute(
        request: TaxComputationRequest,
        entry: TaxCountryComputeEntry,
        periodStart: Date?,
        periodEnd: Date?
    ) -> TaxComputationResult? {
        guard let federalRules = entry.national.selfEmployed else { return nil }

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

        let incomeRules = CountryTaxComputeSupport.resolveIncomeRules(
            block: entry.mergedBlock(forRegion: request.regionCode),
            path: request.incomePath
        ) ?? federalRules

        let taxableIncome = TaxComputeKernel.taxableAfterAllowance(
            gross: gross,
            deductions: deductions,
            personalAllowance: incomeRules.personalAllowance
        )

        let federalTax = TaxComputeKernel.progressiveTax(
            on: taxableIncome,
            brackets: federalRules.brackets
        )

        var stateTax: Decimal = 0
        if let stateRules = entry.regionalSelfEmployedRules(forRegion: request.regionCode),
           !stateRules.brackets.isEmpty {
            stateTax = TaxComputeKernel.progressiveTax(
                on: taxableIncome,
                brackets: stateRules.brackets
            )
        }

        let incomeTax = federalTax + stateTax

        let socialResult: CountryTaxComputeSupport.SocialComputeResult
        if request.incomePath == .employedHypothetical {
            socialResult = (0, [])
        } else {
            socialResult = CountryTaxComputeSupport.usSECA(
                on: max(0, gross - deductions),
                rules: federalRules.socialContributions
            )
        }

        let block = entry.national
        let advanceLines = TaxComputeKernel.advancePayments(
            on: gross,
            rules: block.advancePayments ?? []
        )
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
            socialTax: socialResult.total,
            indirectNet: indirectNet,
            socialLines: socialResult.lines,
            advanceLines: advanceLines,
            incomeRules: incomeRules,
            periodStart: periodStart,
            periodEnd: periodEnd
        )
    }
}
