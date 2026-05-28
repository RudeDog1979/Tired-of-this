//
//  ExpenseIntelligenceEngine.swift
//  BuxMuse
//
//  Local expense intelligence: recurrence, subscriptions, heat zones, refunds, duplicates.
//

import Foundation

struct ExpenseIntelligenceEngine {

    struct AnalysisResult: Equatable {
        var isRecurring: Bool
        var recurrenceType: String?
        var recurrenceConfidence: Double?
        var nextExpectedDate: Date?
        var isSubscriptionLike: Bool
        var heatZoneBucket: String?
        var isRefund: Bool
        var isDuplicate: Bool
        var habitSignatureId: String?
        var microCommitmentType: String?
        var microCommitmentValue: Double?
        var futureImpact1Y: Double?
        var futureImpact5Y: Double?
        var display: ExpenseIntelligenceDisplay
    }

    static func analyze(
        record: ExpenseRecord,
        allRecords: [ExpenseRecord],
        activeSubscriptions: [SubscriptionInfo] = []
    ) -> AnalysisResult {
        let sameMerchant = allRecords.filter {
            MerchantLogoEngine.normalizeMerchantName($0.name) == MerchantLogoEngine.normalizeMerchantName(record.name)
        }.sorted { $0.date < $1.date }

        let recurrence = detectRecurrence(record: record, history: sameMerchant)
        let subscription = detectSubscriptionLike(record: record, history: sameMerchant, subscriptions: activeSubscriptions)
        let heatZone = HeatZoneEngine.analyze(record: record, allRecords: allRecords)
        let habit = HabitSignatureEngine.generateSignature(for: record, history: sameMerchant)
        let futureImpact = FutureImpactEngine.project(amount: record.amountValue, currencyCode: record.currencyCode)
        let emotionSummary = EmotionalTaggingEngine.analyze(emotion: record.emotion)
        let contextSummary = ContextTaggingEngine.analyze(context: record.contextTag)
        let microCommitment = MicroCommitmentEngine.generate(for: record)
        let refund = record.isRefund
        let duplicate = detectDuplicate(record: record, allRecords: allRecords)

        var display = ExpenseIntelligenceDisplay()
        if recurrence.isRecurring, let type = recurrence.recurrenceType {
            let confidence = Int((recurrence.confidence ?? 0) * 100)
            display.recurrenceSummary = "Repeats \(type) · \(confidence)% confidence"
            if let next = recurrence.nextDate {
                display.recurrenceSummary? += " · Next around \(next.formatted(date: .abbreviated, time: .omitted))"
            }
        }
        if subscription.isLike {
            display.subscriptionSummary = subscription.message
        }
        if let heat = heatZone.summary {
            display.heatZoneSummary = heat
        }
        if let hab = habit.summary {
            display.habitSignatureSummary = hab
        }
        display.futureImpactSummary = futureImpact.summary
        display.emotionalTagSummary = emotionSummary
        display.contextTagSummary = contextSummary
        if let mc = microCommitment {
            display.microCommitmentSummary = mc.summary
        }
        if refund {
            display.refundSummary = "Refund detected — funds returned to your wallet."
        }
        if duplicate {
            display.duplicateSummary = "Possible duplicate charge — review this transaction."
        }
        display.categoryInsight = categoryInsight(for: record, allRecords: allRecords)
        display.merchantInsight = merchantInsight(for: record, history: sameMerchant)
        display.goalsImpact = "Spending in \(record.transactionCategory.displayName) affects goal pacing."
        if subscription.matchesSubscription {
            display.subscriptionsImpact = "Matches an active subscription pattern in your hub."
        }

        return AnalysisResult(
            isRecurring: recurrence.isRecurring,
            recurrenceType: recurrence.recurrenceType,
            recurrenceConfidence: recurrence.confidence,
            nextExpectedDate: recurrence.nextDate,
            isSubscriptionLike: subscription.isLike,
            heatZoneBucket: heatZone.bucket,
            isRefund: refund,
            isDuplicate: duplicate,
            habitSignatureId: habit.id,
            microCommitmentType: microCommitment?.type,
            microCommitmentValue: microCommitment?.value,
            futureImpact1Y: futureImpact.impact1Y,
            futureImpact5Y: futureImpact.impact5Y,
            display: display
        )
    }

    // MARK: - Recurrence

    private struct RecurrenceDetection {
        var isRecurring: Bool
        var recurrenceType: String?
        var confidence: Double?
        var nextDate: Date?
        var heatBucket: String?
    }

