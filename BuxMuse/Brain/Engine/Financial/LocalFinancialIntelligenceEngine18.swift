//
//  LocalFinancialIntelligenceEngine18.swift
//  BuxMuse
//  Brain/Engine/Financial/
//
//  iOS 18 Fallback class conforming to ObservableObject for compatibility.
//

import Foundation
import Combine

public final class LocalFinancialIntelligenceEngine18: FinancialIntelligenceEngine, ObservableObject {
    @Published private var transactions: [UUID: Transaction] = [:]
    
    private var cachedActiveSubscriptions: [SubscriptionInfo] = []
    private var cachedSubscriptionDetails: [String: SubscriptionDetail] = [:]
    private let calculationQueue = DispatchQueue(label: "com.buxmuse.financial.calculations", qos: .userInitiated)
    
    public init() {
        queueBackgroundRecalculations()
    }

    public func loadTransactions(_ loaded: [Transaction]) {
        transactions = Dictionary(uniqueKeysWithValues: loaded.map { ($0.id, $0) })
        queueBackgroundRecalculations()
        objectWillChange.send()
    }
    
    public func addTransaction(_ transaction: Transaction) {
        objectWillChange.send()
        transactions[transaction.id] = transaction
        queueBackgroundRecalculations()
    }
    
    public func updateTransaction(_ transaction: Transaction) {
        objectWillChange.send()
        transactions[transaction.id] = transaction
        queueBackgroundRecalculations()
    }
    
    public func deleteTransaction(id: UUID) {
        objectWillChange.send()
        transactions.removeValue(forKey: id)
        queueBackgroundRecalculations()
    }
    
    private func queueBackgroundRecalculations() {
        let txs = Array(transactions.values)
        
        let performRecalc = { [weak self] in
            guard let self = self else { return }
            
            let uniqueMerchants = Array(Set(txs.map { $0.merchantName }))
            
            var subs: [SubscriptionInfo] = []
            var details: [String: SubscriptionDetail] = [:]
            
            for merchant in uniqueMerchants {
                let subCategoryTransactions = txs.filter { MerchantLogoEngine.normalizeMerchantName($0.merchantName) == MerchantLogoEngine.normalizeMerchantName(merchant) }
                let hasSubscriptionCat = subCategoryTransactions.contains(where: { $0.category == .subscriptions })
                let activeCategory = hasSubscriptionCat ? TransactionCategory.subscriptions : (subCategoryTransactions.first?.category ?? .subscriptions)
                
                if let subInfo = BillingCycleAIEngine.analyzeSubscription(
                    merchantName: merchant,
                    transactions: txs,
                    category: activeCategory
                ) {
                    subs.append(subInfo)
                    
                    let detail = BillingCycleAIEngine.subscriptionDetail(info: subInfo, allTransactions: txs)
                    details[MerchantLogoEngine.normalizeMerchantName(merchant)] = detail
                }
            }

            BillingCycleAIEngine.appendUserDeclaredSubscriptions(to: &subs, details: &details, transactions: txs)

            let cancelledMerchants = Set(UserDefaults.standard.stringArray(forKey: "buxmuse.cancelledSubscriptionMerchants") ?? [])
            subs = subs.filter {
                !cancelledMerchants.contains(MerchantLogoEngine.normalizeMerchantName($0.merchantName))
            }
            details = details.filter { !cancelledMerchants.contains($0.key) }
            
            let sortedSubs = subs.sorted(by: { abs($0.cost.value) > abs($1.cost.value) })
            
            let applyResults = {
                self.cachedActiveSubscriptions = sortedSubs
                self.cachedSubscriptionDetails = details
                self.objectWillChange.send()
                NotificationCenter.default.post(name: .buxMuseFinancialDataDidChange, object: nil)
            }
            
            if Thread.isMainThread {
                applyResults()
            } else {
                DispatchQueue.main.async {
                    applyResults()
                }
            }
        }
        
        let isTesting = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil || NSClassFromString("XCTest") != nil
        
        if isTesting {
            performRecalc()
        } else {
            calculationQueue.async {
                performRecalc()
            }
        }
    }
    
    public func allTransactions() -> [Transaction] {
        return Array(transactions.values).sorted(by: { $0.date > $1.date })
    }
    
    public func categorySummaries(for range: DateInterval) -> [CategorySummary] {
        let currentPeriodTransactions = transactions.values.filter { range.contains($0.date) }
        let duration = range.duration
        let prevRange = DateInterval(start: range.start.addingTimeInterval(-duration), end: range.start)
        let prevPeriodTransactions = transactions.values.filter { prevRange.contains($0.date) }
        
        var summaries: [CategorySummary] = []
        let currencyCode = currentPeriodTransactions.first?.amount.currencyCode ?? "USD"
        
        for category in TransactionCategory.allCases {
            let catCurrent = currentPeriodTransactions.filter { $0.category == category }
            let totalCurrentDecimal = catCurrent.reduce(Decimal(0)) { $0 + $1.amount.value }
            let currentAmount = MoneyAmount(value: totalCurrentDecimal, currencyCode: currencyCode)
            
            let catPrev = prevPeriodTransactions.filter { $0.category == category }
            let totalPrevDecimal = catPrev.reduce(Decimal(0)) { $0 + $1.amount.value }
            
            var trend: Double? = nil
            if totalPrevDecimal != 0 {
                let change = totalCurrentDecimal - totalPrevDecimal
                let doubleChange = NSDecimalNumber(decimal: change).doubleValue
                let doublePrev = NSDecimalNumber(decimal: totalPrevDecimal).doubleValue
                trend = (doubleChange / abs(doublePrev)) * 100.0
            } else if totalCurrentDecimal != 0 {
                trend = 100.0
            }
            
            let days = duration / 86400.0
            let average: MoneyAmount?
            if days >= 28 {
                let months = days / 30.0
                average = MoneyAmount(value: totalCurrentDecimal / Decimal(months), currencyCode: currencyCode)
            } else {
                average = nil
            }
            
            summaries.append(CategorySummary(
                category: category,
                total: currentAmount,
                averagePerPeriod: average,
                trendPercentage: trend
            ))
        }
        
        return summaries
    }
    
