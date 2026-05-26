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

    public static let empty = FreelanceTaxDisplay(
        grossIncomeFormatted: "—",
        estimatedTaxFormatted: "—",
        netIncomeFormatted: "—",
        effectiveRatePercent: 0,
        totalDeductionsFormatted: "—",
        taxDeadlineDays: nil,
        taxDeadlineLabel: "Configure tax profile",
        needsTaxProfileSetup: true
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
