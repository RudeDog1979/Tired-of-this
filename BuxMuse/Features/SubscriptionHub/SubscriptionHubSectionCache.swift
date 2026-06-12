//
//  SubscriptionHubSectionCache.swift
//  BuxMuse
//
//  Precomputes hub section lists off the hot view body path (same rules as before).
//

import Foundation

enum SubscriptionHubSectionCache {
    typealias RiskRow = (subName: String, risk: SubscriptionRisk)

    static func detectedRisks(from subscriptions: [SubscriptionInfo]) -> [RiskRow] {
        var list: [RiskRow] = []
        for sub in subscriptions {
            for risk in sub.risks {
                list.append((subName: sub.merchantName, risk: risk))
            }
        }

        let lowerNames = subscriptions.map { $0.merchantName.lowercased() }
        let videoServices = ["netflix", "disney", "prime video", "apple tv", "hulu", "hbo"]
        let activeVideoServices = lowerNames.filter { name in
            videoServices.contains(where: { name.contains($0) })
        }

        if activeVideoServices.count >= 3 {
            let overlayRisk = SubscriptionRisk(
                type: .overlappingFeatures,
                description: "You have \(activeVideoServices.count) active video streams (\(activeVideoServices.map { $0.capitalized }.joined(separator: ", "))). Consider consolidating.",
                severity: "medium"
            )
            list.append((subName: "Video Bundles", risk: overlayRisk))
        }

        return list
    }

    static func opportunities(
        from subscriptions: [SubscriptionInfo],
        settingsManager: AppSettingsManager
    ) -> [SavingsOpportunityItem] {
        var items: [SavingsOpportunityItem] = []

        for sub in subscriptions {
            let val = abs(sub.cost.value)
            let yearlyVal = val * 12

            let isZombie = sub.risks.contains(where: { $0.type == .zombieSubscription })
            if isZombie {
                items.append(SavingsOpportunityItem(
                    merchantName: sub.merchantName,
                    description: "Zombie subscription: Unused in 60 days.",
                    savingsPhrase: "Cancel \(sub.merchantName) → save \(settingsManager.format(yearlyVal))/year",
                    monthlySavings: val,
                    yearlySavings: yearlyVal
                ))
            }

            let lowerName = sub.merchantName.lowercased()
            if lowerName.contains("netflix") {
                items.append(SavingsOpportunityItem(
                    merchantName: sub.merchantName,
                    description: "Netflix premium has cheaper ad-supported tiers.",
                    savingsPhrase: "Downgrade tier → save \(settingsManager.format(val - 6.99))/month",
                    monthlySavings: val - 6.99,
                    yearlySavings: (val - 6.99) * 12
                ))
            } else if lowerName.contains("spotify") {
                items.append(SavingsOpportunityItem(
                    merchantName: sub.merchantName,
                    description: "Billed through Apple App Store (15% markup).",
                    savingsPhrase: "Subscribe direct → save \(settingsManager.format(val * 0.15))/month",
                    monthlySavings: val * 0.15,
                    yearlySavings: (val * 0.15) * 12
                ))
            }
        }

        if subscriptions.count >= 4 && items.isEmpty {
            let sampleVal: Decimal = 15.0
            items.append(SavingsOpportunityItem(
                merchantName: "Consolidated Bundles",
                description: "Overlapping subscriptions detected.",
                savingsPhrase: "Consolidate active services → save \(settingsManager.format(sampleVal * 12))/year",
                monthlySavings: sampleVal,
                yearlySavings: sampleVal * 12
            ))
        }

        return items
    }

    static func categoryBreakdown(
        from subscriptions: [SubscriptionInfo],
        currencyCode: String
    ) -> [CategorySubscriptionGroup] {
        var groups: [TransactionCategory: [SubscriptionInfo]] = [:]
        for sub in subscriptions {
            groups[sub.category, default: []].append(sub)
        }

        var list: [CategorySubscriptionGroup] = []
        let totalAll = subscriptions.reduce(Decimal(0)) { $0 + abs($1.cost.value) }

        for (category, subs) in groups {
            let total = subs.reduce(Decimal(0)) { $0 + abs($1.cost.value) }
            let percent = totalAll > 0
                ? (NSDecimalNumber(decimal: total).doubleValue / NSDecimalNumber(decimal: totalAll).doubleValue) * 100.0
                : 0.0

            list.append(CategorySubscriptionGroup(
                category: category,
                totalCost: MoneyAmount(value: total, currencyCode: currencyCode),
                proportion: percent,
                subscriptionsCount: subs.count
            ))
        }

        return list.sorted(by: { $0.proportion > $1.proportion })
    }
}
