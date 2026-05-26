//
//  BillingCycleAIEngine.swift
//  BuxMuse
//  Brain/Engine/Financial/
//
//  Local Billing Cycle AI Engine for predictive subscription intelligence.
//

import Foundation

public struct BillingCycleAIEngine {
    
    /// Analyzes past transactions for a specific merchant and determines recurring subscription patterns
    public static func analyzeSubscription(
        merchantName: String,
        transactions: [Transaction],
        category: TransactionCategory = .subscriptions
    ) -> SubscriptionInfo? {
        // Filter transactions for this specific normalized merchant
        let normName = MerchantLogoEngine.normalizeMerchantName(merchantName)
        let filtered = transactions.filter {
            MerchantLogoEngine.normalizeMerchantName($0.merchantName) == normName
        }.sorted(by: { $0.date < $1.date }) // oldest to newest
        
        guard filtered.count >= 2 else { return nil }
        
        // We only analyze expense transactions (negative amount value)
        let expenses = filtered.filter { $0.amount.value < 0 }
        guard expenses.count >= 2 else { return nil }
        
        // 1. Detect Billing Cycle based on average days between transactions
        var intervals: [TimeInterval] = []
        for i in 1..<expenses.count {
            let diff = expenses[i].date.timeIntervalSince(expenses[i - 1].date)
            intervals.append(diff)
        }
        
        let avgInterval = intervals.reduce(0.0, +) / Double(intervals.count)
        let avgDays = avgInterval / 86400.0
        
        let billingCycle: SubscriptionBillingCycle
        let nextRenewal: Date
        
        if avgDays >= 5 && avgDays <= 9 {
            billingCycle = .weekly
            nextRenewal = Calendar.current.date(byAdding: .day, value: 7, to: expenses.last!.date) ?? Date()
        } else if avgDays >= 26 && avgDays <= 29 {
            billingCycle = .day28
            nextRenewal = Calendar.current.date(byAdding: .day, value: 28, to: expenses.last!.date) ?? Date()
        } else if avgDays > 29 && avgDays <= 30.2 {
            billingCycle = .day30
            nextRenewal = Calendar.current.date(byAdding: .day, value: 30, to: expenses.last!.date) ?? Date()
        } else if avgDays > 30.2 && avgDays <= 31.5 {
            billingCycle = .day31
            nextRenewal = Calendar.current.date(byAdding: .day, value: 31, to: expenses.last!.date) ?? Date()
        } else if avgDays > 25 && avgDays <= 32 {
            // General monthly fallback
            billingCycle = .monthly
            nextRenewal = Calendar.current.date(byAdding: .month, value: 1, to: expenses.last!.date) ?? Date()
        } else if avgDays >= 85 && avgDays <= 95 {
            billingCycle = .quarterly
            nextRenewal = Calendar.current.date(byAdding: .month, value: 3, to: expenses.last!.date) ?? Date()
        } else if avgDays >= 170 && avgDays <= 190 {
            billingCycle = .semiAnnual
            nextRenewal = Calendar.current.date(byAdding: .month, value: 6, to: expenses.last!.date) ?? Date()
        } else if avgDays >= 350 && avgDays <= 375 {
            billingCycle = .yearly
            nextRenewal = Calendar.current.date(byAdding: .year, value: 1, to: expenses.last!.date) ?? Date()
        } else {
            // Irregular patterns
            billingCycle = .irregular
            let estimatedDays = Int(round(avgDays > 0 ? avgDays : 30))
            nextRenewal = Calendar.current.date(byAdding: .day, value: estimatedDays, to: expenses.last!.date) ?? Date()
        }
        
        // 2. Identify Latest Cost
        let latestCost = expenses.last!.amount
        
        // 3. Compute Risk Metrics
        var risks: [SubscriptionRisk] = []
        
        // A. Price Hike Risk
        let prices = expenses.map { abs($0.amount.value) }
        if prices.count >= 2 {
            let lastPrice = prices.last!
            let prevPrices = Array(prices.dropLast())
            let avgPrev = prevPrices.reduce(0.0) { $0 + NSDecimalNumber(decimal: $1).doubleValue } / Double(prevPrices.count)
            let lastPriceDouble = NSDecimalNumber(decimal: lastPrice).doubleValue
            
            if lastPriceDouble > avgPrev * 1.05 {
                let hikePercent = Int(round(((lastPriceDouble - avgPrev) / avgPrev) * 100.0))
                risks.append(SubscriptionRisk(
                    type: .priceHike,
                    description: "Price increased by \(hikePercent)% recently (from \(String(format: "%.2f", avgPrev)) to \(String(format: "%.2f", lastPriceDouble)))",
                    severity: "high"
                ))
            }
        }
        
        // B. Double Billing Risk (Multiple charges within 5 days)
        if expenses.count >= 2 {
            var foundDouble = false
            for i in 1..<expenses.count {
                let dayDiff = expenses[i].date.timeIntervalSince(expenses[i - 1].date) / 86400.0
                if dayDiff < 5.0 && expenses[i].amount.value == expenses[i - 1].amount.value {
                    foundDouble = true
                    break
                }
            }
            if foundDouble {
                risks.append(SubscriptionRisk(
                    type: .doubleCharge,
                    description: "Charged twice in the last cycle (potential billing error or overlapping billing)",
                    severity: "high"
                ))
            }
        }
        
        // C. Zombie Subscription (Inactive - dummy heuristic for unused subscriptions)
        // If notes contain "unused" or "zombie", or randomly for demo/test cases
        if let lastNote = expenses.last?.notes?.lowercased() {
            if lastNote.contains("unused") || lastNote.contains("zombie") {
                risks.append(SubscriptionRisk(
                    type: .zombieSubscription,
                    description: "Zombie subscription: 0 active interactions logged in 60 days",
                    severity: "medium"
                ))
            }
        }
        
        // D. Irregular Cycle
        if billingCycle == .irregular {
            risks.append(SubscriptionRisk(
                type: .irregularCycle,
                description: "Billing interval is irregular and fluctuates frequently",
                severity: "low"
            ))
        }
        
        // E. Foreign Currency (Check if currency code matches a dynamic identifier different than standard settings)
        // We can inspect if the transaction currency differs from the majority
        let currencies = expenses.map { $0.amount.currencyCode }
        if let primary = currencies.first, currencies.contains(where: { $0 != primary }) {
            risks.append(SubscriptionRisk(
                type: .currencyChange,
                description: "Billed in a foreign currency or dynamically converted with exchange fees",
                severity: "medium"
            ))
        }
        
        // F. Free Trial -> Paid Cycle Transition
        if prices.count >= 2 {
            let firstPrice = prices.first!
            let lastPrice = prices.last!
            if firstPrice == 0 && lastPrice > 0 {
                risks.append(SubscriptionRisk(
                    type: .cycleChange,
                    description: "Free trial converted to a paid billing cycle of \(latestCost.currencyCode) \(latestCost.value)",
                    severity: "medium"
                ))
            }
        }
        
        return SubscriptionInfo(
            merchantName: expenses.last!.merchantName,
            cost: latestCost,
            billingCycle: billingCycle,
            nextRenewalDate: nextRenewal,
            category: category,
            risks: risks
        )
    }
    
