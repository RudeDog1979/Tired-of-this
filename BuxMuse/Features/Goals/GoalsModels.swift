//
//  GoalsModels.swift
//  BuxMuse
//  Features/Goals/
//
//  Core data models for the local-first financial goals engine.
//

import Foundation

public struct Goal: Identifiable, Codable, Equatable {
    public let id: UUID
    public var name: String
    public var targetAmount: Decimal
    public var currentAmount: Decimal
    public var deadline: Date?
    public var priority: Int // 1 = High, 2 = Medium, 3 = Low
    public var notes: String?
    public var createdAt: Date
    public var contributions: [GoalContribution]
    
    public init(id: UUID = UUID(), name: String, targetAmount: Decimal, currentAmount: Decimal = 0, deadline: Date? = nil, priority: Int = 2, notes: String? = nil, createdAt: Date = Date(), contributions: [GoalContribution] = []) {
        self.id = id
        self.name = name
        self.targetAmount = targetAmount
        self.currentAmount = currentAmount
        self.deadline = deadline
        self.priority = priority
        self.notes = notes
        self.createdAt = createdAt
        self.contributions = contributions
    }
}

public struct GoalContribution: Identifiable, Codable, Equatable {
    public let id: UUID
    public let amount: Decimal
    public let date: Date
    public let notes: String?
    
    public init(id: UUID = UUID(), amount: Decimal, date: Date = Date(), notes: String? = nil) {
        self.id = id
        self.amount = amount
        self.date = date
        self.notes = notes
    }
}

public struct GoalProjection: Codable, Equatable {
    public let expectedCompletionDate: Date
    public let bestCaseDate: Date
    public let worstCaseDate: Date
    public let recommendedContribution: Decimal
    public let contributionSchedule: String // e.g. "Weekly", "Monthly"
    
    public init(expectedCompletionDate: Date, bestCaseDate: Date, worstCaseDate: Date, recommendedContribution: Decimal, contributionSchedule: String) {
        self.expectedCompletionDate = expectedCompletionDate
        self.bestCaseDate = bestCaseDate
        self.worstCaseDate = worstCaseDate
        self.recommendedContribution = recommendedContribution
        self.contributionSchedule = contributionSchedule
    }
}

public struct GoalHealth: Codable, Equatable {
    public let score: Int // 0-100
    public let riskFactors: [String]
    public let momentum: Double // -1.0 to 1.0
    public let stability: String // "high", "medium", "low"
    public let confidenceLevel: Double // 0.0 to 1.0 (forecast accuracy)
    
    public init(score: Int, riskFactors: [String], momentum: Double, stability: String = "medium", confidenceLevel: Double = 0.8) {
        self.score = score
        self.riskFactors = riskFactors
        self.momentum = momentum
        self.stability = stability
        self.confidenceLevel = confidenceLevel
    }
}

public enum GoalRiskType: String, Codable, CaseIterable {
    case overspendThreat = "overspend_threat"
    case subscriptionThreat = "subscription_threat"
    case irregularExpenseThreat = "irregular_expense_threat"
    case incomeVolatilityThreat = "income_volatility_threat"
    case categorySpikeThreat = "category_spike_threat"
    case missedContribution = "missed_contribution"
    case fallingBehind = "falling_behind"
}

public struct GoalRisk: Codable, Equatable, Identifiable {
    public var id: String { type.rawValue }
    public let type: GoalRiskType
    public let description: String
    public let severity: String // "high", "medium", "low"
    public let suggestedFix: String
    
    public init(type: GoalRiskType, description: String, severity: String, suggestedFix: String) {
        self.type = type
        self.description = description
        self.severity = severity
        self.suggestedFix = suggestedFix
    }
}

public struct GoalSuggestions: Codable, Equatable {
    public let suggestedTargetAmount: Decimal
    public let suggestedDeadline: Date
    public let suggestedPriority: Int
    public let suggestedContributionSchedule: String
    
    public init(suggestedTargetAmount: Decimal, suggestedDeadline: Date, suggestedPriority: Int, suggestedContributionSchedule: String) {
        self.suggestedTargetAmount = suggestedTargetAmount
        self.suggestedDeadline = suggestedDeadline
        self.suggestedPriority = suggestedPriority
        self.suggestedContributionSchedule = suggestedContributionSchedule
    }
}
