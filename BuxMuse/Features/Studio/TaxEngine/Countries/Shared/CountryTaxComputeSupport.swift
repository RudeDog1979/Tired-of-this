//
//  CountryTaxComputeSupport.swift
//  BuxMuse
//
//  Shared period filtering + result assembly for country tax modules (Phase 1).
//

import Foundation

enum CountryTaxComputeSupport {

    static func filteredInvoices(
        _ invoices: [StudioInvoice],
        start: Date?,
        end: Date?
    ) -> [StudioInvoice] {
        invoices.filter { inv in
            guard inv.status == .paid || inv.status == .sent || inv.status == .overdue else { return false }
            if let start, inv.issueDate < start { return false }
            if let end, inv.issueDate > end { return false }
            return true
        }
    }

    static func filteredReceipts(
        _ receipts: [StudioReceipt],
        start: Date?,
        end: Date?
    ) -> [StudioReceipt] {
        receipts.filter { r in
            if let start, r.date < start { return false }
            if let end, r.date > end { return false }
            return true
        }
    }

    static func filteredMileage(
        _ entries: [MileageEntry],
        start: Date?,
        end: Date?
    ) -> [MileageEntry] {
        entries.filter { e in
            if let start, e.date < start { return false }
            if let end, e.date > end { return false }
            return true
        }
    }

    static func grossIncome(from invoices: [StudioInvoice]) -> Decimal {
        invoices.reduce(0) { $0 + $1.subtotal }
    }

    static func deductibleExpenses(
        receipts: [StudioReceipt],
        mileageEntries: [MileageEntry],
        mileageRatePerUnit: Decimal,
        deductionCategories: [DeductionCategoryRule] = []
    ) -> Decimal {
        StudioDeductionMath.totalDeductible(
            receipts: receipts,
            mileageEntries: mileageEntries,
            mileageRatePerUnit: mileageRatePerUnit,
            catalogRules: deductionCategories
        )
    }

    static func indirectTaxNet(
        invoices: [StudioInvoice],
        receipts: [StudioReceipt],
        vatRegistered: Bool
    ) -> Decimal {
        let invoiceTax = invoices.reduce(0) { $0 + $1.taxAmount }
        let expenseTax = receipts.reduce(0) { $0 + ($1.vatAmount ?? 0) }
        return TaxComputeKernel.indirectTaxNet(
            invoiceTaxCollected: invoiceTax,
            receiptTaxPaid: expenseTax,
            registered: vatRegistered
        )
    }

    typealias SocialComputeResult = (total: Decimal, lines: [(rule: TaxComputeSocialRule, amount: Decimal)])

    static func resolveIncomeRules(
        block: TaxComputeBlock,
        path: TaxEngineIncomePath
    ) -> TaxComputeIncomeRules? {
        switch path {
        case .selfEmployed: return block.selfEmployed
        case .gig: return block.gig ?? block.selfEmployed
        case .employedHypothetical: return block.employed ?? block.selfEmployed
        case .mixed: return block.selfEmployed
        }
    }

