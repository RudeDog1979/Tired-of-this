//
//  SubscriptionHubViewModel.swift
//  BuxMuse
//  Features/SubscriptionHub/
//
//  ViewModel managing local subscription analytics, timelines, burn rates, and risks.
//

import Combine
import SwiftUI

public final class SubscriptionHubViewModel: ObservableObject {
    private let engine: FinancialIntelligenceEngine
    private let settingsManager: AppSettingsManager
    
    @Published public var subscriptions: [SubscriptionInfo] = []
    
    // Cost breakdowns
    @Published public var totalMonthlyCost: MoneyAmount = MoneyAmount(value: 0, currencyCode: "USD")
    @Published public var totalYearlyCost: MoneyAmount = MoneyAmount(value: 0, currencyCode: "USD")
    @Published public var totalWeeklyCost: MoneyAmount = MoneyAmount(value: 0, currencyCode: "USD")
    @Published public var totalIrregularCost: MoneyAmount = MoneyAmount(value: 0, currencyCode: "USD")
    
    // Health and delta
    @Published public var healthScore: Int = 100
    @Published public var monthlyChangeDescription: String = "Your subscriptions are stable this month."
    
    // Timeline renewals
    @Published public var upcomingRenewals: [SubscriptionInfo] = []
    
    // Burn rates
    @Published public var dailyBurnRate: MoneyAmount = MoneyAmount(value: 0, currencyCode: "USD")
    @Published public var weeklyBurnRate: MoneyAmount = MoneyAmount(value: 0, currencyCode: "USD")
    @Published public var monthlyBurnRate: MoneyAmount = MoneyAmount(value: 0, currencyCode: "USD")
    @Published public var yearlyBurnRate: MoneyAmount = MoneyAmount(value: 0, currencyCode: "USD")
    @Published public var burnRateCancellationProjection: String = ""
    @Published public var burnRateQuarterlyIncrease: Double = 0.0
    
    // Selected states
    @Published var selectedDetail: SubscriptionDetail? = nil
    
    private var lastRecomputeFingerprint: [String] = []
    private var quarterlyIncreaseTask: Task<Void, Never>?

    public init(engine: FinancialIntelligenceEngine, settingsManager: AppSettingsManager) {
        self.engine = engine
        self.settingsManager = settingsManager
        let currency = settingsManager.selectedCurrency.id
        totalMonthlyCost = MoneyAmount(value: 0, currencyCode: currency)
        totalYearlyCost = MoneyAmount(value: 0, currencyCode: currency)
        totalWeeklyCost = MoneyAmount(value: 0, currencyCode: currency)
        totalIrregularCost = MoneyAmount(value: 0, currencyCode: currency)
        dailyBurnRate = MoneyAmount(value: 0, currencyCode: currency)
        weeklyBurnRate = MoneyAmount(value: 0, currencyCode: currency)
        monthlyBurnRate = MoneyAmount(value: 0, currencyCode: currency)
        yearlyBurnRate = MoneyAmount(value: 0, currencyCode: currency)
    }

    public func applySnapshot(_ snapshot: SubscriptionHubSnapshot, settingsManager: AppSettingsManager) {
        let fingerprint = Self.fingerprint(for: snapshot.subscriptions)
        healthScore = snapshot.healthScore
        guard fingerprint != lastRecomputeFingerprint else { return }
        lastRecomputeFingerprint = fingerprint
        subscriptions = snapshot.subscriptions
        recomputeDisplayFields(
            from: snapshot.subscriptions,
            preferredHealthScore: snapshot.healthScore
        )
    }

    public func refreshData() {
        let allSubs = engine.activeSubscriptions()
        let fingerprint = Self.fingerprint(for: allSubs)
        guard fingerprint != lastRecomputeFingerprint else { return }
        lastRecomputeFingerprint = fingerprint
        subscriptions = allSubs
        recomputeDisplayFields(from: allSubs)
    }

    private static func fingerprint(for subs: [SubscriptionInfo]) -> [String] {
        subs.map { "\($0.id)|\($0.cost.value)|\($0.nextRenewalDate.timeIntervalSince1970)" }
    }

