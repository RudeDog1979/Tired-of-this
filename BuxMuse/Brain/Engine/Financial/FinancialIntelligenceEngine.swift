//
//  FinancialIntelligenceEngine.swift
//  BuxMuse
//  Brain/Engine/Financial/
//
//  Contract for the local financial intelligence engine.
//

import Foundation

public protocol FinancialIntelligenceEngine {
    func addTransaction(_ transaction: Transaction)
    func updateTransaction(_ transaction: Transaction)
    func deleteTransaction(id: UUID)
    func allTransactions() -> [Transaction]

    func categorySummaries(for range: DateInterval) -> [CategorySummary]
    func overspendAlerts(for range: DateInterval) -> [OverspendAlert]
    func savingsOpportunities(for range: DateInterval) -> [SavingsOpportunity]
    func merchantClusters() -> [MerchantCluster]
    
    func activeSubscriptions() -> [SubscriptionInfo]
    func subscriptionDetail(for merchantName: String) -> SubscriptionDetail?
}
