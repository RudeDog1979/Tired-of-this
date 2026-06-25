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
        XCTAssertEqual(netflix.billingCycle, .monthly)
        
        // Assert next renewal prediction is roughly one month after the last charge
        let expectedRenewal = calendar.date(byAdding: .month, value: 1, to: tx2.date)!
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
        // Spotify has only two charges 7 days apart — treated as monthly (not weekly).
        // Netflix is day30: $10.00 monthly. Spotify: $5.00 monthly. Combined: $15.00
        XCTAssertEqual(viewModel.totalWeeklyCost.value, 0)
        XCTAssertEqual(viewModel.totalMonthlyCost.value, 15.00)
        
        // Daily burn rate: $15.00 / 30.42 ≈ 0.49
        XCTAssertEqual(round(NSDecimalNumber(decimal: viewModel.dailyBurnRate.value).doubleValue * 100.0) / 100.0, 0.49)
        
        // Health score should start at 100 as there are no active price hikes or double charges
        XCTAssertEqual(viewModel.healthScore, 100)
    }
    
    func testDuplicateSameMerchantChargesSurfaceParallelSubscriptions() {
        let calendar = Calendar.current
        let today = Date()

        let tx1 = Transaction(
            date: calendar.date(byAdding: .day, value: -2, to: today)!,
            amount: MoneyAmount(value: -9.99, currencyCode: "USD"),
            merchantName: "Example Plus",
            category: .subscriptions
        )
        let tx2 = Transaction(
            date: calendar.date(byAdding: .day, value: -1, to: today)!,
            amount: MoneyAmount(value: -9.99, currencyCode: "USD"),
            merchantName: "Example Plus",
            category: .subscriptions
        )

        engine.addTransaction(tx1)
        engine.addTransaction(tx2)

        let subs = engine.activeSubscriptions()
        XCTAssertEqual(subs.count, 2)
        XCTAssertEqual(subs.filter { $0.merchantName == "Example Plus" }.count, 2)
        XCTAssertTrue(subs.contains(where: { $0.risks.contains(where: { $0.type == .doubleCharge }) }))
        XCTAssertEqual(Set(subs.map(\.id)).count, 2)
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

    func testTwoChargesSevenDaysApartDefaultToMonthlyNotWeekly() {
        let calendar = Calendar.current
        let today = Date()

        let tx1 = Transaction(
            date: calendar.date(byAdding: .day, value: -7, to: today)!,
            amount: MoneyAmount(value: -15.00, currencyCode: "USD"),
            merchantName: "Voxi",
            category: .subscriptions
        )
        let tx2 = Transaction(
            date: today,
            amount: MoneyAmount(value: -15.00, currencyCode: "USD"),
            merchantName: "Voxi",
            category: .subscriptions
        )

        engine.addTransaction(tx1)
        engine.addTransaction(tx2)

        let subs = engine.activeSubscriptions()
        XCTAssertEqual(subs.count, 1)
        XCTAssertEqual(subs.first?.billingCycle, .monthly)
    }

    func testCancellationGuideRemovesMitchellAndProvidesLinks() {
        let calendar = Calendar.current
        let today = Date()

        let appleTx = Transaction(
            date: calendar.date(byAdding: .day, value: -30, to: today)!,
            amount: MoneyAmount(value: -2.99, currencyCode: "USD"),
            merchantName: "Apple.com/Bill iCloud",
            category: .subscriptions,
            notes: WalletStatementIntelligence.walletImportNotes(rawLabel: "APPLE.COM/BILL")
        )
        engine.addTransaction(appleTx)
        engine.addTransaction(Transaction(
            date: today,
            amount: MoneyAmount(value: -2.99, currencyCode: "USD"),
            merchantName: "Apple.com/Bill iCloud",
            category: .subscriptions,
            notes: WalletStatementIntelligence.walletImportNotes(rawLabel: "APPLE.COM/BILL")
        ))

        let detail = engine.subscriptionDetail(for: "Apple.com/Bill iCloud")
        XCTAssertNotNil(detail)
        XCTAssertFalse(detail!.cancellation.instructions.localizedCaseInsensitiveContains("Mitchell Santos"))
        XCTAssertEqual(detail!.cancellation.channel, .apple)
        XCTAssertNotNil(detail!.cancellation.appStoreManageURL)

        let voxiDetail = BillingCycleAIEngine.subscriptionDetail(
            info: SubscriptionInfo(
                merchantName: "WWW.VOXI.COM",
                cost: MoneyAmount(value: -15, currencyCode: "USD"),
                billingCycle: .monthly,
                nextRenewalDate: today,
                category: .subscriptions,
                risks: []
            ),
            allTransactions: [
                Transaction(
                    date: calendar.date(byAdding: .day, value: -30, to: today)!,
                    amount: MoneyAmount(value: -15, currencyCode: "USD"),
                    merchantName: "WWW.VOXI.COM",
                    category: .subscriptions
                )
            ]
        )
        XCTAssertEqual(voxiDetail.cancellation.channel, .direct)
        XCTAssertNotNil(voxiDetail.cancellation.appStoreManageURL)
        XCTAssertNotNil(voxiDetail.cancellation.providerWebsiteURL)
        XCTAssertTrue(voxiDetail.cancellation.providerWebsiteURL?.absoluteString.contains("voxi.com") == true)
    }

    func testCancellationGuideAlwaysOffersAppStoreForDirectBilledMerchant() {
        let today = Date()
        let guide = SubscriptionBillingChannelDetector.buildCancellationGuide(
            merchantName: "Netflix",
            transactions: [
                Transaction(
                    date: today,
                    amount: MoneyAmount(value: -15.49, currencyCode: "USD"),
                    merchantName: "Netflix",
                    category: .subscriptions
                )
            ],
            locale: Locale(identifier: "en")
        )

        XCTAssertEqual(guide.channel, .direct)
        XCTAssertEqual(guide.appStoreManageURL, SubscriptionBillingChannelDetector.appStoreManageURL)
        XCTAssertNotNil(guide.providerWebsiteURL)
    }
}