    private func recomputeDisplayFields(
        from allSubs: [SubscriptionInfo],
        preferredHealthScore: Int? = nil
    ) {
        let currency = settingsManager.selectedCurrency.id
        
        // 1. Calculate cost breakdowns & burn rates
        var totalMonthly: Decimal = 0
        var totalYearly: Decimal = 0
        var totalWeekly: Decimal = 0
        var totalIrregular: Decimal = 0
        
        for sub in allSubs {
            let costVal = abs(sub.cost.value)
            
            // Map interval calculations
            switch sub.billingCycle {
            case .weekly:
                totalWeekly += costVal
                totalMonthly += costVal * 4.33
                totalYearly += costVal * 52.0
            case .day28:
                totalMonthly += costVal * (30.0 / 28.0)
                totalYearly += costVal * (365.0 / 28.0)
            case .day30:
                totalMonthly += costVal
                totalYearly += costVal * 12.0
            case .day31:
                totalMonthly += costVal * (30.0 / 31.0)
                totalYearly += costVal * 12.0
            case .monthly:
                totalMonthly += costVal
                totalYearly += costVal * 12.0
            case .quarterly:
                totalMonthly += costVal / 3.0
                totalYearly += costVal * 4.0
            case .semiAnnual:
                totalMonthly += costVal / 6.0
                totalYearly += costVal * 2.0
            case .yearly:
                totalMonthly += costVal / 12.0
                totalYearly += costVal
            case .irregular:
                totalIrregular += costVal
                totalMonthly += costVal // Treat irregular as monthly for safety
                totalYearly += costVal * 12.0
            }
        }
        
        self.totalMonthlyCost = MoneyAmount(value: totalMonthly, currencyCode: currency)
        self.totalYearlyCost = MoneyAmount(value: totalYearly, currencyCode: currency)
        self.totalWeeklyCost = MoneyAmount(value: totalWeekly, currencyCode: currency)
        self.totalIrregularCost = MoneyAmount(value: totalIrregular, currencyCode: currency)
        
        // 2. Health + monthly delta — prefer brain snapshot score; avoid per-sub detail fetches on scroll.
        var priceHikeSum: Decimal = 0
        for sub in allSubs {
            for risk in sub.risks where risk.type == .priceHike {
                priceHikeSum += Self.priceHikeDelta(from: risk.description)
            }
        }

        if let preferredHealthScore {
            self.healthScore = preferredHealthScore
        } else {
            self.healthScore = Self.healthScore(for: allSubs)
        }
        
        let locale = settingsManager.interfaceLocale
        if priceHikeSum > 0 {
            self.monthlyChangeDescription = BuxLocalizedString.format(
                "Your subscriptions increased by %@ this month.",
                locale: locale,
                settingsManager.format(priceHikeSum)
            )
        } else {
            self.monthlyChangeDescription = BuxLocalizedString.string(
                "Your subscriptions are fully optimized with no price hikes.",
                locale: locale
            )
        }
        
        // 3. Upcoming Renewals Timeline: sorted by renewal date
        self.upcomingRenewals = allSubs.sorted(by: { $0.nextRenewalDate < $1.nextRenewalDate })
        
        // 4. Burn Rates
        self.monthlyBurnRate = self.totalMonthlyCost
        self.yearlyBurnRate = self.totalYearlyCost
        self.weeklyBurnRate = self.totalWeeklyCost
        self.dailyBurnRate = MoneyAmount(value: totalMonthly / 30.42, currencyCode: currency)
        
        // Simulation details: "If you cancel X, burn rate drops to Y"
        if let mostExpensive = allSubs.first {
            let nextMonthly = totalMonthly - abs(mostExpensive.cost.value)
            self.burnRateCancellationProjection = BuxLocalizedString.format(
                "If you cancel %@, monthly burn rate drops to %@",
                locale: locale,
                mostExpensive.merchantName,
                settingsManager.format(nextMonthly)
            )
        } else {
            self.burnRateCancellationProjection = BuxLocalizedString.string(
                "No subscriptions active to optimize.",
                locale: locale
            )
        }
        
        // Historical increase — expensive full-transaction scan; run off the main actor.
        scheduleQuarterlyBurnIncrease(for: allSubs)
    }