    /// Standard flow: progressive income tax + social + advance + VAT.
    static func compute(
        isoCode: String,
        request: TaxComputationRequest,
        entry: TaxCountryComputeEntry,
        periodStart: Date?,
        periodEnd: Date?,
        socialComputer: ((Decimal, [TaxComputeSocialRule]) -> SocialComputeResult)? = nil,
        source: TaxComputationSource = .countryModule
    ) -> TaxComputationResult? {
        let block = entry.mergedBlock(forRegion: request.regionCode)
        guard let incomeRules = resolveIncomeRules(block: block, path: request.incomePath) else { return nil }

        let invoices = filteredInvoices(request.invoices, start: periodStart, end: periodEnd)
        let receipts = filteredReceipts(request.receipts, start: periodStart, end: periodEnd)
        let mileage = filteredMileage(request.mileageEntries, start: periodStart, end: periodEnd)

        let gross = grossIncome(from: invoices)
        let deductions = deductibleExpenses(
            receipts: receipts,
            mileageEntries: mileage,
            mileageRatePerUnit: request.mileageRatePerUnit,
            deductionCategories: request.taxProfile.deductionCategories
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

        let socialResult: SocialComputeResult
        if let socialComputer {
            socialResult = socialComputer(tradingProfit, incomeRules.socialContributions)
        } else {
            socialResult = defaultSocialContributions(
                on: tradingProfit,
                rules: incomeRules.socialContributions
            )
        }

        let advanceLines = TaxComputeKernel.advancePayments(
            on: gross,
            rules: block.advancePayments ?? []
        )
        let indirectNet = indirectTaxNet(
            invoices: invoices,
            receipts: receipts,
            vatRegistered: request.taxProfile.vatRegistered
        )

        return buildResult(
            countryCode: isoCode,
            regionCode: request.regionCode,
            entry: entry,
            source: source,
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

    static func defaultSocialContributions(
        on profit: Decimal,
        rules: [TaxComputeSocialRule]
    ) -> SocialComputeResult {
        let lines = TaxComputeKernel.socialContributions(on: profit, rules: rules)
        let total = lines.reduce(0) { $0 + $1.amount }
        return (total, lines)
    }

    /// US SECA: 15.3% on 92.35% of net profit, capped at the SS wage base.
    static func usSECA(on profit: Decimal, rules: [TaxComputeSocialRule]) -> SocialComputeResult {
        guard profit > 0,
              let rule = rules.first(where: { $0.id == "seca" }) else {
            return defaultSocialContributions(on: profit, rules: rules)
        }
        let multiplier = rule.profitRateMultiplier ?? 1
        let wageBase = rule.annualCap ?? profit
        let base = min(profit, wageBase) * multiplier
        let amount = base * rule.rate
        guard amount > 0 else { return (0, []) }
        return (amount, [(rule, amount)])
    }

    static func buildResult(
        countryCode: String,
        regionCode: String?,
        entry: TaxCountryComputeEntry,
        source: TaxComputationSource,
        gross: Decimal,
        deductions: Decimal,
        taxableIncome: Decimal,
        incomeTax: Decimal,
        socialTax: Decimal,
        indirectNet: Decimal,
        socialLines: [(rule: TaxComputeSocialRule, amount: Decimal)],
        advanceLines: [(rule: TaxComputeAdvancePayment, amount: Decimal)],
        incomeRules: TaxComputeIncomeRules,
        periodStart: Date?,
        periodEnd: Date?
    ) -> TaxComputationResult {
        let totalDirect = incomeTax + socialTax + advanceLines.reduce(0) { $0 + $1.amount }
        let effective = TaxComputeKernel.effectiveRate(totalTax: totalDirect, gross: gross)
        let marginal = TaxComputeKernel.marginalRate(taxable: taxableIncome, brackets: incomeRules.brackets)

        var lines: [TaxComputationLine] = [
            .init(id: "gross", kind: .grossIncome, amount: gross),
            .init(id: "deductions", kind: .deductibleExpenses, amount: deductions),
            .init(id: "taxable", kind: .taxableIncome, amount: taxableIncome),
            .init(id: "income-tax", kind: .incomeTax, amount: incomeTax),
        ]

        if socialTax > 0 {
            lines.append(.init(id: "social-total", kind: .selfEmployedTax, amount: socialTax))
        }
        for (rule, amount) in socialLines where amount > 0 {
            lines.append(.init(
                id: "social-\(rule.id)",
                kind: .socialContribution,
                labelKey: rule.labelKey,
                amount: amount
            ))
        }
        for (rule, amount) in advanceLines where amount > 0 {
            lines.append(.init(
                id: "advance-\(rule.id)",
                kind: .advancePayment,
                labelKey: rule.labelKey,
                amount: amount
            ))
        }

        lines.append(contentsOf: [
            .init(id: "indirect", kind: .indirectTax, amount: indirectNet),
            .init(id: "total", kind: .totalTax, amount: totalDirect + indirectNet),
            .init(id: "net", kind: .netAfterTax, amount: max(0, gross - totalDirect - indirectNet)),
            .init(id: "effective", kind: .effectiveRate, rate: effective),
            .init(id: "marginal", kind: .marginalRate, rate: marginal),
        ])

        let breakdown = IncomeTaxBreakdown(
            totalIncome: gross,
            deductibleExpenses: deductions,
            taxableIncome: taxableIncome,
            incomeTax: incomeTax,
            selfEmployedTax: socialTax + advanceLines.reduce(0) { $0 + $1.amount },
            indirectTaxNet: indirectNet,
            totalEstimatedTax: totalDirect,
            effectiveRate: Double(truncating: effective as NSDecimalNumber)
        )

        return TaxComputationResult(
            countryCode: countryCode,
            regionCode: regionCode,
            coverageTier: entry.meta.coverageTier,
            source: source,
            catalogUpdatedAt: TaxComputeCatalogStore.shared.payload?.updatedAt,
            taxYear: entry.meta.taxYear,
            lines: lines,
            legacyBreakdown: breakdown
        )
    }
}
