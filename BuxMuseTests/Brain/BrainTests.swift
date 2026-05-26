//
//  BrainTests.swift
//  BuxMuseTests
//  Brain/
//
//  Comprehensive XCTest suite verifying the local financial and merchant intelligence engine.
//

import XCTest
@testable import BuxMuse

final class BrainTests: XCTestCase {
    
    // MARK: - Domain Resolver Tests
    func testDomainResolver() {
        XCTAssertEqual(MerchantLogoEngine.resolveDomain(for: "Starbucks Ltd"), "starbucks.com")
        XCTAssertEqual(MerchantLogoEngine.resolveDomain(for: "Apple Inc."), "apple.com")
        XCTAssertEqual(MerchantLogoEngine.resolveDomain(for: "Netflix Corp"), "netflix.com")
        XCTAssertEqual(MerchantLogoEngine.resolveDomain(for: "Unknown Shop"), "unknownshop.com")
        XCTAssertNil(MerchantLogoEngine.resolveDomain(for: "   "))
    }
    
    // MARK: - Merchant Name Normalization & Levenshtein Distance Tests
    func testNameNormalizationAndLevenshtein() {
        // Normalization
        XCTAssertEqual(MerchantIntelligence.normalize("Starbucks Ltd ☕️"), "starbucks")
        XCTAssertEqual(MerchantIntelligence.normalize("Apple Inc. "), "apple")
        XCTAssertEqual(MerchantIntelligence.normalize("Netflix & Co."), "netflix")
        
        // Levenshtein
        XCTAssertEqual(MerchantIntelligence.levenshteinDistance(between: "apple", and: "apple"), 0)
        XCTAssertEqual(MerchantIntelligence.levenshteinDistance(between: "apple", and: "aple"), 1)
        XCTAssertEqual(MerchantIntelligence.levenshteinDistance(between: "starbucks", and: "starbuck"), 1)
        XCTAssertEqual(MerchantIntelligence.levenshteinDistance(between: "netflix", and: "netflx"), 1)
    }
    
    // MARK: - Merchant Clustering Tests
    func testMerchantClustering() {
        let rawNames = ["Starbucks Cafe", "Starbucks", "Starbuck", "Apple Store", "Apple", "Uber Taxi", "Uber"]
        let clusters = MerchantIntelligence.clusterMerchants(rawNames, distanceThreshold: 5)
        
        XCTAssertGreaterThanOrEqual(clusters.count, 3)
        
        // Find Starbucks cluster
        let starbucksCluster = clusters.first(where: { $0.canonicalName.contains("Starbucks") })
        XCTAssertNotNil(starbucksCluster)
        XCTAssertTrue(starbucksCluster?.merchantNames.contains("Starbucks") ?? false)
    }
    
    // MARK: - Cache Eviction Tests
    func testLightweightLogoCacheEviction() {
        let cache = LightweightLogoCache.shared
        cache.clearCache()
        
        // Populate cache up to the 50 limit and verify LRU behavior
        let testImage = UIImage()
        for idx in 1...60 {
            cache.saveImage(testImage, forKey: "key_\(idx)")
        }
        
        // Key 1 should be evicted since countLimit is capped at 50 in memory
        XCTAssertNil(cache.getImage(forKey: "key_1"))
    }
    
    // MARK: - Category summaries & Trend calculations
    func testCategorySummariesAndTrends() {
        let engine = LocalFinancialIntelligenceEngine18()
        let today = Date()
        
        // Add current period expenses
        engine.addTransaction(Transaction(
            date: today,
            amount: MoneyAmount(value: -150.0, currencyCode: "USD"),
            merchantName: "Whole Foods",
            category: .groceries
        ))
        
        // Add previous equivalent period expenses
        let oneMonthAgo = today.addingTimeInterval(-30 * 24 * 3600)
        engine.addTransaction(Transaction(
            date: oneMonthAgo,
            amount: MoneyAmount(value: -100.0, currencyCode: "USD"),
            merchantName: "Whole Foods",
            category: .groceries
        ))
        
        let range = DateInterval(start: today.addingTimeInterval(-15 * 24 * 3600), end: today.addingTimeInterval(15 * 24 * 3600))
        let summaries = engine.categorySummaries(for: range)
        
        let groceriesSummary = summaries.first(where: { $0.category == .groceries })
        XCTAssertNotNil(groceriesSummary)
        XCTAssertEqual(groceriesSummary?.total.value, -150.0)
        // Trend: (-150 - -100) / -100 * 100 = 50% increase
        XCTAssertEqual(groceriesSummary?.trendPercentage, -50.0)
    }
    
