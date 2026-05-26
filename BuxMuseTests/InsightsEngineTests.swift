//
//  InsightsEngineTests.swift
//  BuxMuseTests
//
//  Unit tests verifying the BuxMuse Insights Engine, Spending Insights, Subscription Insights,
//  Category Insights, Merchant Insights, Goal Insights, Pattern Insights, Predictive Insights,
//  Ranking Engine, and Timing Engine.
//

import XCTest
@testable import BuxMuse

final class InsightsEngineTests: XCTestCase {
    var financialEngine: LocalFinancialIntelligenceEngine18!
    var goalsEngine: GoalsEngine!
    var goalsViewModel: GoalsViewModel!
    var insightsEngine: InsightsEngine!
    var viewModel: InsightsViewModel!
    
    override func setUp() {
        super.setUp()
        financialEngine = LocalFinancialIntelligenceEngine18()
        goalsEngine = GoalsEngine()
        goalsViewModel = GoalsViewModel(goalsEngine: goalsEngine, financialEngine: financialEngine)
        insightsEngine = InsightsEngine()
        viewModel = InsightsViewModel(insightsEngine: insightsEngine, financialEngine: financialEngine, goalsViewModel: goalsViewModel)
    }
    
    override func tearDown() {
        viewModel = nil
        insightsEngine = nil
        goalsViewModel = nil
        goalsEngine = nil
        financialEngine = nil
        super.tearDown()
    }
    
    func testSpendingInsightsPaydayAndWeeklySpikes() {
        let calendar = Calendar.current
        let now = Date()
        
        let lastPaydayDate = calendar.date(byAdding: .day, value: -1, to: now) ?? now
        let fiveWeeksAgo = calendar.date(byAdding: .day, value: -35, to: now) ?? now
        
        // Mock historical transactions to set average weekly spending of £100
        var txs: [Transaction] = [
            Transaction(date: lastPaydayDate, amount: MoneyAmount(value: 3000, currencyCode: "GBP"), merchantName: "Salary Corp", category: .income),
            Transaction(date: calendar.date(byAdding: .day, value: -10, to: now) ?? now, amount: MoneyAmount(value: -100, currencyCode: "GBP"), merchantName: "Grocer A", category: .groceries),
            Transaction(date: calendar.date(byAdding: .day, value: -17, to: now) ?? now, amount: MoneyAmount(value: -100, currencyCode: "GBP"), merchantName: "Grocer B", category: .groceries),
            Transaction(date: calendar.date(byAdding: .day, value: -24, to: now) ?? now, amount: MoneyAmount(value: -100, currencyCode: "GBP"), merchantName: "Grocer C", category: .groceries),
            Transaction(date: calendar.date(byAdding: .day, value: -31, to: now) ?? now, amount: MoneyAmount(value: -100, currencyCode: "GBP"), merchantName: "Grocer D", category: .groceries),
            
            // Current week spend is £250 (weekly spike detected)
            Transaction(date: now, amount: MoneyAmount(value: -250, currencyCode: "GBP"), merchantName: "Luxury Store", category: .other)
        ]
        
        let engine = SpendingInsightsEngine()
        let result = engine.generateInsights(transactions: txs)
        
        // Verify Weekly Spend Spike detection
        let weeklySpike = result.first(where: { $0.title == "Weekly Spend Spike" })
        XCTAssertNotNil(weeklySpike)
        XCTAssertEqual(weeklySpike?.severity, .high)
        XCTAssertEqual(weeklySpike?.category, .spending)
        
        // Verify Payday Spending Surge (spent £250 after £3000 payday, average baseline is £100/3d)
        let paydaySurge = result.first(where: { $0.title == "Payday Spending Surge" })
        XCTAssertNotNil(paydaySurge)
        XCTAssertEqual(paydaySurge?.severity, .medium)
    }
    
    func testSubscriptionInsightsZombieAndRedirections() {
        let activeSubs = [
            SubscriptionInfo(
                merchantName: "Netflix",
                cost: MoneyAmount(value: 15.99, currencyCode: "GBP"),
                billingCycle: .monthly,
                nextRenewalDate: Date().addingTimeInterval(15 * 86400),
                category: .subscriptions,
                risks: [SubscriptionRisk(type: .zombieSubscription, description: "Unused zombie", severity: "medium")]
            )
        ]
        
        let activeGoals = [
            Goal(name: "Tesla SUV", targetAmount: 45000, currentAmount: 10000, priority: 1)
        ]
        
        let engine = SubscriptionInsightsEngine()
        let result = engine.generateInsights(subscriptions: activeSubs, goals: activeGoals)
        
        // Verify Zombie Subscription
        let zombie = result.first(where: { $0.title == "Zombie Subscription" })
        XCTAssertNotNil(zombie)
        XCTAssertEqual(zombie?.severity, .medium)
        
        // Verify Subscription redirection
        let redirection = result.first(where: { $0.title == "Subscription redirection" })
        XCTAssertNotNil(redirection)
        XCTAssertEqual(redirection?.severity, .low)
        XCTAssertEqual(redirection?.category, .subscription)
        XCTAssertEqual(redirection?.affectedGoalName, "Tesla SUV")
    }
    
