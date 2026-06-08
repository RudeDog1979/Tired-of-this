//
//  DashboardSnapshot.swift
//  BuxMuse
//
//  Precomputed, lightweight dashboard read model for 60/120 FPS UI.
//

import Foundation

public struct DashboardRecentTransaction: Identifiable, Equatable {
    public var id: UUID
    public var date: Date
    public var amount: MoneyAmount
    public var merchantName: String
    public var category: TransactionCategory
    public var emotion: String?
    public var emotionSymbol: String?
}

public struct DashboardSnapshot: Equatable {
    public var recentTransactions: [DashboardRecentTransaction]
    public var subscriptionMonthlyTotal: Decimal
    public var subscriptionCount: Int
    public var subscriptionHealthScore: Int
    public var currencyCode: String
    public var totalBalance: Decimal
    public var activeBudgetName: String?
    public var activeBudgetLimit: Decimal
    public var activeBudgetSpent: Decimal
    public var budgetingMode: BudgetingMode
    public var incomePoolThisPeriod: Decimal
    public var envelopeBudgets: [EnvelopeBudgetDisplay]
    public var budgetPeriodStart: Date?
    public var budgetPeriodEnd: Date?
    public var approachingThresholdPercent: Int
    public var workspaceSynergy: WorkspaceSynergySummary

    public static let empty = DashboardSnapshot(
        recentTransactions: [],
        subscriptionMonthlyTotal: 0,
        subscriptionCount: 0,
        subscriptionHealthScore: 100,
        currencyCode: "USD",
        totalBalance: 0,
        activeBudgetName: nil,
        activeBudgetLimit: 0,
        activeBudgetSpent: 0,
        budgetingMode: .simple,
        incomePoolThisPeriod: 0,
        envelopeBudgets: [],
        budgetPeriodStart: nil,
        budgetPeriodEnd: nil,
        approachingThresholdPercent: 80,
        workspaceSynergy: .empty
    )
}

public struct SubscriptionHubSnapshot: Equatable {
    public var subscriptions: [SubscriptionInfo]
    public var totalMonthly: Decimal
    public var healthScore: Int
    public var currencyCode: String

    public static let empty = SubscriptionHubSnapshot(
        subscriptions: [],
        totalMonthly: 0,
        healthScore: 100,
        currencyCode: "USD"
    )
}
