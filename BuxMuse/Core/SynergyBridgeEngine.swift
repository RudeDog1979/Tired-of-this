//
//  SynergyBridgeEngine.swift
//  BuxMuse
//
//  Builds paired ledger rows for workspace splits and dividend transfers.
//

import Foundation

enum SynergyBridgeEngine {
    static func makeSplitPair(
        base: ExpenseRecord,
        primaryHustleId: UUID,
        secondaryHustleId: UUID,
        secondarySharePercent: Double
    ) -> [ExpenseRecord] {
        let clamped = min(99, max(1, secondarySharePercent))
        let total = abs(base.amountValue)
        let secondaryAmount = total * Decimal(clamped / 100.0)
        let primaryAmount = total - secondaryAmount
        let groupId = UUID()
        let primaryId = UUID()
        let secondaryId = UUID()
        let noteSuffix = " · Nexus split"

        let primary = copy(
            base,
            id: primaryId,
            hustleId: primaryHustleId,
            amountValue: -primaryAmount,
            bridgeGroupId: groupId,
            bridgeKind: SynergyBridgeKind.split.rawValue,
            bridgeRole: SynergyBridgeRole.splitPrimary.rawValue,
            bridgeSharePercent: 100 - clamped,
            bridgePeerExpenseId: secondaryId,
            bridgeCounterpartyHustleId: secondaryHustleId,
            notes: appendBridgeNote(base.notes, suffix: noteSuffix)
        )

        let secondary = copy(
            base,
            id: secondaryId,
            hustleId: secondaryHustleId,
            amountValue: -secondaryAmount,
            bridgeGroupId: groupId,
            bridgeKind: SynergyBridgeKind.split.rawValue,
            bridgeRole: SynergyBridgeRole.splitSecondary.rawValue,
            bridgeSharePercent: clamped,
            bridgePeerExpenseId: primaryId,
            bridgeCounterpartyHustleId: primaryHustleId,
            notes: appendBridgeNote(base.notes, suffix: noteSuffix)
        )

        return [primary, secondary]
    }

    static func makeDividendTransferPair(
        amount: Decimal,
        currencyCode: String,
        date: Date,
        label: String,
        sourceHustleId: UUID,
        targetHustleId: UUID,
        notes: String?
    ) -> [ExpenseRecord] {
        let absAmount = abs(amount)
        let groupId = UUID()
        let cleanLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = cleanLabel.isEmpty ? "Owner payout" : cleanLabel
        let outboundId = UUID()
        let inboundId = UUID()

        let outbound = ExpenseRecord(
            id: outboundId,
            name: displayName,
            amountValue: -absAmount,
            currencyCode: currencyCode,
            date: date,
            notes: appendBridgeNote(notes, suffix: " · Transfer out"),
            categoryRaw: TransactionCategory.other.rawValue,
            merchantName: displayName,
            hustleId: sourceHustleId,
            bridgeGroupId: groupId,
            bridgeKind: SynergyBridgeKind.dividendTransfer.rawValue,
            bridgeRole: SynergyBridgeRole.transferOut.rawValue,
            bridgePeerExpenseId: inboundId,
            bridgeCounterpartyHustleId: targetHustleId
        )

        let inbound = ExpenseRecord(
            id: inboundId,
            name: displayName,
            amountValue: absAmount,
            currencyCode: currencyCode,
            date: date,
            notes: appendBridgeNote(notes, suffix: " · Transfer in"),
            categoryRaw: TransactionCategory.income.rawValue,
            merchantName: displayName,
            hustleId: targetHustleId,
            bridgeGroupId: groupId,
            bridgeKind: SynergyBridgeKind.dividendTransfer.rawValue,
            bridgeRole: SynergyBridgeRole.transferIn.rawValue,
            bridgePeerExpenseId: outboundId,
            bridgeCounterpartyHustleId: sourceHustleId
        )

        return [outbound, inbound]
    }

    private static func copy(
        _ base: ExpenseRecord,
        id: UUID,
        hustleId: UUID?,
        amountValue: Decimal,
        bridgeGroupId: UUID,
        bridgeKind: String,
        bridgeRole: String,
        bridgeSharePercent: Double,
        bridgePeerExpenseId: UUID,
        bridgeCounterpartyHustleId: UUID,
        notes: String?
    ) -> ExpenseRecord {
        ExpenseRecord(
            id: id,
            name: base.name,
            amountValue: amountValue,
            currencyCode: base.currencyCode,
            categoryId: base.categoryId,
            merchantId: base.merchantId,
            date: base.date,
            notes: notes,
            isRecurring: base.isRecurring,
            recurrenceType: base.recurrenceType,
            recurrenceConfidence: base.recurrenceConfidence,
            nextExpectedDate: base.nextExpectedDate,
            isSubscriptionLike: base.isSubscriptionLike,
            isTrial: base.isTrial,
            subscriptionStartDate: base.subscriptionStartDate,
            trialEndDate: base.trialEndDate,
            renewalReminderDays: base.renewalReminderDays,
            heatZoneBucket: base.heatZoneBucket,
            emotion: base.emotion,
            contextTag: base.contextTag,
            habitSignatureId: base.habitSignatureId,
            subscriptionConfidence: base.subscriptionConfidence,
            microCommitmentType: base.microCommitmentType,
            microCommitmentValue: base.microCommitmentValue,
            futureImpact1Y: base.futureImpact1Y,
            futureImpact5Y: base.futureImpact5Y,
            createdAt: base.createdAt,
            updatedAt: base.updatedAt,
            categoryRaw: base.categoryRaw,
            merchantName: base.merchantName,
            hustleId: hustleId,
            paymentMethod: base.paymentMethod,
            isBarterExchange: base.isBarterExchange,
            barterGoodsGiven: base.barterGoodsGiven,
            barterGoodsReceived: base.barterGoodsReceived,
            barterEstimatedValue: base.barterEstimatedValue,
            bridgeGroupId: bridgeGroupId,
            bridgeKind: bridgeKind,
            bridgeRole: bridgeRole,
            bridgeSharePercent: bridgeSharePercent,
            bridgePeerExpenseId: bridgePeerExpenseId,
            bridgeCounterpartyHustleId: bridgeCounterpartyHustleId
        )
    }

    private static func appendBridgeNote(_ existing: String?, suffix: String) -> String? {
        let trimmed = (existing ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return suffix.trimmingCharacters(in: CharacterSet(charactersIn: " ·")) }
        if trimmed.contains(suffix) { return trimmed }
        return trimmed + suffix
    }
}
