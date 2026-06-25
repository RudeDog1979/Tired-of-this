//
//  SubscriptionBillingCycleDetector.swift
//  BuxMuse — conservative subscription interval detection (defaults monthly).
//

import Foundation

enum SubscriptionBillingCycleDetector {

    /// Collapses pending/cleared or import duplicates within a few days.
    static func dedupedExpenseCharges(_ expenses: [Transaction]) -> [Transaction] {
        let charges = expenses
            .filter { $0.amount.value < 0 }
            .sorted { $0.date < $1.date }
        guard charges.count >= 2 else { return charges }

        var merged: [Transaction] = []
        for charge in charges {
            if let last = merged.last,
               abs(last.amount.value) == abs(charge.amount.value),
               charge.date.timeIntervalSince(last.date) / 86_400 <= 4 {
                continue
            }
            merged.append(charge)
        }
        return merged
    }

    static func detectCycle(
        expenses: [Transaction],
        category: TransactionCategory = .subscriptions
    ) -> (cycle: SubscriptionBillingCycle, nextRenewal: Date) {
        let sorted = dedupedExpenseCharges(expenses)
        let calendar = Calendar.current

        guard let lastCharge = sorted.last else {
            let fallback = Date()
            return (.monthly, calendar.date(byAdding: .month, value: 1, to: fallback) ?? fallback)
        }

        guard sorted.count >= 2 else {
            return (.monthly, calendar.date(byAdding: .month, value: 1, to: lastCharge.date) ?? lastCharge.date)
        }

        let intervals = intervalDays(for: sorted)
        let spanDays = lastCharge.date.timeIntervalSince(sorted.first!.date) / 86_400
        let median = medianValue(intervals)
        let chargeCount = sorted.count

        if chargeCount == 2, spanDays < 45 {
            return (.monthly, calendar.date(byAdding: .month, value: 1, to: lastCharge.date) ?? lastCharge.date)
        }

        if chargeCount == 2 {
            if median >= 350, median <= 380 {
                return (.yearly, calendar.date(byAdding: .year, value: 1, to: lastCharge.date) ?? lastCharge.date)
            }
            if median >= 25, median <= 35 {
                return (.monthly, calendar.date(byAdding: .month, value: 1, to: lastCharge.date) ?? lastCharge.date)
            }
            return (.monthly, calendar.date(byAdding: .month, value: 1, to: lastCharge.date) ?? lastCharge.date)
        }

        let spread = standardDeviation(intervals)

        if median >= 350, median <= 380 {
            return (.yearly, calendar.date(byAdding: .year, value: 1, to: lastCharge.date) ?? lastCharge.date)
        }
        if median >= 170, median <= 190, chargeCount >= 3 {
            return (.semiAnnual, calendar.date(byAdding: .month, value: 6, to: lastCharge.date) ?? lastCharge.date)
        }
        if median >= 85, median <= 95, chargeCount >= 3 {
            return (.quarterly, calendar.date(byAdding: .month, value: 3, to: lastCharge.date) ?? lastCharge.date)
        }
        if median >= 6, median <= 8, chargeCount >= 3, spread < 1.5 {
            return (.weekly, calendar.date(byAdding: .day, value: 7, to: lastCharge.date) ?? lastCharge.date)
        }
        if median >= 26, median <= 29 {
            return (.day28, calendar.date(byAdding: .day, value: 28, to: lastCharge.date) ?? lastCharge.date)
        }
        if median > 29, median <= 30.2 {
            return (.day30, calendar.date(byAdding: .day, value: 30, to: lastCharge.date) ?? lastCharge.date)
        }
        if median > 30.2, median <= 31.5 {
            return (.day31, calendar.date(byAdding: .day, value: 31, to: lastCharge.date) ?? lastCharge.date)
        }
        if median >= 25, median <= 35 {
            return (.monthly, calendar.date(byAdding: .month, value: 1, to: lastCharge.date) ?? lastCharge.date)
        }

        if category == .subscriptions || category == .utilities || category == .housing {
            return (.monthly, calendar.date(byAdding: .month, value: 1, to: lastCharge.date) ?? lastCharge.date)
        }

        let estimatedDays = Int(round(median > 0 ? median : 30))
        return (
            .irregular,
            calendar.date(byAdding: .day, value: estimatedDays, to: lastCharge.date) ?? lastCharge.date
        )
    }

    private static func intervalDays(for sortedCharges: [Transaction]) -> [Double] {
        guard sortedCharges.count >= 2 else { return [] }
        var intervals: [Double] = []
        for index in 1..<sortedCharges.count {
            intervals.append(sortedCharges[index].date.timeIntervalSince(sortedCharges[index - 1].date) / 86_400)
        }
        return intervals
    }

    private static func medianValue(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let mid = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[mid - 1] + sorted[mid]) / 2
        }
        return sorted[mid]
    }

    private static func standardDeviation(_ values: [Double]) -> Double {
        guard values.count >= 2 else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.reduce(0) { $0 + pow($1 - mean, 2) } / Double(values.count)
        return sqrt(variance)
    }
}
