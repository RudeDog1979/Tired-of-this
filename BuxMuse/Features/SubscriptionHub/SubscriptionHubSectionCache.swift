//
//  SubscriptionHubSectionCache.swift
//  BuxMuse
//
//  Precomputes hub section lists off the hot view body path (same rules as before).
//

import Foundation

enum SubscriptionHubSectionCache {
    typealias RiskRow = (subName: String, risk: SubscriptionRisk)

    static func detectedRisks(from subscriptions: [SubscriptionInfo], locale: Locale) -> [RiskRow] {
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
            let serviceList = activeVideoServices.map { $0.capitalized }.joined(separator: ", ")
            let overlayRisk = SubscriptionRisk(
                type: .overlappingFeatures,
                description: BuxLocalizedString.format(
                    "You have %lld active video streams (%@). Consider consolidating.",
                    locale: locale,
                    activeVideoServices.count,
                    serviceList
                ),
                severity: "medium"
            )
            list.append((
                subName: BuxCatalogLabel.string("Video Bundles", locale: locale),
                risk: overlayRisk
            ))
        }

        return list
    }

    static func opportunities(
        from subscriptions: [SubscriptionInfo],
        settingsManager: AppSettingsManager,
        locale: Locale
    ) -> [SavingsOpportunityItem] {
        var items: [SavingsOpportunityItem] = []

        for sub in subscriptions {
            let val = abs(sub.cost.value)
            let yearlyVal = val * 12

            let isZombie = sub.risks.contains(where: { $0.type == .zombieSubscription })
            if isZombie {
                items.append(SavingsOpportunityItem(
                    merchantName: sub.merchantName,
                    description: BuxLocalizedString.string(
                        "Zombie subscription: Unused in 60 days.",
                        locale: locale
                    ),
                    savingsPhrase: BuxLocalizedString.format(
                        "Cancel %@ → save %@/year",
                        locale: locale,
                        sub.merchantName,
                        settingsManager.format(yearlyVal)
                    ),
                    monthlySavings: val,
                    yearlySavings: yearlyVal
                ))
            }

            let lowerName = sub.merchantName.lowercased()
            if lowerName.contains("netflix") {
                items.append(SavingsOpportunityItem(
                    merchantName: sub.merchantName,
                    description: BuxLocalizedString.string(
                        "Netflix premium has cheaper ad-supported tiers.",
                        locale: locale
                    ),
                    savingsPhrase: BuxLocalizedString.format(
                        "Downgrade tier → save %@/month",
                        locale: locale,
                        settingsManager.format(val - 6.99)
                    ),
                    monthlySavings: val - 6.99,
                    yearlySavings: (val - 6.99) * 12
                ))
            } else if lowerName.contains("spotify") {
                items.append(SavingsOpportunityItem(
                    merchantName: sub.merchantName,
                    description: BuxLocalizedString.string(
                        "Billed through Apple App Store (15% markup).",
                        locale: locale
                    ),
                    savingsPhrase: BuxLocalizedString.format(
                        "Subscribe direct → save %@/month",
                        locale: locale,
                        settingsManager.format(val * 0.15)
                    ),
                    monthlySavings: val * 0.15,
                    yearlySavings: (val * 0.15) * 12
                ))
            }
        }

        if subscriptions.count >= 4 && items.isEmpty {
            let sampleVal: Decimal = 15.0
            items.append(SavingsOpportunityItem(
                merchantName: BuxCatalogLabel.string("Consolidated Bundles", locale: locale),
                description: BuxLocalizedString.string(
                    "Overlapping subscriptions detected.",
                    locale: locale
                ),
                savingsPhrase: BuxLocalizedString.format(
                    "Consolidate active services → save %@/year",
                    locale: locale,
                    settingsManager.format(sampleVal * 12)
                ),
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
