//
//  FreelanceDisplays.swift
//  BuxMuse
//
//  Read-only display structs for Freelance Hub UI — no business logic.
//

import Foundation

public struct FreelanceHubDisplay: Equatable {
    public var hero: FreelanceHeroDisplay
    public var invoicesSummary: FreelanceInvoiceSummaryDisplay
    public var topClients: [FreelanceClientDisplay]
    public var taxSummary: FreelanceTaxDisplay
    public var cashflow: FreelanceCashflowDisplay
    public var projectsSummary: FreelanceProjectsDisplay
    public var receiptsSummary: FreelanceReceiptsDisplay
    public var deductionOpportunities: [FreelanceDeductionDisplay]
    public var alerts: [FreelanceAlertDisplay]
    public var isEmpty: Bool

    public static let empty = FreelanceHubDisplay(
        hero: .empty,
        invoicesSummary: .empty,
        topClients: [],
        taxSummary: .empty,
        cashflow: .empty,
        projectsSummary: .empty,
        receiptsSummary: .empty,
        deductionOpportunities: [],
        alerts: [],
        isEmpty: true
    )
}

public struct FreelanceHeroDisplay: Equatable {
    public var businessTitle: String
    public var businessSubtitle: String
    public var estimatedTaxFormatted: String
    public var effectiveTaxRatePercent: Int
    public var runwayMonthsFormatted: String
    public var monthlyBurnFormatted: String
    public var totalPaidFormatted: String
    public var totalOutstandingFormatted: String
    public var paidInvoiceCount: Int
    public var outstandingInvoiceCount: Int
    public var timeToMoneyDays: Int?
    public var hasData: Bool

    public static let empty = FreelanceHeroDisplay(
        businessTitle: "Set Up Your Business",
        businessSubtitle: "Freelancer",
        estimatedTaxFormatted: "—",
        effectiveTaxRatePercent: 0,
        runwayMonthsFormatted: "—",
        monthlyBurnFormatted: "—",
        totalPaidFormatted: "—",
        totalOutstandingFormatted: "—",
        paidInvoiceCount: 0,
        outstandingInvoiceCount: 0,
        timeToMoneyDays: nil,
        hasData: false
    )
}

public struct FreelanceInvoiceSummaryDisplay: Equatable {
    public var draftCount: Int
    public var sentCount: Int
    public var paidCount: Int
    public var overdueCount: Int
    public var totalOutstandingFormatted: String
    public var totalPaidFormatted: String
    public var nextDueDate: Date?
    public var nextDueClientName: String?

    public static let empty = FreelanceInvoiceSummaryDisplay(
        draftCount: 0, sentCount: 0, paidCount: 0, overdueCount: 0,
        totalOutstandingFormatted: "—", totalPaidFormatted: "—",
        nextDueDate: nil, nextDueClientName: nil
    )
}

public struct FreelanceClientDisplay: Identifiable, Equatable {
    public var id: UUID
    public var name: String
    public var lifetimeValueFormatted: String
    public var healthScore: Int
    public var stressScore: Int
    public var emotionalProfitabilityScore: Int
    public var isRedFlag: Bool
    public var overdueInvoiceCount: Int
}

public struct FreelanceTaxDisplay: Equatable {
    public var grossIncomeFormatted: String
    public var estimatedTaxFormatted: String
    public var netIncomeFormatted: String
    public var effectiveRatePercent: Int
    public var totalDeductionsFormatted: String
    public var taxDeadlineDays: Int?
    public var taxDeadlineLabel: String
    public var needsTaxProfileSetup: Bool
    public var primaryRulesPreview: String
    public var incomeTypeLabel: String

    public static let empty = FreelanceTaxDisplay(
        grossIncomeFormatted: "—",
        estimatedTaxFormatted: "—",
        netIncomeFormatted: "—",
        effectiveRatePercent: 0,
        totalDeductionsFormatted: "—",
        taxDeadlineDays: nil,
        taxDeadlineLabel: "Configure tax profile",
        needsTaxProfileSetup: true,
        primaryRulesPreview: "",
        incomeTypeLabel: TaxIncomeType.selfEmployed.summaryLabel
    )
}

public struct FreelanceCashflowDisplay: Equatable {
    public var runwayMonthsFormatted: String
    public var survivalIncomeFormatted: String
    public var projectedInflowFormatted: String
    public var burnRateFormatted: String
    public var survivalModeActive: Bool
    public var survivalMessage: String

    public static let empty = FreelanceCashflowDisplay(
        runwayMonthsFormatted: "—",
        survivalIncomeFormatted: "—",
        projectedInflowFormatted: "—",
        burnRateFormatted: "—",
        survivalModeActive: false,
        survivalMessage: "Add invoices and receipts to forecast cashflow."
    )
}

public struct FreelanceProjectsDisplay: Equatable {
    public var activeCount: Int
    public var overrunRiskCount: Int
    public var topProjectName: String?
    public var topProjectProfitFormatted: String?

    public static let empty = FreelanceProjectsDisplay(
        activeCount: 0,
        overrunRiskCount: 0,
        topProjectName: nil,
        topProjectProfitFormatted: nil
    )
}

public struct FreelanceReceiptsDisplay: Equatable {
    public var totalCount: Int
    public var deductibleTotalFormatted: String
    public var thisMonthCount: Int

    public static let empty = FreelanceReceiptsDisplay(
        totalCount: 0,
        deductibleTotalFormatted: "—",
        thisMonthCount: 0
    )
}