    private static func detectRecurrence(record: ExpenseRecord, history: [ExpenseRecord]) -> RecurrenceDetection {
        let expenses = history.filter { $0.amountValue < 0 }
        guard expenses.count >= 2 else {
            return RecurrenceDetection(isRecurring: false, recurrenceType: nil, confidence: nil, nextDate: nil, heatBucket: nil)
        }

        var intervals: [TimeInterval] = []
        for i in 1..<expenses.count {
            intervals.append(expenses[i].date.timeIntervalSince(expenses[i - 1].date))
        }
        let avgDays = (intervals.reduce(0, +) / Double(intervals.count)) / 86_400

        let type: String?
        if avgDays >= 5 && avgDays <= 9 { type = "weekly" }
        else if avgDays >= 12 && avgDays <= 16 { type = "bi-weekly" }
        else if avgDays >= 25 && avgDays <= 35 { type = "monthly" }
        else if avgDays >= 350 && avgDays <= 380 { type = "yearly" }
        else if avgDays > 0 { type = "irregular" }
        else { type = nil }

        guard let type else {
            return RecurrenceDetection(isRecurring: false, recurrenceType: nil, confidence: nil, nextDate: nil, heatBucket: nil)
        }

        let confidence = min(1.0, Double(expenses.count) / 6.0)
        let last = expenses.last?.date ?? record.date
        let next: Date?
        switch type {
        case "weekly": next = Calendar.current.date(byAdding: .day, value: 7, to: last)
        case "bi-weekly": next = Calendar.current.date(byAdding: .day, value: 14, to: last)
        case "monthly": next = Calendar.current.date(byAdding: .month, value: 1, to: last)
        case "yearly": next = Calendar.current.date(byAdding: .year, value: 1, to: last)
        default: next = Calendar.current.date(byAdding: .day, value: Int(avgDays), to: last)
        }

        return RecurrenceDetection(
            isRecurring: true,
            recurrenceType: type,
            confidence: confidence,
            nextDate: next,
            heatBucket: nil
        )
    }

    // MARK: - Subscription-like

    private struct SubscriptionDetection {
        var isLike: Bool
        var message: String?
        var matchesSubscription: Bool
    }

    private static func detectSubscriptionLike(
        record: ExpenseRecord,
        history: [ExpenseRecord],
        subscriptions: [SubscriptionInfo]
    ) -> SubscriptionDetection {
        let norm = MerchantLogoEngine.normalizeMerchantName(record.name)
        if let match = subscriptions.first(where: { MerchantLogoEngine.normalizeMerchantName($0.merchantName) == norm }) {
            return SubscriptionDetection(
                isLike: true,
                message: "Matches your \(match.merchantName) pattern",
                matchesSubscription: true
            )
        }

        if let sub = BillingCycleAIEngine.analyzeSubscription(
            merchantName: record.name,
            transactions: history.map { $0.toTransaction() },
            category: record.transactionCategory
        ) {
            return SubscriptionDetection(
                isLike: true,
                message: "This looks like a subscription · \(sub.billingCycle.rawValue) cycle",
                matchesSubscription: false
            )
        }

        let expenses = history.filter { $0.amountValue < 0 }
        if expenses.count >= 2 {
            let amounts = expenses.map { abs($0.amountValue) }
            let sameAmount = Set(amounts).count == 1
            let cal = Calendar.current
            let sameDay = Set(expenses.map { cal.component(.day, from: $0.date) }).count == 1
            if sameAmount && sameDay {
                return SubscriptionDetection(
                    isLike: true,
                    message: "Part of a monthly cycle at this merchant",
                    matchesSubscription: false
                )
            }
        }

        return SubscriptionDetection(isLike: false, message: nil, matchesSubscription: false)
    }

    // MARK: - Duplicate & insights

    private static func detectDuplicate(record: ExpenseRecord, allRecords: [ExpenseRecord]) -> Bool {
        let cal = Calendar.current
        return allRecords.contains { other in
            guard other.id != record.id else { return false }
            let sameMerchant = MerchantLogoEngine.normalizeMerchantName(other.name) == MerchantLogoEngine.normalizeMerchantName(record.name)
            let sameAmount = abs(other.amountValue) == abs(record.amountValue)
            let close = abs(other.date.timeIntervalSince(record.date)) < 86_400
            let sameDay = cal.isDate(other.date, inSameDayAs: record.date)
            return sameMerchant && sameAmount && close && sameDay
        }
    }

    private static func categoryInsight(for record: ExpenseRecord, allRecords: [ExpenseRecord]) -> String? {
        let count = allRecords.filter { $0.transactionCategory == record.transactionCategory }.count
        guard count >= 3 else { return nil }
        return "\(record.transactionCategory.displayName) appears often in your recent activity (\(count) times)."
    }

    private static func merchantInsight(for record: ExpenseRecord, history: [ExpenseRecord]) -> String? {
        guard history.count >= 2 else { return nil }
        return "You've logged \(history.count) expenses at \(record.name) recently."
    }
}