    private func scheduleQuarterlyBurnIncrease(for allSubs: [SubscriptionInfo]) {
        quarterlyIncreaseTask?.cancel()
        let normalizedMerchants = Set(allSubs.map {
            MerchantLogoEngine.normalizeMerchantName($0.merchantName)
        })
        let spendRows = engine.allTransactions().compactMap { tx -> SubscriptionSpendRow? in
            guard tx.amount.value < 0 else { return nil }
            let normalized = MerchantLogoEngine.normalizeMerchantName(tx.merchantName)
            guard normalizedMerchants.contains(normalized) else { return nil }
            return SubscriptionSpendRow(date: tx.date, spend: abs(tx.amount.value))
        }

        quarterlyIncreaseTask = Task { [weak self] in
            let increase = await Task.detached(priority: .utility) {
                Self.computeQuarterlyBurnIncrease(spendRows: spendRows)
            }.value
            guard !Task.isCancelled else { return }
            self?.burnRateQuarterlyIncrease = increase
        }
    }

    private struct SubscriptionSpendRow: Sendable {
        let date: Date
        let spend: Decimal
    }

    private static func healthScore(for subs: [SubscriptionInfo]) -> Int {
        var score = 100
        for sub in subs {
            for risk in sub.risks {
                switch risk.type {
                case .priceHike: score -= 8
                case .doubleCharge: score -= 15
                case .zombieSubscription: score -= 10
                case .irregularCycle: score -= 3
                case .currencyChange: score -= 5
                default: score -= 4
                }
            }
        }
        return max(10, min(100, score))
    }

    /// Parses "(from X to Y)" price-hike copy without hitting `subscriptionDetail`.
    private static func priceHikeDelta(from description: String) -> Decimal {
        let pattern = #"from\s+([0-9]+(?:\.[0-9]+)?)\s+to\s+([0-9]+(?:\.[0-9]+)?)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(
                in: description,
                range: NSRange(description.startIndex..., in: description)
              ),
              match.numberOfRanges == 3,
              let oldRange = Range(match.range(at: 1), in: description),
              let newRange = Range(match.range(at: 2), in: description),
              let oldValue = Decimal(string: String(description[oldRange])),
              let newValue = Decimal(string: String(description[newRange])),
              newValue > oldValue
        else { return 0 }
        return newValue - oldValue
    }

    private nonisolated static func computeQuarterlyBurnIncrease(spendRows: [SubscriptionSpendRow]) -> Double {
        guard !spendRows.isEmpty else { return 0 }

        let now = Date()
        let calendar = Calendar.current
        guard let currentStart = calendar.date(byAdding: .day, value: -90, to: now),
              let previousStart = calendar.date(byAdding: .day, value: -180, to: now) else {
            return 0
        }

        let currentTotal = spendRows
            .filter { $0.date >= currentStart }
            .reduce(Decimal(0)) { $0 + $1.spend }
        let previousTotal = spendRows
            .filter { $0.date >= previousStart && $0.date < currentStart }
            .reduce(Decimal(0)) { $0 + $1.spend }

        guard previousTotal > 0 else { return 0 }

        let current = NSDecimalNumber(decimal: currentTotal).doubleValue
        let previous = NSDecimalNumber(decimal: previousTotal).doubleValue
        let increase = ((current - previous) / previous) * 100
        return increase > 0 ? increase : 0
    }

    public func loadDetail(for merchantName: String) {
        if let detail = engine.subscriptionDetail(for: merchantName) {
            self.selectedDetail = detail
        }
    }
    
    public func simulateCancel(merchantName: String) {
        // Legacy entry point — prefer BuxMuseBrain.cancelSubscription to preserve transaction history.
        let normalized = MerchantLogoEngine.normalizeMerchantName(merchantName)
        SettingsStore.shared.registerCancelledSubscription(normalizedMerchant: normalized)

        let txs = engine.allTransactions().filter {
            MerchantLogoEngine.normalizeMerchantName($0.merchantName) == normalized
        }
        for tx in txs {
            var updated = tx
            updated = Transaction(
                id: tx.id,
                date: tx.date,
                amount: tx.amount,
                merchantName: tx.merchantName,
                category: tx.category,
                notes: tx.notes,
                isSubscriptionLike: false,
                isTrial: false,
                nextExpectedDate: nil,
                subscriptionStartDate: nil,
                trialEndDate: nil
            )
            engine.updateTransaction(updated)
        }
        refreshData()
    }
}
