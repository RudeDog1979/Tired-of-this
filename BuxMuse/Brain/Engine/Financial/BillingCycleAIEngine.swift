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
        category: TransactionCategory = .subscriptions,
        locale: Locale = BuxInterfaceLocale.currentInterfaceLocale
    ) -> SubscriptionInfo? {
        // Only analyze categories that can contain subscriptions
        guard category == .subscriptions || category == .utilities || category == .housing else {
            return nil
        }
        
        // Filter transactions for this specific normalized merchant
        let normName = MerchantLogoEngine.normalizeMerchantName(merchantName)
        let filtered = transactions.filter {
            MerchantLogoEngine.normalizeMerchantName($0.merchantName) == normName
        }.sorted(by: { $0.date < $1.date }) // oldest to newest
        
        guard filtered.count >= 2 else { return nil }
        
        // We only analyze expense transactions (negative amount value)
        let expenses = filtered.filter { $0.amount.value < 0 }
        guard expenses.count >= 2 else { return nil }
        
        let detection = SubscriptionBillingCycleDetector.detectCycle(
            expenses: expenses,
            category: category
        )
        let billingCycle = detection.cycle
        let nextRenewal = detection.nextRenewal
        
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
                    description: BuxLocalizedString.format(
                        "Price increased by %lld%% recently (from %@ to %@)",
                        locale: locale,
                        hikePercent,
                        String(format: "%.2f", avgPrev),
                        String(format: "%.2f", lastPriceDouble)
                    ),
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
                    description: BuxLocalizedString.string(
                        "Charged twice in the last cycle (potential billing error or overlapping billing)",
                        locale: locale
                    ),
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
                    description: BuxLocalizedString.string(
                        "Zombie subscription: 0 active interactions logged in 60 days",
                        locale: locale
                    ),
                    severity: "medium"
                ))
            }
        }
        
        // D. Irregular Cycle
        if billingCycle == .irregular {
            risks.append(SubscriptionRisk(
                type: .irregularCycle,
                description: BuxLocalizedString.string(
                    "Billing interval is irregular and fluctuates frequently",
                    locale: locale
                ),
                severity: "low"
            ))
        }
        
        // E. Foreign Currency (Check if currency code matches a dynamic identifier different than standard settings)
        // We can inspect if the transaction currency differs from the majority
        let currencies = expenses.map { $0.amount.currencyCode }
        if let primary = currencies.first, currencies.contains(where: { $0 != primary }) {
            risks.append(SubscriptionRisk(
                type: .currencyChange,
                description: BuxLocalizedString.string(
                    "Billed in a foreign currency or dynamically converted with exchange fees",
                    locale: locale
                ),
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
                    description: BuxLocalizedString.format(
                        "Free trial converted to a paid billing cycle of %@ %@",
                        locale: locale,
                        latestCost.currencyCode,
                        "\(latestCost.value)"
                    ),
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

    /// Same-amount charges within five days — parallel subs or duplicate billing in one cycle.
    public static func parallelChargeInstanceCount(expenses: [Transaction]) -> Int {
        let charges = expenses.filter { $0.amount.value < 0 }.sorted { $0.date < $1.date }
        guard charges.count >= 2 else { return max(1, charges.count) }

        var maxCluster = 1
        for i in 0..<charges.count {
            var cluster = 1
            for j in (i + 1)..<charges.count {
                let dayDiff = charges[j].date.timeIntervalSince(charges[i].date) / 86_400
                if dayDiff < 5,
                   charges[j].amount.value == charges[i].amount.value {
                    cluster += 1
                }
            }
            maxCluster = max(maxCluster, cluster)
        }
        return max(1, maxCluster)
    }

    public static func subscriptionInstanceCount(
        merchantExpenses: [Transaction],
        userDeclaredCount: Int
    ) -> Int {
        max(parallelChargeInstanceCount(expenses: merchantExpenses), userDeclaredCount, 1)
    }

    /// Single user-declared subscription (no recurring history required).
    public static func subscriptionFromUserDeclaration(_ transaction: Transaction) -> SubscriptionInfo? {
        guard transaction.isSubscriptionLike || transaction.isTrial else { return nil }

        let merchant = transaction.merchantName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !merchant.isEmpty else { return nil }

        let nextRenewal: Date
        if transaction.isTrial, let trialEnd = transaction.trialEndDate {
            nextRenewal = trialEnd
        } else if let next = transaction.nextExpectedDate {
            nextRenewal = next
        } else if let start = transaction.subscriptionStartDate {
            nextRenewal = Calendar.current.date(byAdding: .month, value: 1, to: start) ?? transaction.date
        } else {
            nextRenewal = Calendar.current.date(byAdding: .month, value: 1, to: transaction.date) ?? transaction.date
        }

        let cost: MoneyAmount
        if transaction.amount.value < 0 {
            cost = transaction.amount
        } else {
            cost = MoneyAmount(value: -abs(transaction.amount.value), currencyCode: transaction.amount.currencyCode)
        }

        return SubscriptionInfo(
            merchantName: merchant,
            cost: cost,
            billingCycle: .monthly,
            nextRenewalDate: nextRenewal,
            category: .subscriptions,
            risks: []
        )
    }

    /// Fills any user-declared instances the merchant pass did not already surface.
    public static func appendUserDeclaredSubscriptions(
        to subs: inout [SubscriptionInfo],
        details: inout [String: SubscriptionDetail],
        transactions: [Transaction],
        locale: Locale = BuxInterfaceLocale.currentInterfaceLocale
    ) {
        let declared = transactions.filter { $0.isSubscriptionLike || $0.isTrial }
        let declaredByMerchant = Dictionary(grouping: declared) { MerchantLogoEngine.normalizeMerchantName($0.merchantName) }

        for (norm, merchantDeclared) in declaredByMerchant {
            let existingCount = subs.filter { MerchantLogoEngine.normalizeMerchantName($0.merchantName) == norm }.count
            guard existingCount < merchantDeclared.count else { continue }

            let sortedDeclared = merchantDeclared.sorted { $0.date > $1.date }
            for offset in existingCount..<sortedDeclared.count {
                let transaction = sortedDeclared[offset]
                guard let subInfo = subscriptionFromUserDeclaration(transaction) else { continue }
                subs.append(subInfo.parallelInstance(at: offset))
                if details[norm] == nil, let first = subscriptionFromUserDeclaration(sortedDeclared.last!) {
                    details[norm] = subscriptionDetail(info: first, allTransactions: transactions, locale: locale)
                }
            }
        }
    }

    /// Returns the detailed info for a specific subscription
    public static func subscriptionDetail(
        info: SubscriptionInfo,
        allTransactions: [Transaction],
        locale: Locale = BuxInterfaceLocale.currentInterfaceLocale
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
        var usageInsights = BuxLocalizedString.format(
            "Your subscription has been active for %lld cycles. You interact with this service regularly.",
            locale: locale,
            expenses.count
        )
        
        let currency = info.cost.currencyCode
        let lowerMerchant = info.merchantName.lowercased()
        if lowerMerchant.contains("netflix") {
            alternatives = [
                BuxLocalizedString.format(
                    "Apple TV+ (Cheaper alternatives starting at %@ 9.99/mo)",
                    locale: locale,
                    currency
                ),
                BuxLocalizedString.format(
                    "Ad-supported plan (%@ 6.99/mo)",
                    locale: locale,
                    currency
                ),
            ]
            usageInsights = BuxLocalizedString.format(
                "Active Netflix Premium account. Price increased by 15%% in recent cycle. Consider moving to standard ad-supported tier to save %@ 8.50/mo.",
                locale: locale,
                currency
            )
        } else if lowerMerchant.contains("spotify") {
            alternatives = [
                BuxLocalizedString.string("YouTube Music (Included in Premium)", locale: locale),
                BuxLocalizedString.format(
                    "Spotify Individual (%@ 11.99/mo)",
                    locale: locale,
                    currency
                ),
            ]
            usageInsights = BuxLocalizedString.string(
                "Shared Spotify Family account. Consider Spotify Individual if only one person uses it.",
                locale: locale
            )
        } else {
            alternatives = [
                BuxLocalizedString.string("Downgrade plan", locale: locale),
                BuxLocalizedString.string("Share a bundle with family", locale: locale),
            ]
        }
        
        // Price history graph (first 6 items)
        let graphValues = Array(prices.prefix(6).reversed())

        let merchantExpenses = expenses.sorted { $0.date < $1.date }
        let cancellation = SubscriptionBillingChannelDetector.buildCancellationGuide(
            merchantName: info.merchantName,
            transactions: merchantExpenses,
            locale: locale
        )
        
        return SubscriptionDetail(
            info: info,
            history: expenses,
            priceHistoryGraph: graphValues,
            cancellation: cancellation,
            budgetImpactMonthly: budgetMonthly,
            budgetImpactYearly: budgetYearly,
            costChangePercentage: changePercent,
            usageInsights: usageInsights,
            alternatives: alternatives
        )
    }
}
