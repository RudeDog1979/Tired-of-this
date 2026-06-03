//
//  GoalsMomentumEngine.swift
//  BuxMuse
//  Features/Goals/
//
//  Tracks deposit frequencies and contribution velocity to calculate a momentum index.
//

import Foundation

public struct GoalMomentumResult {
    public let score: Double // -1.0 to 1.0
    public let statusDescription: String
    public let microActions: [String]
    public let habitActions: [String]
}

public final class GoalsMomentumEngine {

    public init() {}

    public func computeMomentum(
        goal: Goal,
        currencyCode: String = AppSettingsManager.preferredCurrencyCode,
        locale: Locale = BuxInterfaceLocale.currentInterfaceLocale
    ) -> GoalMomentumResult {
        let contributions = goal.contributions.sorted(by: { $0.date > $1.date })
        let now = Date()
        let format = { (amount: Decimal) in
            AppSettingsManager.format(
                amount: amount,
                currency: AppSettingsManager.currencySetting(for: currencyCode)
            )
        }

        guard !contributions.isEmpty else {
            let daysSinceCreated = now.timeIntervalSince(goal.createdAt) / 86400.0
            let score = daysSinceCreated > 14 ? -0.5 : 0.0
            let status = daysSinceCreated > 14
                ? BuxLocalizedString.string("Stalled", locale: locale)
                : BuxLocalizedString.string("Awaiting Kickstart", locale: locale)
            return GoalMomentumResult(
                score: score,
                statusDescription: status,
                microActions: [
                    BuxLocalizedString.format("Deposit %@ today to initialize momentum.", locale: locale, format(10)),
                    BuxLocalizedString.string("Set a calendar reminder for weekly goal updates.", locale: locale),
                ],
                habitActions: [
                    BuxLocalizedString.string("Form a weekly check-in habit to review cash flow.", locale: locale),
                    BuxLocalizedString.string("Match non-essential treats (like coffee) with a goal contribution.", locale: locale),
                ]
            )
        }

        let thirtyDaysAgo = now.addingTimeInterval(-30.0 * 86400.0)
        let sixtyDaysAgo = now.addingTimeInterval(-60.0 * 86400.0)

        let recentContributions = contributions.filter { $0.date >= thirtyDaysAgo }
        let prevContributions = contributions.filter { $0.date >= sixtyDaysAgo && $0.date < thirtyDaysAgo }

        let recentSum = recentContributions.reduce(Decimal(0)) { $0 + $1.amount }
        let prevSum = prevContributions.reduce(Decimal(0)) { $0 + $1.amount }

        let recentSumDouble = NSDecimalNumber(decimal: recentSum).doubleValue
        let prevSumDouble = NSDecimalNumber(decimal: prevSum).doubleValue

        var score: Double = 0.0
        var status = BuxLocalizedString.string("Consistent Momentum", locale: locale)
        var micro: [String] = []
        var habit: [String] = []

        if recentSumDouble == 0 && prevSumDouble == 0 {
            score = -0.8
            status = BuxLocalizedString.string("Stalled", locale: locale)
            micro = [
                BuxLocalizedString.format("Make a small %@ micro-contribution to break the dry spell.", locale: locale, format(5)),
                BuxLocalizedString.string("Review your budget to see where cash has been leak-drained.", locale: locale),
            ]
            habit = [
                BuxLocalizedString.format("Automate a micro-savings deposit of %@ per day.", locale: locale, format(1)),
                BuxLocalizedString.string("Link savings goals to positive daily habits.", locale: locale),
            ]
        } else if recentSumDouble > 0 && prevSumDouble == 0 {
            score = 0.6
            status = BuxLocalizedString.string("Accelerating", locale: locale)
            micro = [
                BuxLocalizedString.format("Double down! Try to add another %@ while in this active streak.", locale: locale, format(20)),
                BuxLocalizedString.string("Share your savings milestone with a trusted partner.", locale: locale),
            ]
            habit = [
                BuxLocalizedString.string("Keep this active momentum high by saving at the beginning of the week.", locale: locale),
                BuxLocalizedString.string("Build a 3-week streak of consecutive contributions.", locale: locale),
            ]
        } else if recentSumDouble == 0 && prevSumDouble > 0 {
            score = -0.4
            status = BuxLocalizedString.string("Slowing Down", locale: locale)
            micro = [
                BuxLocalizedString.format("Re-engage today by allocating just %@ to this goal.", locale: locale, format(10)),
                BuxLocalizedString.string("Audit recent purchases to identify saving leakages.", locale: locale),
            ]
            habit = [
                BuxLocalizedString.string("Reschedule savings day to align precisely with your payday.", locale: locale),
                BuxLocalizedString.string("Avoid the 'all-or-nothing' mindset: small regular steps outperform large rare steps.", locale: locale),
            ]
        } else {
            let ratio = recentSumDouble / prevSumDouble
            if ratio > 1.15 {
                score = min(1.0, 0.5 + (ratio - 1.0))
                status = BuxLocalizedString.string("Accelerating", locale: locale)
                micro = [
                    BuxLocalizedString.string("Excellent progress! Consider locking in a portion of this month's extra savings.", locale: locale),
                    BuxLocalizedString.string("Review if your target date can be pulled forward.", locale: locale),
                ]
                habit = [
                    BuxLocalizedString.string("Increase your auto-saving amount by 5% to harness your momentum.", locale: locale),
                    BuxLocalizedString.string("Reward yourself with a small, free celebration for accelerated pacing.", locale: locale),
                ]
            } else if ratio < 0.85 {
                score = max(-0.6, -0.2 - (1.0 - ratio))
                status = BuxLocalizedString.string("Slowing Down", locale: locale)
                micro = [
                    BuxLocalizedString.string("Adjust your milestone targets slightly to feel less pressure.", locale: locale),
                    BuxLocalizedString.format("Audit subscriptions to redirect a quick %@ today.", locale: locale, format(15)),
                ]
                habit = [
                    BuxLocalizedString.string("Try 'zero-spend days' once a week to free up cash.", locale: locale),
                    BuxLocalizedString.string("Keep contributions recurring to remove friction.", locale: locale),
                ]
            } else {
                score = 0.4
                status = BuxLocalizedString.string("Consistent Momentum", locale: locale)
                micro = [
                    BuxLocalizedString.string("Maintain this excellent, stable velocity with your regular deposit.", locale: locale),
                    BuxLocalizedString.string("Confirm your current cash reserves are healthy.", locale: locale),
                ]
                habit = [
                    BuxLocalizedString.string("Establish a permanent auto-contribution so you don't even have to think about it.", locale: locale),
                    BuxLocalizedString.string("Maintain the 'pay yourself first' golden rule.", locale: locale),
                ]
            }
        }

        return GoalMomentumResult(
            score: score,
            statusDescription: status,
            microActions: micro,
            habitActions: habit
        )
    }
}
