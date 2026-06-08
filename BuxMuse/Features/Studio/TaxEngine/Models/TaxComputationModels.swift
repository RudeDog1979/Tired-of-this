//
//  TaxComputationModels.swift
//  BuxMuse
//
//  Tax Engine v2 request/result types (Phase 0).
//

import Foundation

public enum TaxComputationPeriod: Equatable, Sendable {
    case allTime
    case fiscalYearToDate(reference: Date)
    case calendarQuarter(reference: Date)
    case fiscalQuarter(reference: Date)
    case custom(start: Date, end: Date)
    case hypotheticalAnnual
}

public struct TaxComputationRequest: Equatable, Sendable {
    public var profile: StudioProfile
    public var taxProfile: StudioTaxProfile
    public var invoices: [StudioInvoice]
    public var receipts: [StudioReceipt]
    public var mileageEntries: [MileageEntry]
    public var mileageRatePerUnit: Decimal
    public var incomePath: TaxEngineIncomePath
    public var period: TaxComputationPeriod
    public var hypotheticalEmployedGross: Decimal?
    public var locale: Locale
    public var now: Date

    public init(
        profile: StudioProfile,
        taxProfile: StudioTaxProfile,
        invoices: [StudioInvoice],
        receipts: [StudioReceipt],
        mileageEntries: [MileageEntry] = [],
        mileageRatePerUnit: Decimal = 0,
        incomePath: TaxEngineIncomePath = .selfEmployed,
        period: TaxComputationPeriod = .allTime,
        hypotheticalEmployedGross: Decimal? = nil,
        locale: Locale = BuxInterfaceLocale.currentInterfaceLocale,
        now: Date = Date()
    ) {
        self.profile = profile
        self.taxProfile = taxProfile
        self.invoices = invoices
        self.receipts = receipts
        self.mileageEntries = mileageEntries
        self.mileageRatePerUnit = mileageRatePerUnit
        self.incomePath = incomePath
        self.period = period
        self.hypotheticalEmployedGross = hypotheticalEmployedGross
        self.locale = locale
        self.now = now
    }

    public var countryCode: String {
        TaxManager.normalizeCountryCode(
            taxProfile.selectedTaxCountry ?? profile.countryCode
        )
    }

    public var regionCode: String? {
        let fromProfile = taxProfile.regionCode?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let fromProfile, !fromProfile.isEmpty { return fromProfile.uppercased() }
        let fromStudio = profile.regionCode?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let fromStudio, !fromStudio.isEmpty { return fromStudio.uppercased() }
        return nil
    }
}

public enum TaxComputationLineKind: String, Codable, Sendable {
    case grossIncome
    case deductibleExpenses
    case taxableIncome
    case incomeTax
    case selfEmployedTax
    case socialContribution
    case advancePayment
    case indirectTax
    case totalTax
    case netAfterTax
    case effectiveRate
    case marginalRate

    public var catalogLabelKey: String {
        switch self {
        case .grossIncome: return "Gross income"
        case .deductibleExpenses: return "Deductible expenses"
        case .taxableIncome: return "Taxable income"
        case .incomeTax: return "Income tax"
        case .selfEmployedTax: return "Self-employed tax"
        case .socialContribution: return "Social contributions"
        case .advancePayment: return "Advance tax payment"
        case .indirectTax: return "Indirect tax (VAT/GST)"
        case .totalTax: return "Total estimated tax"
        case .netAfterTax: return "Net after tax"
        case .effectiveRate: return "Effective tax rate"
        case .marginalRate: return "Marginal tax rate"
        }
    }
}

public struct TaxComputationLine: Equatable, Sendable, Identifiable {
    public var id: String
    public var kind: TaxComputationLineKind
    public var labelKey: String
    public var amount: Decimal?
    public var rate: Decimal?

    public init(
        id: String,
        kind: TaxComputationLineKind,
        labelKey: String? = nil,
        amount: Decimal? = nil,
        rate: Decimal? = nil
    ) {
        self.id = id
        self.kind = kind
        self.labelKey = labelKey ?? kind.catalogLabelKey
        self.amount = amount
        self.rate = rate
    }
}

public enum TaxComputationSource: String, Sendable {
    case countryModule
    case structuredCatalog
    case legacyManualRates
}

public struct TaxComputationResult: Equatable, Sendable {
    public var countryCode: String
    public var regionCode: String?
    public var coverageTier: TaxCoverageTier
    public var source: TaxComputationSource
    public var catalogUpdatedAt: String?
    public var taxYear: String?
    public var lines: [TaxComputationLine]
    public var legacyBreakdown: IncomeTaxBreakdown

    public var grossIncome: Decimal { lineAmount(.grossIncome) }
    public var deductibleExpenses: Decimal { lineAmount(.deductibleExpenses) }
    public var taxableIncome: Decimal { lineAmount(.taxableIncome) }
    public var totalTax: Decimal { lineAmount(.totalTax) }
    public var netAfterTax: Decimal { lineAmount(.netAfterTax) }

    public init(
        countryCode: String,
        regionCode: String?,
        coverageTier: TaxCoverageTier,
        source: TaxComputationSource,
        catalogUpdatedAt: String? = nil,
        taxYear: String? = nil,
        lines: [TaxComputationLine],
        legacyBreakdown: IncomeTaxBreakdown
    ) {
        self.countryCode = countryCode
        self.regionCode = regionCode
        self.coverageTier = coverageTier
        self.source = source
        self.catalogUpdatedAt = catalogUpdatedAt
        self.taxYear = taxYear
        self.lines = lines
        self.legacyBreakdown = legacyBreakdown
    }

    private func lineAmount(_ kind: TaxComputationLineKind) -> Decimal {
        lines.first(where: { $0.kind == kind })?.amount ?? 0
    }
}
