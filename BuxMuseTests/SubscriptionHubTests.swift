//
//  SubscriptionHubTests.swift
//  BuxMuseTests
//
//  Unit tests verifying BuxMuse Subscription Hub logic, billing cycle AI,
//  burn rate equations, health scores, and risk analysis metrics.
//

import XCTest
@testable import BuxMuse

final class SubscriptionHubTests: XCTestCase {
    var engine: LocalFinancialIntelligenceEngine18!
    var settingsManager: AppSettingsManager!
    var viewModel: SubscriptionHubViewModel!
    
    override func setUp() {
        super.setUp()
        engine = LocalFinancialIntelligenceEngine18()
        settingsManager = AppSettingsManager()
        viewModel = SubscriptionHubViewModel(engine: engine, settingsManager: settingsManager)
    }
    
    override func tearDown() {
        viewModel = nil
        settingsManager = nil
        engine = nil
        super.tearDown()
    }
    
    func testBillingCycleAIDetectionAndRenewalPrediction() {
        // 1. Setup Monthly recurring charges for "Netflix"
        let calendar = Calendar.current
        let today = Date()
        
        let tx1 = Transaction(
            date: calendar.date(byAdding: .day, value: -60, to: today)!,
            amount: MoneyAmount(value: -15.49, currencyCode: "USD"),
            merchantName: "Netflix",
            category: .subscriptions
        )
        let tx2 = Transaction(
            date: calendar.date(byAdding: .day, value: -30, to: today)!,
            amount: MoneyAmount(value: -15.49, currencyCode: "USD"),
            merchantName: "Netflix",
            category: .subscriptions
        )
        
        engine.addTransaction(tx1)
        engine.addTransaction(tx2)
        
        // 2. Query subscriptions through the brain
        let subs = engine.activeSubscriptions()
        XCTAssertEqual(subs.count, 1)
        
        let netflix = subs.first!
        XCTAssertEqual(netflix.merchantName, "Netflix")
        XCTAssertEqual(netflix.billingCycle, .day30)
        
        // Assert next renewal prediction is roughly 30 days after the last charge
        let expectedRenewal = calendar.date(byAdding: .day, value: 30, to: tx2.date)!
        XCTAssertEqual(
            calendar.startOfDay(for: netflix.nextRenewalDate),
            calendar.startOfDay(for: expectedRenewal)
        )
    }
    
    func testBurnRateAndHealthScoreCalculation() {
        // Setup Netflix monthly expense
        let calendar = Calendar.current
        let today = Date()
        
        let n1 = Transaction(
            date: calendar.date(byAdding: .day, value: -60, to: today)!,
            amount: MoneyAmount(value: -10.00, currencyCode: "USD"),
            merchantName: "Netflix",
            category: .subscriptions
        )
        let n2 = Transaction(
            date: calendar.date(byAdding: .day, value: -30, to: today)!,
            amount: MoneyAmount(value: -10.00, currencyCode: "USD"),
            merchantName: "Netflix",
            category: .subscriptions
        )
        engine.addTransaction(n1)
        engine.addTransaction(n2)
        
        // Setup Spotify weekly expense
        let s1 = Transaction(
            date: calendar.date(byAdding: .day, value: -14, to: today)!,
            amount: MoneyAmount(value: -5.00, currencyCode: "USD"),
            merchantName: "Spotify",
            category: .subscriptions
        )
        let s2 = Transaction(
            date: calendar.date(byAdding: .day, value: -7, to: today)!,
            amount: MoneyAmount(value: -5.00, currencyCode: "USD"),
            merchantName: "Spotify",
            category: .subscriptions
        )
        engine.addTransaction(s1)
        engine.addTransaction(s2)
        
        // Refresh ViewModel
        viewModel.refreshData()
        
        // Verify Weekly and Monthly cost totals
        // Spotify is weekly: $5.00/week -> $5.00 weekly total. Netflix is day30: $10.00 monthly.
        // Spotify monthly projection: 5 * 4.33 = 21.65. Combined monthly: 10 + 21.65 = 31.65
        XCTAssertEqual(viewModel.totalWeeklyCost.value, 5.00)
        XCTAssertEqual(viewModel.totalMonthlyCost.value, 31.65)
        
        // Daily burn rate: $31.65 / 30.42 ≈ 1.04
        XCTAssertEqual(round(NSDecimalNumber(decimal: viewModel.dailyBurnRate.value).doubleValue * 100.0) / 100.0, 1.04)
        
        // Health score should start at 100 as there are no active price hikes or double charges
        XCTAssertEqual(viewModel.healthScore, 100)
    }
    
