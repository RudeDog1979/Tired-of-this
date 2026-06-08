//
//  TaxCatalogV2Models.swift
//  BuxMuse
//
//  Structured compute catalog — sidecar to buxmuse_tax.json prose (Phase 0).
//

import Foundation

public struct TaxComputeBracket: Codable, Equatable, Sendable {
    public var from: Decimal
    public var to: Decimal?
    public var rate: Decimal

    public init(from: Decimal, to: Decimal? = nil, rate: Decimal) {
        self.from = from
        self.to = to
        self.rate = rate
    }
}

public struct TaxComputeSocialRule: Codable, Equatable, Sendable {
    public var id: String
    public var labelKey: String
    public var rate: Decimal
    public var profitRateMultiplier: Decimal?
    public var lowerProfitBound: Decimal?
    public var upperProfitBound: Decimal?
    public var annualCap: Decimal?

    public init(
        id: String,
        labelKey: String,
        rate: Decimal,
        profitRateMultiplier: Decimal? = nil,
        lowerProfitBound: Decimal? = nil,
        upperProfitBound: Decimal? = nil,
        annualCap: Decimal? = nil
    ) {
        self.id = id
        self.labelKey = labelKey
        self.rate = rate
        self.profitRateMultiplier = profitRateMultiplier
        self.lowerProfitBound = lowerProfitBound
        self.upperProfitBound = upperProfitBound
        self.annualCap = annualCap
    }
}

public struct TaxComputeDeductionRule: Codable, Equatable, Sendable {
    public var categoryId: String
    public var deductibility: Decimal

    public init(categoryId: String, deductibility: Decimal) {
        self.categoryId = categoryId
        self.deductibility = deductibility
    }
}

public struct TaxComputeRegion: Codable, Equatable, Sendable {
    public var code: String
    public var name: String

    public init(code: String, name: String) {
        self.code = code
        self.name = name
    }
}

public struct TaxComputeIncomeRules: Codable, Equatable, Sendable {
    public var personalAllowance: Decimal?
    public var brackets: [TaxComputeBracket]
    public var socialContributions: [TaxComputeSocialRule]

    public init(
        personalAllowance: Decimal? = nil,
        brackets: [TaxComputeBracket] = [],
        socialContributions: [TaxComputeSocialRule] = []
    ) {
        self.personalAllowance = personalAllowance
        self.brackets = brackets
        self.socialContributions = socialContributions
    }
}

public struct TaxComputeVATRules: Codable, Equatable, Sendable {
    public var standardRate: Decimal
    public var registrationThreshold: Decimal?
    public var filingFrequency: String?

    public init(standardRate: Decimal, registrationThreshold: Decimal? = nil, filingFrequency: String? = nil) {
        self.standardRate = standardRate
        self.registrationThreshold = registrationThreshold
        self.filingFrequency = filingFrequency
    }
}

public struct TaxComputeAdvancePayment: Codable, Equatable, Sendable {
    public var id: String
    public var labelKey: String
    public var rateOnGross: Decimal

    public init(id: String, labelKey: String, rateOnGross: Decimal) {
        self.id = id
        self.labelKey = labelKey
        self.rateOnGross = rateOnGross
    }
}

public struct TaxComputeBlock: Codable, Equatable, Sendable {
    public var selfEmployed: TaxComputeIncomeRules?
    public var employed: TaxComputeIncomeRules?
    public var gig: TaxComputeIncomeRules?
    public var vat: TaxComputeVATRules?
    public var advancePayments: [TaxComputeAdvancePayment]?
    public var deductions: [TaxComputeDeductionRule]?
    public var paymentSchedule: String?
    /// US state sales/use tax rate (decimal fraction) for invoice supplemental lines (Phase L).
    public var salesTaxRate: Decimal?

    public init(
        selfEmployed: TaxComputeIncomeRules? = nil,
        employed: TaxComputeIncomeRules? = nil,
        gig: TaxComputeIncomeRules? = nil,
        vat: TaxComputeVATRules? = nil,
        advancePayments: [TaxComputeAdvancePayment]? = nil,
        deductions: [TaxComputeDeductionRule]? = nil,
        paymentSchedule: String? = nil,
        salesTaxRate: Decimal? = nil
    ) {
        self.selfEmployed = selfEmployed
        self.employed = employed
        self.gig = gig
        self.vat = vat
        self.advancePayments = advancePayments
        self.deductions = deductions
        self.paymentSchedule = paymentSchedule
        self.salesTaxRate = salesTaxRate
    }
}

