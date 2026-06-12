//
//  TaxEnvelopeModels.swift
//  BuxMuse
//
//  Tax Envelope — persisted state for set-aside jar, quarterly marks, onboarding.
//

import Foundation

public struct TaxEnvelopeDeposit: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var amount: Decimal
    public var savedAt: Date
    public var linkedEntryId: UUID?
    public var note: String?

    public init(
        id: UUID = UUID(),
        amount: Decimal,
        savedAt: Date = Date(),
        linkedEntryId: UUID? = nil,
        note: String? = nil
    ) {
        self.id = id
        self.amount = amount
        self.savedAt = savedAt
        self.linkedEntryId = linkedEntryId
        self.note = note
    }
}

public struct TaxEnvelopePaymentMark: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var periodKey: String
    public var paidAt: Date
    public var amount: Decimal

    public init(
        id: UUID = UUID(),
        periodKey: String,
        paidAt: Date = Date(),
        amount: Decimal
    ) {
        self.id = id
        self.periodKey = periodKey
        self.paidAt = paidAt
        self.amount = amount
    }
}

public struct TaxEnvelopeState: Codable, Equatable, Sendable {
    public var isEnabled: Bool
    public var onboardingCompleted: Bool
    /// Optional user override from onboarding (decimal fraction, e.g. 0.25 = 25%).
    public var recommendedSaveRateOverride: Decimal?
    public var deposits: [TaxEnvelopeDeposit]
    public var paymentMarks: [TaxEnvelopePaymentMark]

    public init(
        isEnabled: Bool = false,
        onboardingCompleted: Bool = false,
        recommendedSaveRateOverride: Decimal? = nil,
        deposits: [TaxEnvelopeDeposit] = [],
        paymentMarks: [TaxEnvelopePaymentMark] = []
    ) {
        self.isEnabled = isEnabled
        self.onboardingCompleted = onboardingCompleted
        self.recommendedSaveRateOverride = recommendedSaveRateOverride
        self.deposits = deposits
        self.paymentMarks = paymentMarks
    }
}

public struct TaxEnvelopeSetAsideResult: Equatable, Sendable {
    public var amount: Decimal
    public var rateFraction: Decimal
    public var rateSource: TaxEnvelopeRateSource
    public var catalogTaxYear: String?
    public var rulesAsOf: String?

    public init(
        amount: Decimal,
        rateFraction: Decimal,
        rateSource: TaxEnvelopeRateSource,
        catalogTaxYear: String? = nil,
        rulesAsOf: String? = nil
    ) {
        self.amount = amount
        self.rateFraction = rateFraction
        self.rateSource = rateSource
        self.catalogTaxYear = catalogTaxYear
        self.rulesAsOf = rulesAsOf
    }
}

public enum TaxEnvelopeRateSource: String, Sendable {
    case catalogAdvancePayments
    case catalogMarginalRate
    case catalogEffectiveRate
    case userOverride
    case legacyManualRates
}
