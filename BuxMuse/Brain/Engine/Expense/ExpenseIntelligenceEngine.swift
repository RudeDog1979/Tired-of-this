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
        activeSubscriptions: [SubscriptionInfo] = [],
        categoriesById: [UUID: ExpenseCategoryRecord] = [:],
        locale: Locale = BuxInterfaceLocale.currentInterfaceLocale
    ) -> AnalysisResult {
        let sameMerchant = allRecords.filter {
            MerchantLogoEngine.normalizeMerchantName($0.name) == MerchantLogoEngine.normalizeMerchantName(record.name)
        }.sorted { $0.date < $1.date }

        let recurrence = detectRecurrence(record: record, history: sameMerchant)
        let subscription = detectSubscriptionLike(
            record: record,
            history: sameMerchant,
            subscriptions: activeSubscriptions,
            locale: locale
        )
        let heatZone = HeatZoneEngine.analyze(record: record, allRecords: allRecords)
        let habit = HabitSignatureEngine.generateSignature(for: record, history: sameMerchant)
        let futureImpact = FutureImpactEngine.project(amount: record.amountValue, currencyCode: record.currencyCode)
        let emotionSummary = EmotionalTaggingEngine.analyze(emotion: record.emotion, locale: locale)
        let contextSummary = ContextTaggingEngine.analyze(context: record.contextTag)
        let microCommitment = MicroCommitmentEngine.generate(for: record)
        let refund = record.isRefund
        let duplicate = detectDuplicate(record: record, allRecords: allRecords)

        var display = ExpenseIntelligenceDisplay()
        if recurrence.isRecurring, let type = recurrence.recurrenceType {
            let confidence = Int((recurrence.confidence ?? 0) * 100)
            display.recurrenceSummary = BuxLocalizedString.format(
                "Repeats %@ · %lld%% confidence",
                locale: locale,
                localizedRecurrenceType(type, locale: locale),
                confidence
            )
            if let next = recurrence.nextDate {
                display.recurrenceSummary? += BuxLocalizedString.format(
                    " · Next around %@",
                    locale: locale,
                    next.formatted(date: .abbreviated, time: .omitted)
                )
            }
        }
        if subscription.isLike {
            display.subscriptionSummary = localizedSubscriptionMessage(subscription, locale: locale)
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
            display.refundSummary = BuxLocalizedString.string(
                "Refund detected — funds returned to your wallet.",
                locale: locale
            )
        }
        if duplicate {
            display.duplicateSummary = BuxLocalizedString.string(
                "Possible duplicate charge — review this transaction.",
                locale: locale
            )
        }
        display.categoryInsight = categoryInsight(
            for: record,
            allRecords: allRecords,
            categoriesById: categoriesById,
            locale: locale
        )
        display.merchantInsight = merchantInsight(for: record, history: sameMerchant, locale: locale)
        display.goalsImpact = BuxLocalizedString.format(
            "Spending in %@ affects goal pacing.",
            locale: locale,
            record.resolvedCategoryLabel(categoriesById: categoriesById, locale: locale)
        )
        if subscription.matchesSubscription {
            display.subscriptionsImpact = BuxLocalizedString.string(
                "Matches an active subscription pattern in your hub.",
                locale: locale
            )
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
        subscriptions: [SubscriptionInfo],
        locale: Locale
    ) -> SubscriptionDetection {
        let nonSubscriptionCategories: Set<TransactionCategory> = [
            .groceries, .restaurants, .transport, .shopping, .travel, .education, .health, .personal, .other
        ]
        let norm = MerchantLogoEngine.normalizeMerchantName(record.name)
        let isKnownSubKeyword = BuxFinanceKitManager.knownSubscriptionKeywords.contains(where: { norm.contains($0) })
        
        if nonSubscriptionCategories.contains(record.transactionCategory) && !isKnownSubKeyword {
            return SubscriptionDetection(isLike: false, message: nil, matchesSubscription: false)
        }

        let matchingSubs = subscriptions.filter { MerchantLogoEngine.normalizeMerchantName($0.merchantName) == norm }
        if let match = matchingSubs.first {
            return SubscriptionDetection(
                isLike: true,
                message: BuxLocalizedString.format(
                    "Matches your %@ pattern",
                    locale: locale,
                    match.displayName
                ),
                matchesSubscription: true
            )
        }

        if let sub = BillingCycleAIEngine.analyzeSubscription(
            merchantName: record.name,
            transactions: history.map { $0.toTransaction() },
            category: record.transactionCategory,
            locale: locale
        ) {
            return SubscriptionDetection(
                isLike: true,
                message: BuxLocalizedString.format(
                    "This looks like a subscription · %@ cycle",
                    locale: locale,
                    sub.billingCycle.localizedDisplayName(locale: locale)
                ),
                matchesSubscription: true
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
                    message: BuxLocalizedString.string(
                        "Part of a monthly cycle at this merchant",
                        locale: locale
                    ),
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

    private static func categoryInsight(
        for record: ExpenseRecord,
        allRecords: [ExpenseRecord],
        categoriesById: [UUID: ExpenseCategoryRecord],
        locale: Locale
    ) -> String? {
        let label = record.resolvedCategoryLabel(categoriesById: categoriesById, locale: locale)
        let count = allRecords.filter {
            $0.resolvedCategoryLabel(categoriesById: categoriesById, locale: locale) == label
        }.count
        guard count >= 3 else { return nil }
        return BuxLocalizedString.format(
            "%@ appears often in your recent activity (%lld times).",
            locale: locale,
            label,
            count
        )
    }

    private static func merchantInsight(
        for record: ExpenseRecord,
        history: [ExpenseRecord],
        locale: Locale
    ) -> String? {
        guard history.count >= 2 else { return nil }
        return BuxLocalizedString.format(
            "You've logged %lld expenses at %@ recently.",
            locale: locale,
            history.count,
            record.name
        )
    }

    private static func localizedRecurrenceType(_ type: String, locale: Locale) -> String {
        switch type {
        case "weekly": return BuxLocalizedString.string("weekly", locale: locale)
        case "bi-weekly": return BuxLocalizedString.string("bi-weekly", locale: locale)
        case "monthly": return BuxLocalizedString.string("monthly", locale: locale)
        case "yearly": return BuxLocalizedString.string("yearly", locale: locale)
        case "irregular": return BuxLocalizedString.string("irregular", locale: locale)
        default: return type
        }
    }

    private static func localizedSubscriptionMessage(_ detection: SubscriptionDetection, locale: Locale) -> String? {
        detection.message
    }
}