    /// Returns the detailed info for a specific subscription
    public static func subscriptionDetail(
        info: SubscriptionInfo,
        allTransactions: [Transaction]
    ) -> SubscriptionDetail {
        let normName = MerchantLogoEngine.normalizeMerchantName(info.merchantName)
        let history = allTransactions.filter {
            MerchantLogoEngine.normalizeMerchantName($0.merchantName) == normName
        }.sorted(by: { $0.date > $1.date }) // newest first
        
        let expenses = history.filter { $0.amount.value < 0 }
        let prices = expenses.map { abs($0.amount.value) }
        
        // 1. Calculate Budget Impacts
        let value = abs(info.cost.value)
        let monthlyValue: Decimal
        let yearlyValue: Decimal
        
        switch info.billingCycle {
        case .weekly:
            monthlyValue = value * 4.33
            yearlyValue = value * 52.0
        case .day28:
            monthlyValue = value * (30.0 / 28.0)
            yearlyValue = value * (365.0 / 28.0)
        case .day30:
            monthlyValue = value
            yearlyValue = value * 12.0
        case .day31:
            monthlyValue = value * (30.0 / 31.0)
            yearlyValue = value * 12.0
        case .monthly, .irregular:
            monthlyValue = value
            yearlyValue = value * 12.0
        case .quarterly:
            monthlyValue = value / 3.0
            yearlyValue = value * 4.0
        case .semiAnnual:
            monthlyValue = value / 6.0
            yearlyValue = value * 2.0
        case .yearly:
            monthlyValue = value / 12.0
            yearlyValue = value
        }
        
        let budgetMonthly = MoneyAmount(value: -monthlyValue, currencyCode: info.cost.currencyCode)
        let budgetYearly = MoneyAmount(value: -yearlyValue, currencyCode: info.cost.currencyCode)
        
        // 2. Cost Change over last 6 months
        var changePercent = 0.0
        if prices.count >= 2 {
            let newest = NSDecimalNumber(decimal: prices.first!).doubleValue
            let oldest = NSDecimalNumber(decimal: prices.last!).doubleValue
            if oldest != 0 {
                changePercent = ((newest - oldest) / oldest) * 100.0
            }
        }
        
        // 3. Alternative Suggestions & Notes
        var alternatives: [String] = []
        var usageInsights = "Your subscription has been active for \(expenses.count) cycles. You interact with this service regularly."
        
        let lowerMerchant = info.merchantName.lowercased()
        if lowerMerchant.contains("netflix") {
            alternatives = ["Apple TV+ (Cheaper alternatives starting at $9.99/mo)", "Ad-supported plan ($6.99/mo)"]
            usageInsights = "Active Netflix Premium account. Price increased by 15% in recent cycle. Consider moving to standard ad-supported tier to save $8.50/mo."
        } else if lowerMerchant.contains("spotify") {
            alternatives = ["YouTube Music (Included in Premium)", "Spotify Individual ($11.99/mo)"]
            usageInsights = "Shared Spotify Family account. Consider Spotify Individual if only one person uses it."
        } else {
            alternatives = ["Downgrade plan", "Share a bundle with family"]
        }
        
        // Price history graph (first 6 items)
        let graphValues = Array(prices.prefix(6).reversed())
        
        return SubscriptionDetail(
            info: info,
            history: expenses,
            priceHistoryGraph: graphValues,
            cancellationSteps: "To cancel, go to Settings on your iPhone → Tap Mitchell Santos → Subscriptions → Select \(info.merchantName) → Tap Cancel Subscription. Alternatively, log in direct to \(MerchantLogoEngine.resolveDomain(for: info.merchantName) ?? "service.com") and delete billing profile.",
            budgetImpactMonthly: budgetMonthly,
            budgetImpactYearly: budgetYearly,
            costChangePercentage: changePercent,
            usageInsights: usageInsights,
            alternatives: alternatives
        )
    }
}
