//
//  BrainModels.swift
//  BuxMuse
//  Brain/Models/
//
//  Data models for the BuxMuse Local Intelligence Engine.
//

import Foundation

public struct MoneyAmount: Codable, Equatable {
    public let value: Decimal
    public let currencyCode: String
    
    public init(value: Decimal, currencyCode: String) {
        self.value = value
        self.currencyCode = currencyCode
    }
}

public enum TransactionCategory: String, Codable, CaseIterable, Identifiable {
    case groceries
    case restaurants
    case transport
    case subscriptions
    case housing
    case entertainment
    case shopping
    case health
    case utilities
    case travel
    case education
    case personal
    case income
    case other
    
    public var id: String { self.rawValue }
    
    public var displayName: String {
        switch self {
        case .groceries: return "Groceries"
        case .restaurants: return "Restaurants"
        case .transport: return "Transport"
        case .subscriptions: return "Subscriptions"
        case .housing: return "Housing"
        case .entertainment: return "Entertainment"
        case .shopping: return "Shopping"
        case .health: return "Health"
        case .utilities: return "Utilities"
        case .travel: return "Travel"
        case .education: return "Education"
        case .personal: return "Personal"
        case .income: return "Income"
        case .other: return "Other"
        }
    }
}

public struct Transaction: Identifiable, Codable, Equatable {
    public let id: UUID
    public let date: Date
    public let amount: MoneyAmount   // negative = expense, positive = income
    public let merchantName: String
    public let category: TransactionCategory
    public let notes: String?
    public let emotion: String?
    public let isSubscriptionLike: Bool
    public let isTrial: Bool
    public let nextExpectedDate: Date?
    public let subscriptionStartDate: Date?
    public let trialEndDate: Date?
    public let hustleId: UUID?
    public let paymentMethod: String?
    /// Barter / trade exchange flag — no money changes hands.
    public let isBarterExchange: Bool
    /// What was given in the barter (goods or services).
    public let barterGoodsGiven: String?
    /// What was received in the barter (goods or services).
    public let barterGoodsReceived: String?
    /// Manually estimated monetary value of the barter in the user's primary currency.
    public let barterEstimatedValue: Decimal?
    public let bridgeGroupId: UUID?
    public let bridgeKind: String?
    public let bridgeRole: String?
    public let bridgeSharePercent: Double?
    public let bridgePeerExpenseId: UUID?
    public let bridgeCounterpartyHustleId: UUID?

    public init(
        id: UUID = UUID(),
        date: Date,
        amount: MoneyAmount,
        merchantName: String,
        category: TransactionCategory,
        notes: String? = nil,
        emotion: String? = nil,
        isSubscriptionLike: Bool = false,
        isTrial: Bool = false,
        nextExpectedDate: Date? = nil,
        subscriptionStartDate: Date? = nil,
        trialEndDate: Date? = nil,
        hustleId: UUID? = nil,
        paymentMethod: String? = nil,
        isBarterExchange: Bool = false,
        barterGoodsGiven: String? = nil,
        barterGoodsReceived: String? = nil,
        barterEstimatedValue: Decimal? = nil,
        bridgeGroupId: UUID? = nil,
        bridgeKind: String? = nil,
        bridgeRole: String? = nil,
        bridgeSharePercent: Double? = nil,
        bridgePeerExpenseId: UUID? = nil,
        bridgeCounterpartyHustleId: UUID? = nil
    ) {
        self.id = id
        self.date = date
        self.amount = amount
        self.merchantName = merchantName
        self.category = category
        self.notes = notes
        self.emotion = emotion
        self.isSubscriptionLike = isSubscriptionLike
        self.isTrial = isTrial
        self.nextExpectedDate = nextExpectedDate
        self.subscriptionStartDate = subscriptionStartDate
        self.trialEndDate = trialEndDate
        self.hustleId = hustleId
        self.paymentMethod = paymentMethod
        self.isBarterExchange = isBarterExchange
        self.barterGoodsGiven = barterGoodsGiven
        self.barterGoodsReceived = barterGoodsReceived
        self.barterEstimatedValue = barterEstimatedValue
        self.bridgeGroupId = bridgeGroupId
        self.bridgeKind = bridgeKind
        self.bridgeRole = bridgeRole
        self.bridgeSharePercent = bridgeSharePercent
        self.bridgePeerExpenseId = bridgePeerExpenseId
        self.bridgeCounterpartyHustleId = bridgeCounterpartyHustleId
    }
}

public struct MerchantCluster: Identifiable, Equatable {
    public let id: UUID
    public let canonicalName: String
    public let merchantNames: [String]
    
    public init(id: UUID = UUID(), canonicalName: String, merchantNames: [String]) {
        self.id = id
        self.canonicalName = canonicalName
        self.merchantNames = merchantNames
    }
}

public struct CategorySummary: Equatable {
    public let category: TransactionCategory
    public let total: MoneyAmount
    public let averagePerPeriod: MoneyAmount?
    public let trendPercentage: Double?
    
    public init(category: TransactionCategory, total: MoneyAmount, averagePerPeriod: MoneyAmount? = nil, trendPercentage: Double? = nil) {
        self.category = category
        self.total = total
        self.averagePerPeriod = averagePerPeriod
        self.trendPercentage = trendPercentage
    }
}