    func testCategoryAndMerchantAnomalies() {
        let calendar = Calendar.current
        let now = Date()
        
        // Overspend groceries baseline (£50/mo), current month grocery total is £300
        let txs = [
            Transaction(date: calendar.date(byAdding: .day, value: -40, to: now) ?? now, amount: MoneyAmount(value: -50, currencyCode: "GBP"), merchantName: "Tesco", category: .groceries),
            Transaction(date: calendar.date(byAdding: .day, value: -70, to: now) ?? now, amount: MoneyAmount(value: -50, currencyCode: "GBP"), merchantName: "Tesco", category: .groceries),
            Transaction(date: now, amount: MoneyAmount(value: -300, currencyCode: "GBP"), merchantName: "Tesco", category: .groceries)
        ]
        
        let catEngine = CategoryInsightsEngine()
        let catResult = catEngine.generateInsights(transactions: txs)
        
        let groceriesOverspend = catResult.first(where: { $0.title == "Groceries Overspend" })
        XCTAssertNotNil(groceriesOverspend)
        XCTAssertEqual(groceriesOverspend?.severity, .high)
        
        // Merchant price hikes: previous Tesco was £50, latest Tesco is £300
        let merchEngine = MerchantInsightsEngine()
        let merchResult = merchEngine.generateInsights(transactions: txs)
        
        let priceSpike = merchResult.first(where: { $0.title == "Merchant Price Spike" })
        XCTAssertNotNil(priceSpike)
        XCTAssertEqual(priceSpike?.accentColorName, "orange")
    }
    
    func testGoalInsightsTimelines() {
        let calendar = Calendar.current
        let now = Date()
        let baselineDate = calendar.date(byAdding: .day, value: -120, to: now) ?? now
        
        // Add transactions to trigger category overspends which will trigger Goal Risks
        financialEngine.addTransaction(Transaction(date: baselineDate, amount: MoneyAmount(value: -10, currencyCode: "GBP"), merchantName: "Tesco", category: .groceries))
        financialEngine.addTransaction(Transaction(date: now, amount: MoneyAmount(value: -500, currencyCode: "GBP"), merchantName: "Tesco", category: .groceries))
        
        var newGoal = goalsEngine.createGoal(
            name: "New Vacation",
            targetAmount: 5000,
            currentAmount: 0,
            deadline: Date().addingTimeInterval(30 * 86400),
            priority: 1
        )
        newGoal.createdAt = calendar.date(byAdding: .day, value: -20, to: now) ?? now
        goalsEngine.updateGoal(newGoal)
        
        let engine = GoalInsightsEngine()
        let result = engine.generateInsights(goals: [newGoal], goalsViewModel: goalsViewModel)
        
        // Low health goal should be flagged at risk
        let timelineRisk = result.first(where: { $0.title == "Goal Timeline At Risk" })
        XCTAssertNotNil(timelineRisk)
        XCTAssertEqual(timelineRisk?.severity, .high)
    }
    
    func testPatternAndPredictiveEngines() {
        let calendar = Calendar.current
        let now = Date()
        
        // Late night transport spikes: Set hour to 22 and 23 using Calendar components for 100% robustness
        var comps1 = calendar.dateComponents([.year, .month, .day], from: now)
        comps1.hour = 22
        comps1.minute = 30
        let lateNightDate1 = calendar.date(from: comps1) ?? now
        
        var comps2 = calendar.dateComponents([.year, .month, .day], from: now)
        comps2.day = (comps2.day ?? 1) - 1
        comps2.hour = 23
        comps2.minute = 15
        let lateNightDate2 = calendar.date(from: comps2) ?? now
        
        let historicalDate = calendar.date(byAdding: .day, value: -45, to: now) ?? now
        
        let txs = [
            Transaction(date: lateNightDate1, amount: MoneyAmount(value: -45, currencyCode: "GBP"), merchantName: "Uber", category: .transport),
            Transaction(date: lateNightDate2, amount: MoneyAmount(value: -35, currencyCode: "GBP"), merchantName: "Uber", category: .transport),
            
            // Historical spending to set monthly baseline average of £300, making run-rate of £80/mo look extremely stable
            Transaction(date: historicalDate, amount: MoneyAmount(value: -900, currencyCode: "GBP"), merchantName: "Tesco", category: .groceries)
        ]
        
        let patternEngine = PatternInsightsEngine()
        let patternResult = patternEngine.generateInsights(transactions: txs)
        
        let transportSpike = patternResult.first(where: { $0.title == "Late Night Transport Surge" })
        XCTAssertNotNil(transportSpike)
        XCTAssertEqual(transportSpike?.severity, .low)
        
        let predEngine = PredictiveInsightsEngine()
        let predResult = predEngine.generateInsights(transactions: txs)
        
        // Stable spending predicted if current run-rate is extremely low
        let budgetForecast = predResult.first(where: { $0.title == "Stable Spending Forecast" })
        XCTAssertNotNil(budgetForecast)
    }
    
    func testRankingAndTimingCadence() {
        let list = [
            FinancialInsight(
                title: "Payday Splurge Bias",
                value: "Splurge Risk",
                description: "You spent more after payday.",
                fullExplanation: "payday splurge",
                severity: .medium,
                category: .spending,
                systemIcon: "creditcard",
                accentColorName: "orange",
                suggestedActions: [],
                dataBehind: "Last Payday: 2026-05-25 09:00:00 +0100." // 1 day ago (should pass timing filter)
            ),
            FinancialInsight(
                title: "Overspend High Risk Alert",
                value: "Spike Detected",
                description: "groceries overspend",
                fullExplanation: "high cost overspend",
                severity: .high,
                category: .predictive,
                systemIcon: "exclamationmark.square",
                accentColorName: "red",
                suggestedActions: [],
                impactMonthly: 450
            )
        ]
        
        // Ranking validation
        let ranker = InsightsRankingEngine()
        let ranked = ranker.rank(insights: list)
        
        XCTAssertEqual(ranked.first?.title, "Overspend High Risk Alert") // High severity + high impact takes 1st place!
        
        // Timing validation
        let timer = InsightsTimingEngine()
        let filtered = timer.filterByTiming(insights: ranked)
        XCTAssertEqual(filtered.count, 2)
    }
}