public struct FreelanceDeductionDisplay: Identifiable, Equatable {
    public var id: UUID
    public var title: String
    public var description: String
    public var savingsFormatted: String
}

public struct FreelanceAlertDisplay: Identifiable, Equatable {
    public var id: String
    public var title: String
    public var message: String
    public var severity: String
}

/// Shared copy for self-employed tax reference content (JSON and UI).
public enum TaxReferenceCopy {
    public static let disclaimer = "This is informational reference text, not legal advice."
}

// MARK: - Brain snapshots (views read these — no inline engine calls)

public struct TaxSandboxParams: Equatable {
    public var indirectTaxRegistered: Bool
    public var rateIncrease: Double
    public var billableHours: Double
    public var newPurchases: Double

    public static let `default` = TaxSandboxParams(
        indirectTaxRegistered: false,
        rateIncrease: 0,
        billableHours: 0,
        newPurchases: 0
    )
}

public struct TaxSandboxResultDisplay: Equatable {
    public var grossIncomeFormatted: String
    public var deductionsFormatted: String
    public var taxableIncomeFormatted: String
    public var estimatedTaxFormatted: String
    public var netIncomeFormatted: String
    public var indirectTaxFormatted: String
    public var effectiveRatePercent: Int

    public static let empty = TaxSandboxResultDisplay(
        grossIncomeFormatted: "—",
        deductionsFormatted: "—",
        taxableIncomeFormatted: "—",
        estimatedTaxFormatted: "—",
        netIncomeFormatted: "—",
        indirectTaxFormatted: "—",
        effectiveRatePercent: 0
    )
}

public struct TaxSandboxDisplay: Equatable {
    public var currencyCode: String
    public var incomeTypeLabel: String
    public var countryLabel: String
    public var primaryRulesPreview: String
    public var indirectTaxNotes: String
    public var indirectTaxRegistrationLabel: String
    public var isProfileConfigured: Bool
    public var base: TaxSandboxResultDisplay
    public var simulated: TaxSandboxResultDisplay

    public static let empty = TaxSandboxDisplay(
        currencyCode: "USD",
        incomeTypeLabel: TaxIncomeType.selfEmployed.summaryLabel,
        countryLabel: "",
        primaryRulesPreview: "",
        indirectTaxNotes: "",
        indirectTaxRegistrationLabel: "Indirect tax registered",
        isProfileConfigured: false,
        base: .empty,
        simulated: .empty
    )
}

public struct FreelanceDeductionsSnapshotDisplay: Equatable {
    public var totalFormatted: String
    public var opportunities: [FreelanceDeductionDisplay]

    public static let empty = FreelanceDeductionsSnapshotDisplay(
        totalFormatted: "—",
        opportunities: []
    )
}

// MARK: - Self-employed OS snapshots

public struct IncomeTaxDisplay: Equatable {
    public var totalIncomeFormatted: String
    public var deductibleExpensesFormatted: String
    public var taxableIncomeFormatted: String
    public var incomeTaxFormatted: String
    public var selfEmployedTaxFormatted: String
    public var indirectTaxNetFormatted: String
    public var totalEstimatedTaxFormatted: String
    public var effectiveRatePercent: Int
    public var ratesConfigured: Bool

    public static let empty = IncomeTaxDisplay(
        totalIncomeFormatted: "—",
        deductibleExpensesFormatted: "—",
        taxableIncomeFormatted: "—",
        incomeTaxFormatted: "—",
        selfEmployedTaxFormatted: "—",
        indirectTaxNetFormatted: "—",
        totalEstimatedTaxFormatted: "—",
        effectiveRatePercent: 0,
        ratesConfigured: false
    )
}

public struct QuarterlyTaxDisplay: Equatable {
    public var quarterLabel: String
    public var periodRangeLabel: String
    public var incomeTaxFormatted: String
    public var selfEmployedTaxFormatted: String
    public var indirectTaxFormatted: String
    public var totalDueFormatted: String
    public var setAsideFormatted: String
    public var nextPaymentLabel: String
    public var breakdown: IncomeTaxDisplay

    public static let empty = QuarterlyTaxDisplay(
        quarterLabel: "—",
        periodRangeLabel: "—",
        incomeTaxFormatted: "—",
        selfEmployedTaxFormatted: "—",
        indirectTaxFormatted: "—",
        totalDueFormatted: "—",
        setAsideFormatted: "—",
        nextPaymentLabel: "Configure payment schedule",
        breakdown: .empty
    )
}

public struct ComplianceItemDisplay: Identifiable, Equatable {
    public var id: String
    public var question: String
    public var answer: String
    public var severity: String
}

public struct ComplianceDisplay: Equatable {
    public var warnings: [ComplianceItemDisplay]
    public var faq: [ComplianceItemDisplay]

    public static let empty = ComplianceDisplay(warnings: [], faq: [])
}

public struct SelfEmployedDashboardDisplay: Equatable {
    public var incomeFormatted: String
    public var expensesFormatted: String
    public var deductibleFormatted: String
    public var netProfitFormatted: String
    public var estimatedTaxFormatted: String
    public var quarterlyDueFormatted: String
    public var effectiveRatePercent: Int
    public var runwayMonthsFormatted: String
    public var hasData: Bool

    public static let empty = SelfEmployedDashboardDisplay(
        incomeFormatted: "—",
        expensesFormatted: "—",
        deductibleFormatted: "—",
        netProfitFormatted: "—",
        estimatedTaxFormatted: "—",
        quarterlyDueFormatted: "—",
        effectiveRatePercent: 0,
        runwayMonthsFormatted: "—",
        hasData: false
    )
}
