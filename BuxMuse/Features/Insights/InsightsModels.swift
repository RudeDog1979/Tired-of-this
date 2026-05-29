//
//  InsightsModels.swift
//  BuxMuse
//  Features/Insights/
//
//  Core data models for the local-first financial insights engine.
//

import Foundation

public enum InsightSeverity: String, Codable, CaseIterable, Comparable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    
    public static func < (lhs: InsightSeverity, rhs: InsightSeverity) -> Bool {
        switch (lhs, rhs) {
        case (.low, .medium), (.low, .high), (.medium, .high):
            return true
        default:
            return false
        }
    }
}

public enum InsightCategory: String, Codable, CaseIterable, Identifiable {
    case spending = "spending"
    case subscription = "subscription"
    case category = "category"
    case merchant = "merchant"
    case goal = "goal"
    case pattern = "pattern"
    case predictive = "predictive"
    
    public var id: String { self.rawValue }
}

public struct FinancialInsight: Identifiable, Codable, Equatable {
    public let id: UUID
    public let title: String
    public let value: String           // e.g. "+£45.20", "Urgent Alert", "Low Risk", "Redirection Opportunity"
    public let description: String
    public let fullExplanation: String
    public let severity: InsightSeverity
    public let category: InsightCategory
    public let systemIcon: String
    public let accentColorName: String  // "red", "green", "orange", "blue", "purple"
    public let suggestedActions: [String]
    public let impactMonthly: Decimal
    public let impactYearly: Decimal
    public let affectedGoalId: UUID?
    public let affectedGoalName: String?
    public let dataBehind: String
    public let createdAt: Date
    
    public init(
        id: UUID = UUID(),
        title: String,
        value: String,
        description: String,
        fullExplanation: String,
        severity: InsightSeverity,
        category: InsightCategory,
        systemIcon: String,
        accentColorName: String,
        suggestedActions: [String],
        impactMonthly: Decimal = 0,
        impactYearly: Decimal = 0,
        affectedGoalId: UUID? = nil,
        affectedGoalName: String? = nil,
        dataBehind: String = "",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.value = value
        self.description = description
        self.fullExplanation = fullExplanation
        self.severity = severity
        self.category = category
        self.systemIcon = systemIcon
        self.accentColorName = accentColorName
        self.suggestedActions = suggestedActions
        self.impactMonthly = impactMonthly
        self.impactYearly = impactYearly
        self.affectedGoalId = affectedGoalId
        self.affectedGoalName = affectedGoalName
        self.dataBehind = dataBehind
        self.createdAt = createdAt
    }
}

// MARK: - Display formatting (user currency, 2 decimal places)

public enum InsightMoneyFormat {
    public static var currencyCode: String { AppSettingsManager.preferredCurrencyCode }

    public static func format(_ amount: Decimal, currencyCode: String? = nil) -> String {
        let code = currencyCode ?? self.currencyCode
        return AppSettingsManager.format(
            amount: amount,
            currency: AppSettingsManager.currencySetting(for: code)
        )
    }

    public static func percentChange(from ratio: Decimal) -> Int {
        Int((Double(truncating: (ratio - 1) as NSDecimalNumber)) * 100)
    }
}