public struct OverspendAlert: Equatable {
    public let category: TransactionCategory
    public let currentTotal: MoneyAmount
    public let baselineTotal: MoneyAmount
    public let overspendPercentage: Double
    
    public init(category: TransactionCategory, currentTotal: MoneyAmount, baselineTotal: MoneyAmount, overspendPercentage: Double) {
        self.category = category
        self.currentTotal = currentTotal
        self.baselineTotal = baselineTotal
        self.overspendPercentage = overspendPercentage
    }
}

public struct SavingsOpportunity: Equatable {
    public let description: String
    public let category: TransactionCategory?
    public let estimatedMonthlySavings: MoneyAmount?
    
    public init(description: String, category: TransactionCategory?, estimatedMonthlySavings: MoneyAmount?) {
        self.description = description
        self.category = category
        self.estimatedMonthlySavings = estimatedMonthlySavings
    }
}

// MARK: - Subscription Models

public enum SubscriptionBillingCycle: String, Codable, CaseIterable, Identifiable {
    case weekly
    case monthly
    case quarterly
    case semiAnnual = "semi-annual"
    case yearly
    case day28 = "28-day"
    case day30 = "30-day"
    case day31 = "31-day"
    case irregular
    
    public var id: String { self.rawValue }
    
    public var displayName: String {
        switch self {
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .quarterly: return "Quarterly"
        case .semiAnnual: return "Semi-Annual"
        case .yearly: return "Yearly"
        case .day28: return "28-day"
        case .day30: return "30-day"
        case .day31: return "31-day"
        case .irregular: return "Irregular Pattern"
        }
    }
}

public enum SubscriptionRiskType: String, Codable, CaseIterable, Identifiable {
    case priceHike = "price_hike"
    case irregularCycle = "irregular_cycle"
    case doubleCharge = "double_charge"
    case nameChange = "name_change"
    case categoryChange = "category_change"
    case currencyChange = "currency_change"
    case cycleChange = "cycle_change"
    case ghostBilling = "ghost_billing"
    case zombieSubscription = "zombie_subscription"
    case shadowSubscription = "shadow_subscription"
    case overlappingFeatures = "overlapping_features"
    
    public var id: String { self.rawValue }
    
    public var displayName: String {
        switch self {
        case .priceHike: return "Price Hike"
        case .irregularCycle: return "Irregular Cycle"
        case .doubleCharge: return "Double Charge"
        case .nameChange: return "Merchant Name Change"
        case .categoryChange: return "Category Modification"
        case .currencyChange: return "Foreign Currency"
        case .cycleChange: return "Billing Cycle Change"
        case .ghostBilling: return "Ghost Billing (Unused)"
        case .zombieSubscription: return "Zombie (Inactive)"
        case .shadowSubscription: return "Shadow Subscription"
        case .overlappingFeatures: return "Overlapping Services"
        }
    }
}

public struct SubscriptionRisk: Codable, Equatable, Identifiable {
    public var id: String { type.rawValue }
    public let type: SubscriptionRiskType
    public let description: String
    public let severity: String // "high", "medium", "low"
    
    public init(type: SubscriptionRiskType, description: String, severity: String) {
        self.type = type
        self.description = description
        self.severity = severity
    }
}

public struct SubscriptionInfo: Identifiable, Codable, Equatable {
    public var id: String { merchantName }
    public let merchantName: String
    public let cost: MoneyAmount
    public let billingCycle: SubscriptionBillingCycle
    public let nextRenewalDate: Date
    public let category: TransactionCategory
    public let risks: [SubscriptionRisk]
    
    public init(merchantName: String, cost: MoneyAmount, billingCycle: SubscriptionBillingCycle, nextRenewalDate: Date, category: TransactionCategory, risks: [SubscriptionRisk] = []) {
        self.merchantName = merchantName
        self.cost = cost
        self.billingCycle = billingCycle
        self.nextRenewalDate = nextRenewalDate
        self.category = category
        self.risks = risks
    }
}

public struct SubscriptionDetail: Codable, Equatable, Identifiable {
    public var id: String { info.merchantName }
    public let info: SubscriptionInfo
    public let history: [Transaction]
    public let priceHistoryGraph: [Decimal]
    public let cancellationSteps: String
    public let budgetImpactMonthly: MoneyAmount
    public let budgetImpactYearly: MoneyAmount
    public let costChangePercentage: Double // change over last 6 months
    public let usageInsights: String
    public let alternatives: [String]
    
    public init(info: SubscriptionInfo, history: [Transaction], priceHistoryGraph: [Decimal], cancellationSteps: String, budgetImpactMonthly: MoneyAmount, budgetImpactYearly: MoneyAmount, costChangePercentage: Double, usageInsights: String, alternatives: [String]) {
        self.info = info
        self.history = history
        self.priceHistoryGraph = priceHistoryGraph
        self.cancellationSteps = cancellationSteps
        self.budgetImpactMonthly = budgetImpactMonthly
        self.budgetImpactYearly = budgetImpactYearly
        self.costChangePercentage = costChangePercentage
        self.usageInsights = usageInsights
        self.alternatives = alternatives
    }
}

// MARK: - Formatting Extensions
extension MoneyAmount {
    /// Formats MoneyAmount using the AppSettingsManager settings
    public func formatted(with manager: AppSettingsManager) -> String {
        return manager.format(self.value)
    }
}
