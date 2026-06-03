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
        goalsViewModel: GoalsViewModel,
        projects: [StudioProject] = [],
        locale: Locale
    ) {
        let isTesting = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil || NSClassFromString("XCTest") != nil
        
        if isTesting {
            self.performRecalculation(
                transactions: transactions,
                subscriptions: subscriptions,
                goals: goals,
                goalsViewModel: goalsViewModel,
                projects: projects,
                locale: locale
            )
        } else {
            calculationQueue.async { [weak self] in
                self?.performRecalculation(
                    transactions: transactions,
                    subscriptions: subscriptions,
                    goals: goals,
                    goalsViewModel: goalsViewModel,
                    projects: projects,
                    locale: locale
                )
            }
        }
    }
    
    private func performRecalculation(
        transactions: [Transaction],
        subscriptions: [SubscriptionInfo],
        goals: [Goal],
        goalsViewModel: GoalsViewModel,
        projects: [StudioProject],
        locale: Locale
    ) {
        var generated: [FinancialInsight] = []
        
        generated.append(contentsOf: spendingEngine.generateInsights(transactions: transactions, locale: locale))
        generated.append(contentsOf: subscriptionEngine.generateInsights(subscriptions: subscriptions, goals: goals, locale: locale))
        generated.append(contentsOf: categoryEngine.generateInsights(transactions: transactions, locale: locale))
        generated.append(contentsOf: merchantEngine.generateInsights(transactions: transactions, locale: locale))
        generated.append(contentsOf: goalEngine.generateInsights(goals: goals, goalsViewModel: goalsViewModel, locale: locale))
        generated.append(contentsOf: patternEngine.generateInsights(transactions: transactions, locale: locale))
        generated.append(contentsOf: predictiveEngine.generateInsights(transactions: transactions, locale: locale))
        generated.append(contentsOf: BarterInsightsEngine.generateInsights(transactions: transactions, locale: locale))
        generated.append(contentsOf: PaymentSourceInsightsEngine.generateInsights(transactions: transactions, locale: locale))
        generated.append(contentsOf: WorkspaceInsightsEngine.generateInsights(transactions: transactions, locale: locale))
        generated.append(contentsOf: CashDigitalInsightsEngine.generateInsights(transactions: transactions, locale: locale))
        generated.append(contentsOf: ScopeCreepInsightsEngine.generateInsights(projects: projects, locale: locale))
        
        let curated = timingEngine.filterByTiming(insights: generated)
        let ranked = rankingEngine.rank(insights: curated)
        
        if Thread.isMainThread {
            self.insights = ranked
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.insights = ranked
            }
        }
    }
}