public struct TaxCountryComputeMeta: Codable, Equatable, Sendable {
    public var isoCode: String
    public var currency: String
    public var taxYear: String
    public var fiscalYearStartMonth: Int
    public var fiscalYearStartDay: Int
    public var coverageTier: TaxCoverageTier
    public var supportedIncomePaths: [TaxEngineIncomePath]
    public var regions: [TaxComputeRegion]?
    public var lastVerified: String

    public init(
        isoCode: String,
        currency: String,
        taxYear: String,
        fiscalYearStartMonth: Int = 1,
        fiscalYearStartDay: Int = 1,
        coverageTier: TaxCoverageTier,
        supportedIncomePaths: [TaxEngineIncomePath],
        regions: [TaxComputeRegion]? = nil,
        lastVerified: String
    ) {
        self.isoCode = isoCode
        self.currency = currency
        self.taxYear = taxYear
        self.fiscalYearStartMonth = fiscalYearStartMonth
        self.fiscalYearStartDay = fiscalYearStartDay
        self.coverageTier = coverageTier
        self.supportedIncomePaths = supportedIncomePaths
        self.regions = regions
        self.lastVerified = lastVerified
    }
}

public struct TaxCountryComputeEntry: Codable, Equatable, Sendable {
    public var meta: TaxCountryComputeMeta
    public var national: TaxComputeBlock
    public var regionalOverrides: [String: TaxComputeBlock]?

    public init(
        meta: TaxCountryComputeMeta,
        national: TaxComputeBlock,
        regionalOverrides: [String: TaxComputeBlock]? = nil
    ) {
        self.meta = meta
        self.national = national
        self.regionalOverrides = regionalOverrides
    }

    /// Full regional replacement — used only where the override is a complete block (legacy).
    public func block(forRegion regionCode: String?) -> TaxComputeBlock {
        guard let regionCode else { return national }
        let code = regionCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !code.isEmpty, let override = regionalOverrides?[code] else {
            return national
        }
        return override
    }

    /// National block with regional overlays — keeps national social when regional social is empty (e.g. Scotland).
    public func mergedBlock(forRegion regionCode: String?) -> TaxComputeBlock {
        guard let regionCode else { return national }
        let code = regionCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !code.isEmpty, let override = regionalOverrides?[code] else {
            return national
        }
        return TaxComputeBlock(
            selfEmployed: mergeIncomeRules(base: national.selfEmployed, overlay: override.selfEmployed),
            employed: mergeIncomeRules(base: national.employed, overlay: override.employed),
            gig: mergeIncomeRules(base: national.gig, overlay: override.gig),
            vat: override.vat ?? national.vat,
            advancePayments: override.advancePayments ?? national.advancePayments,
            deductions: override.deductions ?? national.deductions,
            paymentSchedule: override.paymentSchedule ?? national.paymentSchedule
        )
    }

    public func regionalSelfEmployedRules(forRegion regionCode: String?) -> TaxComputeIncomeRules? {
        guard let regionCode else { return nil }
        let code = regionCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !code.isEmpty else { return nil }
        return regionalOverrides?[code]?.selfEmployed
    }

    public func regionalSalesTaxRate(forRegion regionCode: String?) -> Decimal? {
        guard let regionCode else { return nil }
        let code = regionCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !code.isEmpty else { return nil }
        guard let rate = regionalOverrides?[code]?.salesTaxRate, rate > 0 else { return nil }
        return rate
    }

    private func mergeIncomeRules(
        base: TaxComputeIncomeRules?,
        overlay: TaxComputeIncomeRules?
    ) -> TaxComputeIncomeRules? {
        guard let overlay else { return base }
        var merged = base ?? TaxComputeIncomeRules()
        if !overlay.brackets.isEmpty { merged.brackets = overlay.brackets }
        if let allowance = overlay.personalAllowance { merged.personalAllowance = allowance }
        if !overlay.socialContributions.isEmpty { merged.socialContributions = overlay.socialContributions }
        return merged
    }
}

public struct TaxComputeCatalogPayload: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var updatedAt: String
    public var countries: [String: TaxCountryComputeEntry]

    public init(schemaVersion: Int, updatedAt: String, countries: [String: TaxCountryComputeEntry]) {
        self.schemaVersion = schemaVersion
        self.updatedAt = updatedAt
        self.countries = countries
    }
}
