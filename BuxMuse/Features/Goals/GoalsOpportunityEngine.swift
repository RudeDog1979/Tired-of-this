//
//  GoalsOpportunityEngine.swift
//  BuxMuse
//  Features/Goals/
//
//  Identifies budget margins, subscription trims, and categories to accelerate goals.
//

import Foundation

public struct GoalOpportunity: Codable, Equatable, Identifiable {
    public let id: UUID
    public let description: String
    public let benefit: String
    public let potentialSavings: Decimal

    public init(id: UUID = UUID(), description: String, benefit: String, potentialSavings: Decimal) {
        self.id = id
        self.description = description
        self.benefit = benefit
        self.potentialSavings = potentialSavings
    }
}

public final class GoalsOpportunityEngine {

    public init() {}

    public func findOpportunities(
        goal: Goal,
        transactions: [Transaction],
        activeSubscriptions: [SubscriptionInfo],
        savingsOpportunities: [SavingsOpportunity],
        locale: Locale = BuxInterfaceLocale.currentInterfaceLocale
    ) -> [GoalOpportunity] {
        var list: [GoalOpportunity] = []
        let remaining = max(0, goal.targetAmount - goal.currentAmount)
        guard remaining > 0 else { return [] }

        let projectionEngine = GoalsProjectionEngine()
        let currentProj = projectionEngine.project(
            goal: goal,
            transactions: transactions,
            activeSubscriptions: activeSubscriptions
        )
        let monthsToExpected = max(1.0, currentProj.expectedCompletionDate.timeIntervalSinceNow / (30.0 * 86400.0))

        if let topSub = activeSubscriptions.first {
            let cost = abs(topSub.cost.value)
            let newSavingsRate = currentProj.recommendedContribution + cost
            let newMonthsToComplete = NSDecimalNumber(decimal: remaining / newSavingsRate).doubleValue
            let monthDifference = max(0.5, monthsToExpected - newMonthsToComplete)
            let formatDiff = String(format: "%.1f", monthDifference)
            list.append(GoalOpportunity(
                description: BuxLocalizedString.format(
                    "Cancel your unused %@ subscription.",
                    locale: locale,
                    topSub.merchantName
                ),
                benefit: BuxLocalizedString.format(
                    "Redirect %@/mo to reach your goal %@ months earlier.",
                    locale: locale,
                    "\(cost)",
                    formatDiff
                ),
                potentialSavings: cost
            ))
        }

        if let topCategoryOpportunity = savingsOpportunities.first {
            let savings = topCategoryOpportunity.estimatedMonthlySavings?.value ?? 0
            if savings > 0 {
                let newSavingsRate = currentProj.recommendedContribution + savings
                let newMonthsToComplete = NSDecimalNumber(decimal: remaining / newSavingsRate).doubleValue
                let monthDifference = max(0.5, monthsToExpected - newMonthsToComplete)
                let formatDiff = String(format: "%.1f", monthDifference)
                let categoryName = topCategoryOpportunity.category?.localizedDisplayName(locale: locale).lowercased()
                    ?? BuxLocalizedString.string("other", locale: locale)
                list.append(GoalOpportunity(
                    description: BuxLocalizedString.format(
                        "Trim %@ expenses by 15%%.",
                        locale: locale,
                        categoryName
                    ),
                    benefit: BuxLocalizedString.format(
                        "Redirect %@/mo to finish %@ months earlier.",
                        locale: locale,
                        "\(savings)",
                        formatDiff
                    ),
                    potentialSavings: savings
                ))
            }
        }

        let calendar = Calendar.current
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let windfalls = transactions.filter {
            $0.date >= thirtyDaysAgo &&
            $0.category == .income &&
            $0.amount.value > 500.0 &&
            !$0.merchantName.lowercased().contains("salary") &&
            !$0.merchantName.lowercased().contains("payroll")
        }

        if let largeWindfall = windfalls.first {
            let value = largeWindfall.amount.value
            let remainingAfterWindfall = max(0, remaining - value)
            let newMonthsToComplete = NSDecimalNumber(decimal: remainingAfterWindfall / currentProj.recommendedContribution).doubleValue
            let monthDifference = max(0.5, monthsToExpected - newMonthsToComplete)
            let formatDiff = String(format: "%.1f", monthDifference)
            list.append(GoalOpportunity(
                description: BuxLocalizedString.format(
                    "Redirect recent windfall from %@ to your goal.",
                    locale: locale,
                    largeWindfall.merchantName
                ),
                benefit: BuxLocalizedString.format(
                    "Reach your goal %@ months earlier with a one-time %@ deposit.",
                    locale: locale,
                    formatDiff,
                    "\(value)"
                ),
                potentialSavings: value
            ))
        }

        if list.isEmpty {
            let suggestedSmallSaving = goal.targetAmount * 0.02
            let monthlySavings = suggestedSmallSaving
            let newSavingsRate = currentProj.recommendedContribution + monthlySavings
            let newMonthsToComplete = NSDecimalNumber(decimal: remaining / newSavingsRate).doubleValue
            let monthDifference = max(0.5, monthsToExpected - newMonthsToComplete)
            let formatDiff = String(format: "%.1f", monthDifference)
            list.append(GoalOpportunity(
                description: BuxLocalizedString.format(
                    "Save an extra %@/mo by packing your own lunch.",
                    locale: locale,
                    "\(monthlySavings)"
                ),
                benefit: BuxLocalizedString.format(
                    "Accelerate your completion timeline by %@ months.",
                    locale: locale,
                    formatDiff
                ),
                potentialSavings: monthlySavings
            ))
        }

        return list
    }
}