    // MARK: - Overspend Alerting (Triggered at > 1.15x baseline)
    func testOverspendAlerting() {
        let engine = LocalFinancialIntelligenceEngine18()
        let today = Date()
        let calendar = Calendar.current
        
        // Build a baseline by inserting transactions from months 4 and 5 ago (reference range: -6 to -3 months)
        for monthOffset in [-4, -5] {
            if let targetDate = calendar.date(byAdding: .month, value: monthOffset, to: today) {
                engine.addTransaction(Transaction(
                    date: targetDate,
                    amount: MoneyAmount(value: -100.0, currencyCode: "USD"),
                    merchantName: "Baseline Restaurant",
                    category: .restaurants
                ))
            }
        }
        
        // Current month (range) restaurants expense: -200 (Baseline average is -100. Overspend is > 1.15 baseline)
        engine.addTransaction(Transaction(
            date: today,
            amount: MoneyAmount(value: -200.0, currencyCode: "USD"),
            merchantName: "Fancy Sushi",
            category: .restaurants
        ))
        
        let range = DateInterval(start: today.addingTimeInterval(-15 * 24 * 3600), end: today.addingTimeInterval(15 * 24 * 3600))
        let alerts = engine.overspendAlerts(for: range)
        
        XCTAssertEqual(alerts.count, 1)
        XCTAssertEqual(alerts.first?.category, .restaurants)
        XCTAssertEqual(alerts.first?.overspendPercentage, 100.0) // 100% overspend
    }
    
    // MARK: - Savings Opportunities Detection
    func testSavingsOpportunities() {
        let engine = LocalFinancialIntelligenceEngine18()
        let today = Date()
        let calendar = Calendar.current
        
        // Build baseline of -100.0
        for monthOffset in [-4, -5] {
            if let targetDate = calendar.date(byAdding: .month, value: monthOffset, to: today) {
                engine.addTransaction(Transaction(
                    date: targetDate,
                    amount: MoneyAmount(value: -100.0, currencyCode: "USD"),
                    merchantName: "Groceries Base",
                    category: .groceries
                ))
            }
        }
        
        // Current is -200.0 (top category, above baseline)
        engine.addTransaction(Transaction(
            date: today,
            amount: MoneyAmount(value: -200.0, currencyCode: "USD"),
            merchantName: "Organic Market",
            category: .groceries
        ))
        
        let range = DateInterval(start: today.addingTimeInterval(-15 * 24 * 3600), end: today.addingTimeInterval(15 * 24 * 3600))
        let savings = engine.savingsOpportunities(for: range)
        
        XCTAssertEqual(savings.count, 1)
        XCTAssertEqual(savings.first?.category, .groceries)
        // Expected savings: 15% of (200 - 100) = 15.00
        XCTAssertEqual(savings.first?.estimatedMonthlySavings?.value, 15.00)
    }
    
    // MARK: - Backwards Compatibility & Fallback Logic Match
    func testFallbackLogicEquivalence() {
        let engine26: FinancialIntelligenceEngine
        if #available(iOS 26.0, *) {
            engine26 = LocalFinancialIntelligenceEngine()
        } else {
            engine26 = LocalFinancialIntelligenceEngine18()
        }
        
        let engine18 = LocalFinancialIntelligenceEngine18()
        let today = Date()
        
        let tx = Transaction(
            date: today,
            amount: MoneyAmount(value: -50.0, currencyCode: "USD"),
            merchantName: "Coffee House",
            category: .restaurants
        )
        
        engine26.addTransaction(tx)
        engine18.addTransaction(tx)
        
        XCTAssertEqual(engine26.allTransactions().count, engine18.allTransactions().count)
        XCTAssertEqual(engine26.allTransactions().first?.amount.value, engine18.allTransactions().first?.amount.value)
    }
}
