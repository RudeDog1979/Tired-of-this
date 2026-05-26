//
//  InsightsEngine.swift
//  BuxMuse
//  Features/Insights/
//
//  Central orchestrator for the local-first financial insights engine.
//

import Foundation
import Combine

public final class InsightsEngine: ObservableObject {
    @Published public private(set) var insights: [FinancialInsight] = []
    
    private let spendingEngine = SpendingInsightsEngine()
    private let subscriptionEngine = SubscriptionInsightsEngine()
    private let categoryEngine = CategoryInsightsEngine()
    private let merchantEngine = MerchantInsightsEngine()
    private let goalEngine = GoalInsightsEngine()
    private let patternEngine = PatternInsightsEngine()
    private let predictiveEngine = PredictiveInsightsEngine()
    
    private let rankingEngine = InsightsRankingEngine()
    private let timingEngine = InsightsTimingEngine()
    
    private let calculationQueue = DispatchQueue(label: "com.buxmuse.insights.calculations", qos: .userInitiated)
    
    public init() {}
    
    public func recalculateAllInsightsAsync(
        transactions: [Transaction],
        subscriptions: [SubscriptionInfo],
        goals: [Goal],
        goalsViewModel: GoalsViewModel
    ) {
        // Detect XCTest unit testing environment to run synchronously
        let isTesting = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil || NSClassFromString("XCTest") != nil
        
        if isTesting {
            self.performRecalculation(transactions: transactions, subscriptions: subscriptions, goals: goals, goalsViewModel: goalsViewModel)
        } else {
            calculationQueue.async { [weak self] in
                self?.performRecalculation(transactions: transactions, subscriptions: subscriptions, goals: goals, goalsViewModel: goalsViewModel)
            }
        }
    }
    
    private func performRecalculation(
        transactions: [Transaction],
        subscriptions: [SubscriptionInfo],
        goals: [Goal],
        goalsViewModel: GoalsViewModel
    ) {
        var generated: [FinancialInsight] = []
        
        // 1. Core sub-engines sweeps
        generated.append(contentsOf: spendingEngine.generateInsights(transactions: transactions))
        generated.append(contentsOf: subscriptionEngine.generateInsights(subscriptions: subscriptions, goals: goals))
        generated.append(contentsOf: categoryEngine.generateInsights(transactions: transactions))
        generated.append(contentsOf: merchantEngine.generateInsights(transactions: transactions))
        generated.append(contentsOf: goalEngine.generateInsights(goals: goals, goalsViewModel: goalsViewModel))
        generated.append(contentsOf: patternEngine.generateInsights(transactions: transactions))
        generated.append(contentsOf: predictiveEngine.generateInsights(transactions: transactions))
        
        // 2. Timing filters
        let curated = timingEngine.filterByTiming(insights: generated)
        
        // 3. Ranking weights
        let ranked = rankingEngine.rank(insights: curated)
        
        // 4. Thread-safe publishing
        if Thread.isMainThread {
            self.insights = ranked
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.insights = ranked
            }
        }
    }
}