    public func overspendAlerts(for range: DateInterval) -> [OverspendAlert] {
        var alerts: [OverspendAlert] = []
        let currencyCode = transactions.values.first?.amount.currencyCode ?? "USD"
        
        for category in TransactionCategory.allCases {
            guard category != .income else { continue }
            
            let currentTotal = transactions.values
                .filter { range.contains($0.date) && $0.category == category }
                .reduce(Decimal(0)) { $0 + $1.amount.value }
            
            let baseline = baselineForCategory(category, referenceDate: range.start)
            
            if baseline != 0 {
                let currentAbs = abs(currentTotal)
                let baselineAbs = abs(baseline)
                
                if currentAbs > baselineAbs * 1.15 {
                    let overspendPercent = ((NSDecimalNumber(decimal: currentAbs).doubleValue - NSDecimalNumber(decimal: baselineAbs).doubleValue) / NSDecimalNumber(decimal: baselineAbs).doubleValue) * 100.0
                    alerts.append(OverspendAlert(
                        category: category,
                        currentTotal: MoneyAmount(value: currentTotal, currencyCode: currencyCode),
                        baselineTotal: MoneyAmount(value: baseline, currencyCode: currencyCode),
                        overspendPercentage: overspendPercent
                    ))
                }
            }
        }
        
        return alerts
    }
    
    public func savingsOpportunities(for range: DateInterval) -> [SavingsOpportunity] {
        var opportunities: [SavingsOpportunity] = []
        let summaries = categorySummaries(for: range).filter { $0.category != .income && $0.total.value != 0 }
        let currencyCode = transactions.values.first?.amount.currencyCode ?? "USD"
        
        let sortedSummaries = summaries.sorted(by: { abs($0.total.value) > abs($1.total.value) })
        let topCategories = Array(sortedSummaries.prefix(2))
        
        for summary in topCategories {
            let category = summary.category
            let baseline = baselineForCategory(category, referenceDate: range.start)
            let currentVal = abs(summary.total.value)
            
            if baseline != 0 {
                let baselineVal = abs(baseline)
                if currentVal > baselineVal {
                    let differenceVal = currentVal - baselineVal
                    let overPercent = ((NSDecimalNumber(decimal: differenceVal).doubleValue) / NSDecimalNumber(decimal: baselineVal).doubleValue) * 100.0
                    let potentialSavings = differenceVal * 0.15
                    
                    let suggestion = "Your \(category.displayName.lowercased()) spending is \(Int(overPercent))% above baseline. Reducing by 15% could save you \(currencyCode) \(String(format: "%.2f", NSDecimalNumber(decimal: potentialSavings).doubleValue))/month."
                    
                    opportunities.append(SavingsOpportunity(
                        description: suggestion,
                        category: category,
                        estimatedMonthlySavings: MoneyAmount(value: potentialSavings, currencyCode: currencyCode)
                    ))
                }
            }
        }
        
        return opportunities
    }
    
    public func merchantClusters() -> [MerchantCluster] {
        let merchantNames = Array(Set(transactions.values.map { $0.merchantName }))
        return MerchantIntelligence.clusterMerchants(merchantNames)
    }
    
    private func baselineForCategory(_ category: TransactionCategory, referenceDate: Date) -> Decimal {
        let calendar = Calendar.current
        
        guard let threeMonthsAgo = calendar.date(byAdding: .month, value: -3, to: referenceDate),
              let sixMonthsAgo = calendar.date(byAdding: .month, value: -6, to: referenceDate) else {
            return 0
        }
        
        let baselineRange = DateInterval(start: sixMonthsAgo, end: threeMonthsAgo)
        let baselineTransactions = transactions.values.filter {
            baselineRange.contains($0.date) && $0.category == category
        }
        
        let totalSpend = baselineTransactions.reduce(Decimal(0)) { $0 + $1.amount.value }
        
        let monthsSet = Set(baselineTransactions.map { tx -> Int in
            let comps = calendar.dateComponents([.year, .month], from: tx.date)
            return (comps.year ?? 0) * 100 + (comps.month ?? 0)
        })
        
        let activeMonthsCount = max(1, monthsSet.count)
        return totalSpend / Decimal(activeMonthsCount)
    }
    
    // MARK: - Subscription Intelligence
    
    public func activeSubscriptions() -> [SubscriptionInfo] {
        return cachedActiveSubscriptions
    }
    
    public func subscriptionDetail(for merchantName: String) -> SubscriptionDetail? {
        let normQuery = MerchantLogoEngine.normalizeMerchantName(merchantName)
        return cachedSubscriptionDetails[normQuery]
    }
}
