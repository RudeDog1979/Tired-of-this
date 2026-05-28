//
//  TaxStudioModels.swift
//  BuxMuse
//
//  Raw deterministic outputs for Tax Studio engines (not formatted for UI).
//

import Foundation

// MARK: - Context

public struct TaxStudioContext: Equatable {
    public var profile: StudioProfile
    public var taxProfile: StudioTaxProfile
    public var invoices: [StudioInvoice]
    public var receipts: [StudioReceipt]
    public var mileageEntries: [MileageEntry]
    public var countryPreset: TaxInfo?
    public var catalogUpdatedAt: String?
    public var now: Date

    public init(
        profile: StudioProfile,
        taxProfile: StudioTaxProfile,
        invoices: [StudioInvoice],
        receipts: [StudioReceipt],
        mileageEntries: [MileageEntry] = [],
        countryPreset: TaxInfo? = nil,
        catalogUpdatedAt: String? = nil,
        now: Date = Date()
    ) {
        self.profile = profile
        self.taxProfile = taxProfile
        self.invoices = invoices
        self.receipts = receipts
        self.mileageEntries = mileageEntries
        self.countryPreset = countryPreset
        self.catalogUpdatedAt = catalogUpdatedAt
        self.now = now
    }
}

// MARK: - Intelligence

public struct TaxIntelligenceSnapshot: Equatable {
    public var breakdown: IncomeTaxBreakdown
    public var taxSimulation: TaxSimulationResult
    public var quarterly: QuarterlyTaxEstimate
    public var deductibleSavings: Decimal
    public var socialContributions: Decimal
    public var bracketLabel: String
    public var bracketProximityPercent: Int
    public var thresholdWarnings: [String]
}

// MARK: - Forecast

public struct TaxForecastSnapshot: Equatable {
    public var projectedTaxableIncome: Decimal
    public var projectedTaxOwed: Decimal
    public var projectedQuarterlyPayment: Decimal
    public var projectedEffectiveRate: Double
    public var projectedRunwayAfterTaxMonths: Double
    public var vatRegistrationETA: Date?
    public var bracketChangeMonthLabel: String?
    public var monthlyIncomeVelocity: Decimal
    public var monthlyExpenseVelocity: Decimal
}

// MARK: - Health

public enum TaxHealthBand: String, Equatable {
    case green, yellow, red
}

public struct TaxHealthRecommendation: Identifiable, Equatable {
    public var id: String
    public var title: String
    public var detail: String
    public var band: TaxHealthBand
}

public struct TaxHealthSnapshot: Equatable {
    public var score: Int
    public var band: TaxHealthBand
    public var riskLevel: String
    public var recommendations: [TaxHealthRecommendation]
}

// MARK: - Autopilot

public struct TaxAutopilotInsight: Identifiable, Equatable {
    public var id: String
    public var message: String
    public var icon: String
    public var priority: Int
}

// MARK: - Coach

public struct TaxCoachCard: Identifiable, Equatable {
    public var id: String
    public var title: String
    public var body: String
    public var category: String
}

// MARK: - Timeline

public enum TaxTimelineSeverity: String, Equatable {
    case info, warning, critical
}

public struct TaxTimelineEvent: Identifiable, Equatable {
    public var id: String
    public var date: Date
    public var title: String
    public var subtitle: String
    public var severity: TaxTimelineSeverity
    public var deepLink: TaxStudioDeepLink
}

public enum TaxStudioDeepLink: String, Equatable {
    case overview, calculator, forecast, timeline, health, coach, settings
    case taxProfile, receipts, invoices, quarterly
}

// MARK: - Sanity

public struct TaxSanityWarning: Identifiable, Equatable {
    public var id: String
    public var title: String
    public var detail: String
    public var suggestion: String
    public var deepLink: TaxStudioDeepLink
}

public struct TaxSanitySnapshot: Equatable {
    public var warnings: [TaxSanityWarning]
}

// MARK: - Aggregate

public struct TaxStudioSnapshot: Equatable {
    public var intelligence: TaxIntelligenceSnapshot
    public var forecast: TaxForecastSnapshot
    public var health: TaxHealthSnapshot
    public var autopilot: [TaxAutopilotInsight]
    public var coach: [TaxCoachCard]
    public var timeline: [TaxTimelineEvent]
    public var sanity: TaxSanitySnapshot
}
