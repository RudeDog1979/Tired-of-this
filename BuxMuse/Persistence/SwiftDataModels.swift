//
//  SwiftDataModels.swift
//  BuxMuse
//
//  Local SwiftData schema — migration-ready, offline-only.
//

import Foundation
import SwiftData

// MARK: - Expenses

@Model
final class ExpenseEntity {
    @Attribute(.unique) var id: UUID
    var name: String
    var amountValue: Decimal
    var currencyCode: String
    var categoryId: UUID?
    var merchantId: UUID?
    var date: Date
    var notes: String?
    var isRecurring: Bool
    var recurrenceType: String?
    var recurrenceConfidence: Double?
    var nextExpectedDate: Date?
    var isSubscriptionLike: Bool
    var isTrial: Bool
    var subscriptionStartDate: Date?
    var trialEndDate: Date?
    var renewalReminderDays: Int?
    var heatZoneBucket: String?
    var emotion: String?
    var contextTag: String?
    var habitSignatureId: String?
    var subscriptionConfidence: Double?
    var microCommitmentType: String?
    var microCommitmentValue: Double?
    var futureImpact1Y: Double?
    var futureImpact5Y: Double?
    var createdAt: Date
    var updatedAt: Date
    /// Legacy engine/dashboard mapping — kept in sync with `categoryId`.
    var categoryRaw: String
    /// Legacy display field — mirrors `name`.
    var merchantName: String

    init(
        id: UUID = UUID(),
        name: String,
        amountValue: Decimal,
        currencyCode: String,
        categoryId: UUID? = nil,
        merchantId: UUID? = nil,
        date: Date,
        notes: String? = nil,
        isRecurring: Bool = false,
        recurrenceType: String? = nil,
        recurrenceConfidence: Double? = nil,
        nextExpectedDate: Date? = nil,
        isSubscriptionLike: Bool = false,
        isTrial: Bool = false,
        subscriptionStartDate: Date? = nil,
        trialEndDate: Date? = nil,
        renewalReminderDays: Int? = nil,
        heatZoneBucket: String? = nil,
        emotion: String? = nil,
        contextTag: String? = nil,
        habitSignatureId: String? = nil,
        subscriptionConfidence: Double? = nil,
        microCommitmentType: String? = nil,
        microCommitmentValue: Double? = nil,
        futureImpact1Y: Double? = nil,
        futureImpact5Y: Double? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        categoryRaw: String,
        merchantName: String
    ) {
        self.id = id
        self.name = name
        self.amountValue = amountValue
        self.currencyCode = currencyCode
        self.categoryId = categoryId
        self.merchantId = merchantId
        self.date = date
        self.notes = notes
        self.isRecurring = isRecurring
        self.recurrenceType = recurrenceType
        self.recurrenceConfidence = recurrenceConfidence
        self.nextExpectedDate = nextExpectedDate
        self.isSubscriptionLike = isSubscriptionLike
        self.isTrial = isTrial
        self.subscriptionStartDate = subscriptionStartDate
        self.trialEndDate = trialEndDate
        self.renewalReminderDays = renewalReminderDays
        self.heatZoneBucket = heatZoneBucket
        self.emotion = emotion
        self.contextTag = contextTag
        self.habitSignatureId = habitSignatureId
        self.subscriptionConfidence = subscriptionConfidence
        self.microCommitmentType = microCommitmentType
        self.microCommitmentValue = microCommitmentValue
        self.futureImpact1Y = futureImpact1Y
        self.futureImpact5Y = futureImpact5Y
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.categoryRaw = categoryRaw
        self.merchantName = merchantName
    }
}

// MARK: - Goals

@Model
final class GoalEntity {
    @Attribute(.unique) var id: UUID
    var name: String
    var targetAmount: Decimal
    var currentAmount: Decimal
    var deadline: Date?
    var priority: Int
    var notes: String?
    var createdAt: Date
    @Relationship(deleteRule: .cascade, inverse: \ContributionEntity.goal)
    var contributions: [ContributionEntity]