    func testRiskAnalyzerAndCancellationOpportunityEngine() {
        let calendar = Calendar.current
        let today = Date()
        
        // Setup Netflix showing a clear Price Hike (e.g. from $10.00 to $15.00)
        let n1 = Transaction(
            date: calendar.date(byAdding: .day, value: -60, to: today)!,
            amount: MoneyAmount(value: -10.00, currencyCode: "USD"),
            merchantName: "Netflix",
            category: .subscriptions
        )
        let n2 = Transaction(
            date: calendar.date(byAdding: .day, value: -30, to: today)!,
            amount: MoneyAmount(value: -15.00, currencyCode: "USD"),
            merchantName: "Netflix",
            category: .subscriptions
        )
        engine.addTransaction(n1)
        engine.addTransaction(n2)
        
        // Setup Zombie subscription (has "zombie" or "unused" in notes)
        let z1 = Transaction(
            date: calendar.date(byAdding: .day, value: -60, to: today)!,
            amount: MoneyAmount(value: -12.00, currencyCode: "USD"),
            merchantName: "Adobe CC",
            category: .subscriptions,
            notes: "Zombie unused subscription"
        )
        let z2 = Transaction(
            date: calendar.date(byAdding: .day, value: -30, to: today)!,
            amount: MoneyAmount(value: -12.00, currencyCode: "USD"),
            merchantName: "Adobe CC",
            category: .subscriptions,
            notes: "zombie"
        )
        engine.addTransaction(z1)
        engine.addTransaction(z2)
        
        viewModel.refreshData()
        
        // Health score should deduct points for Price Hike (-8) and Zombie (-10) -> score 82
        XCTAssertEqual(viewModel.healthScore, 82)
        
        // Verify price hike risk is added
        let netflixSub = viewModel.subscriptions.first(where: { $0.merchantName == "Netflix" })
        XCTAssertNotNil(netflixSub)
        XCTAssertTrue(netflixSub!.risks.contains(where: { $0.type == .priceHike }))
        
        // Verify zombie risk is added
        let adobeSub = viewModel.subscriptions.first(where: { $0.merchantName == "Adobe CC" })
        XCTAssertNotNil(adobeSub)
        XCTAssertTrue(adobeSub!.risks.contains(where: { $0.type == .zombieSubscription }))
    }
    
    func testSubscriptionDetailViewModelAndCancelSimulation() {
        let calendar = Calendar.current
        let today = Date()
        
        let tx1 = Transaction(
            date: calendar.date(byAdding: .day, value: -60, to: today)!,
            amount: MoneyAmount(value: -20.00, currencyCode: "USD"),
            merchantName: "Prime Video",
            category: .subscriptions
        )
        let tx2 = Transaction(
            date: calendar.date(byAdding: .day, value: -30, to: today)!,
            amount: MoneyAmount(value: -20.00, currencyCode: "USD"),
            merchantName: "Prime Video",
            category: .subscriptions
        )
        engine.addTransaction(tx1)
        engine.addTransaction(tx2)
        
        viewModel.refreshData()
        
        // Load details
        viewModel.loadDetail(for: "Prime Video")
        XCTAssertNotNil(viewModel.selectedDetail)
        
        let detail = viewModel.selectedDetail!
        XCTAssertEqual(detail.info.merchantName, "Prime Video")
        XCTAssertEqual(detail.budgetImpactMonthly.value, -20.00)
        XCTAssertEqual(detail.budgetImpactYearly.value, -240.00)
        
        // Test simulated cancellation
        viewModel.simulateCancel(merchantName: "Prime Video")
        XCTAssertEqual(viewModel.subscriptions.count, 0)
    }
}
