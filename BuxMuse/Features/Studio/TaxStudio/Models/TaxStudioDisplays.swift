//
//  TaxStudioDisplays.swift
//  BuxMuse
//
//  Formatted read models for Tax Studio UI — built by StudioBrain only.
//

import Foundation
import SwiftUI

public enum TaxStudioTab: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case calculator = "Calculator"
    case forecast = "Forecast"
    case timeline = "Timeline"
    case health = "Health"
    case coach = "Coach"
    case settings = "Settings"

    public var id: String { rawValue }

    public var menuLabel: String { rawValue }
}

public struct TaxStudioMetricDisplay: Identifiable, Equatable {
    public var id: String
    public var title: String
    public var value: String
    public var subtitle: String
}

public enum TaxStudioInsightTone: Equatable {
    case positive
    case warning
    case info
}

public struct TaxStudioHeroDisplay: Equatable {
    public var estimatedTax: String
    public var effectiveRate: String
    public var quarterlyDue: String
    public var quarterLabel: String
    public var runway: String
    public var vatSummary: String
    public var countryLabel: String
    public var healthScore: Int
    public var healthBand: TaxHealthBand
    public var healthRiskLevel: String

    public static let empty = TaxStudioHeroDisplay(
        estimatedTax: "—",
        effectiveRate: "—",
        quarterlyDue: "—",
        quarterLabel: "—",
        runway: "—",
        vatSummary: "—",
        countryLabel: "—",
        healthScore: 0,
        healthBand: .yellow,
        healthRiskLevel: "—"
    )
}

public struct TaxStudioAutopilotDisplay: Identifiable, Equatable {
    public var id: String
    public var message: String
    public var icon: String
    public var tone: TaxStudioInsightTone
}

public struct TaxStudioCoachCardDisplay: Identifiable, Equatable {
    public var id: String
    public var title: String
    public var body: String
    public var category: String
}

public struct TaxStudioTimelineEventDisplay: Identifiable, Equatable {
    public var id: String
    public var date: Date
    public var dateLabel: String
    public var title: String
    public var subtitle: String
    public var severity: TaxTimelineSeverity
    public var accent: Color
    public var isNextHighlight: Bool
}

public struct TaxStudioSanityDisplay: Identifiable, Equatable {
    public var id: String
    public var title: String
    public var detail: String
    public var suggestion: String
}

public struct TaxStudioHealthFactorDisplay: Identifiable, Equatable {
    public var id: String
    public var title: String
    public var valueLabel: String
    public var progress: Double
}

public struct TaxStudioHealthDisplay: Equatable {
    public var score: Int
    public var band: TaxHealthBand
    public var riskLevel: String
    public var scoreColorName: String
    public var factors: [TaxStudioHealthFactorDisplay]
    public var recommendations: [TaxStudioCoachCardDisplay]

    public static let empty = TaxStudioHealthDisplay(
        score: 0,
        band: .yellow,
        riskLevel: "—",
        scoreColorName: "gray",
        factors: [],
        recommendations: []
    )
}

public struct TaxStudioDisplay: Equatable {
    public var catalogUpdatedLabel: String
    public var showMonthlyBanner: Bool
    public var hero: TaxStudioHeroDisplay
    public var metrics: [TaxStudioMetricDisplay]
    public var health: TaxStudioHealthDisplay
    public var autopilot: [TaxStudioAutopilotDisplay]
    public var coachCards: [TaxStudioCoachCardDisplay]
    public var timeline: [TaxStudioTimelineEventDisplay]
    public var sanity: [TaxStudioSanityDisplay]
    public var forecastRows: [TaxStudioMetricDisplay]
    public var taxPressureSparkline: [Double]
    public var taxPressureSparklineLabel: String
    public var forecastMonthlyBars: [TaxStudioForecastBar]
    public var bracketLabel: String
    public var thresholdWarnings: [String]
    public var incomeTaxDisplay: IncomeTaxDisplay
    public var quarterlyDisplay: QuarterlyTaxDisplay

    public static let empty = TaxStudioDisplay(
        catalogUpdatedLabel: "—",
        showMonthlyBanner: true,
        hero: .empty,
        metrics: [],
        health: .empty,
        autopilot: [],
        coachCards: [],
        timeline: [],
        sanity: [],
        forecastRows: [],
        taxPressureSparkline: [],
        taxPressureSparklineLabel: "—",
        forecastMonthlyBars: [],
        bracketLabel: "—",
        thresholdWarnings: [],
        incomeTaxDisplay: .empty,
        quarterlyDisplay: .empty
    )
}