    init(
        id: UUID = UUID(),
        name: String,
        targetAmount: Decimal,
        currentAmount: Decimal,
        deadline: Date? = nil,
        priority: Int = 2,
        notes: String? = nil,
        createdAt: Date = Date(),
        contributions: [ContributionEntity] = []
    ) {
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

@Model
final class ContributionEntity {
    @Attribute(.unique) var id: UUID
    var amount: Decimal
    var date: Date
    var notes: String?
    var goal: GoalEntity?

    init(id: UUID = UUID(), amount: Decimal, date: Date = Date(), notes: String? = nil, goal: GoalEntity? = nil) {
        self.id = id
        self.amount = amount
        self.date = date
        self.notes = notes
        self.goal = goal
    }
}

// MARK: - Insights (metadata only)

@Model
final class InsightEntity {
    @Attribute(.unique) var id: UUID
    var payloadJSON: Data
    var createdAt: Date
    var categoryRaw: String

    init(id: UUID = UUID(), payloadJSON: Data, createdAt: Date = Date(), categoryRaw: String) {
        self.id = id
        self.payloadJSON = payloadJSON
        self.createdAt = createdAt
        self.categoryRaw = categoryRaw
    }
}

// MARK: - Merchants & categories

@Model
final class MerchantEntity {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var normalizedName: String
    var name: String
    var logoURL: String?
    var localLogoPath: String?
    var cluster: String?
    var riskScore: Double?
    var isSubscriptionMerchant: Bool
    var lastSeenAt: Date

    init(
        id: UUID = UUID(),
        normalizedName: String,
        name: String,
        logoURL: String? = nil,
        localLogoPath: String? = nil,
        cluster: String? = nil,
        riskScore: Double? = nil,
        isSubscriptionMerchant: Bool = false,
        lastSeenAt: Date = Date()
    ) {
        self.id = id
        self.normalizedName = normalizedName
        self.name = name
        self.logoURL = logoURL
        self.localLogoPath = localLogoPath
        self.cluster = cluster
        self.riskScore = riskScore
        self.isSubscriptionMerchant = isSubscriptionMerchant
        self.lastSeenAt = lastSeenAt
    }
}

@Model
final class CategoryEntity {
    @Attribute(.unique) var id: UUID
    var name: String
    var icon: String
    var color: String
    var isCustom: Bool
    var isSubscriptionCategory: Bool
    var subscriptionFrequency: String?
    var createdAt: Date
    /// Maps built-in categories to `TransactionCategory` for engine compatibility.
    var systemCategoryRaw: String?

    init(
        id: UUID = UUID(),
        name: String,
        icon: String,
        color: String,
        isCustom: Bool = false,
        isSubscriptionCategory: Bool = false,
        subscriptionFrequency: String? = nil,
        createdAt: Date = Date(),
        systemCategoryRaw: String? = nil
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.color = color
        self.isCustom = isCustom
        self.isSubscriptionCategory = isSubscriptionCategory
        self.subscriptionFrequency = subscriptionFrequency
        self.createdAt = createdAt
        self.systemCategoryRaw = systemCategoryRaw
    }
}

// MARK: - Intelligence cache rows

@Model
final class PatternEntity {
    @Attribute(.unique) var id: UUID
    var patternKey: String
    var payloadJSON: Data
    var updatedAt: Date

    init(id: UUID = UUID(), patternKey: String, payloadJSON: Data, updatedAt: Date = Date()) {
        self.id = id
        self.patternKey = patternKey
        self.payloadJSON = payloadJSON
        self.updatedAt = updatedAt
    }
}

@Model
final class BillingCycleEntity {
    @Attribute(.unique) var merchantKey: String
    var payloadJSON: Data
    var updatedAt: Date

    init(merchantKey: String, payloadJSON: Data, updatedAt: Date = Date()) {
        self.merchantKey = merchantKey
        self.payloadJSON = payloadJSON
        self.updatedAt = updatedAt
    }
}

@Model
final class BaselineEntity {
    @Attribute(.unique) var categoryRaw: String
    var baselineValue: Decimal
    var currencyCode: String
    var updatedAt: Date

    init(categoryRaw: String, baselineValue: Decimal, currencyCode: String, updatedAt: Date = Date()) {
        self.categoryRaw = categoryRaw
        self.baselineValue = baselineValue
        self.currencyCode = currencyCode
        self.updatedAt = updatedAt
    }
}

@Model
final class OverspendEntity {
    @Attribute(.unique) var id: UUID
    var categoryRaw: String
    var overspendPercentage: Double
    var payloadJSON: Data
    var recordedAt: Date

    init(id: UUID = UUID(), categoryRaw: String, overspendPercentage: Double, payloadJSON: Data, recordedAt: Date = Date()) {
        self.id = id
        self.categoryRaw = categoryRaw
        self.overspendPercentage = overspendPercentage
        self.payloadJSON = payloadJSON
        self.recordedAt = recordedAt
    }
}

@Model
final class SavingsOpportunityEntity {
    @Attribute(.unique) var id: UUID
    var payloadJSON: Data
    var recordedAt: Date

    init(id: UUID = UUID(), payloadJSON: Data, recordedAt: Date = Date()) {
        self.id = id
        self.payloadJSON = payloadJSON
        self.recordedAt = recordedAt
    }
}

@Model
final class SubscriptionEntity {
    @Attribute(.unique) var merchantKey: String
    var payloadJSON: Data
    var updatedAt: Date

    init(merchantKey: String, payloadJSON: Data, updatedAt: Date = Date()) {
        self.merchantKey = merchantKey
        self.payloadJSON = payloadJSON
        self.updatedAt = updatedAt
    }
}

// MARK: - Preferences & theme

@Model
final class UserPreferencesEntity {
    @Attribute(.unique) var id: String
    var selectedTabRaw: String
    var currencyCode: String
    var isBalanceVisible: Bool
    var activeCategoryPill: String

    init(
        id: String = "default",
        selectedTabRaw: String = "home",
        currencyCode: String = "USD",
        isBalanceVisible: Bool = true,
        activeCategoryPill: String = "Expenses"
    ) {
        self.id = id
        self.selectedTabRaw = selectedTabRaw
        self.currencyCode = currencyCode
        self.isBalanceVisible = isBalanceVisible
        self.activeCategoryPill = activeCategoryPill
    }
}

@Model
final class ThemeEntity {
    @Attribute(.unique) var id: String
    var themeId: String
    var updatedAt: Date

    init(id: String = "default", themeId: String = AppTheme.buxDefault.id, updatedAt: Date = Date()) {
        self.id = id
        self.themeId = themeId
        self.updatedAt = updatedAt
    }
}

// MARK: - Mapping

extension ExpenseEntity {
    func toTransaction() -> Transaction? {
        guard let category = TransactionCategory(rawValue: categoryRaw) else { return nil }
        return Transaction(
            id: id,
            date: date,
            amount: MoneyAmount(value: amountValue, currencyCode: currencyCode),
            merchantName: name.isEmpty ? merchantName : name,
            category: category,
            notes: notes
        )
    }
}

extension GoalEntity {
    func toGoal() -> Goal {
        Goal(
            id: id,
            name: name,
            targetAmount: targetAmount,
            currentAmount: currentAmount,
            deadline: deadline,
            priority: priority,
            notes: notes,
            createdAt: createdAt,
            contributions: contributions.map {
                GoalContribution(id: $0.id, amount: $0.amount, date: $0.date, notes: $0.notes)
            }
        )
    }

    static func from(_ goal: Goal) -> GoalEntity {
        let entity = GoalEntity(
            id: goal.id,
            name: goal.name,
            targetAmount: goal.targetAmount,
            currentAmount: goal.currentAmount,
            deadline: goal.deadline,
            priority: goal.priority,
            notes: goal.notes,
            createdAt: goal.createdAt
        )
        entity.contributions = goal.contributions.map {
            ContributionEntity(id: $0.id, amount: $0.amount, date: $0.date, notes: $0.notes, goal: entity)
        }
        return entity
    }
}

extension InsightEntity {
    @MainActor
    static func from(_ insight: FinancialInsight) -> InsightEntity? {
        guard let data = try? JSONEncoder().encode(insight) else { return nil }
        return InsightEntity(id: insight.id, payloadJSON: data, createdAt: insight.createdAt, categoryRaw: insight.category.rawValue)
    }

    @MainActor
    func toInsight() -> FinancialInsight? {
        try? JSONDecoder().decode(FinancialInsight.self, from: payloadJSON)
    }
}
