//
//  TaxEnvelopeDisplays.swift
//  BuxMuse
//

import Foundation

public struct TaxSavingsHubHeroDisplay: Equatable {
    public var weekSetAsideLine: String
    public var yearProgressLine: String
    public var isEnabled: Bool
    public var needsSetup: Bool
    public var disclaimer: String

    public static let empty = TaxSavingsHubHeroDisplay(
        weekSetAsideLine: "",
        yearProgressLine: "",
        isEnabled: false,
        needsSetup: true,
        disclaimer: ""
    )
}

public struct TaxEnvelopeRootDisplay: Equatable {
    public var isEnabled: Bool
    public var needsOnboarding: Bool
    public var hubHero: TaxSavingsHubHeroDisplay
    public var weekTab: TaxEnvelopeWeekDisplay
    public var jarTab: TaxEnvelopeJarDisplay
    public var remindersTab: TaxEnvelopeRemindersDisplay
    public var countryLabel: String
    public var taxYearLabel: String?
    public var rulesAsOfLabel: String?

    public static let empty = TaxEnvelopeRootDisplay(
        isEnabled: false,
        needsOnboarding: true,
        hubHero: .empty,
        weekTab: .empty,
        jarTab: .empty,
        remindersTab: .empty,
        countryLabel: "",
        taxYearLabel: nil,
        rulesAsOfLabel: nil
    )
}

public struct TaxEnvelopeWeekDisplay: Equatable {
    public var weekIncomeFormatted: String
    public var weekSetAsideTargetFormatted: String
    public var weekSetAsideRatePercent: Int
    public var coachLine: String
    public var incomeEntryCount: Int

    public static let empty = TaxEnvelopeWeekDisplay(
        weekIncomeFormatted: "—",
        weekSetAsideTargetFormatted: "—",
        weekSetAsideRatePercent: 0,
        coachLine: "",
        incomeEntryCount: 0
    )
}

public struct TaxEnvelopeJarDisplay: Equatable {
    public var savedTotalFormatted: String
    public var targetFormatted: String
    public var progressFraction: Double
    public var recentDeposits: [TaxEnvelopeDepositRow]
    public var coachLine: String
    public var emptyStateLine: String
    public var hasDeposits: Bool

    public static let empty = TaxEnvelopeJarDisplay(
        savedTotalFormatted: "—",
        targetFormatted: "—",
        progressFraction: 0,
        recentDeposits: [],
        coachLine: "",
        emptyStateLine: "",
        hasDeposits: false
    )
}

public struct TaxEnvelopeDepositRow: Identifiable, Equatable {
    public var id: UUID
    public var amountFormatted: String
    public var dateLabel: String
    public var note: String?
}

public struct TaxEnvelopeRemindersDisplay: Equatable {
    public var nextDueDateLabel: String?
    public var nextDueAmountFormatted: String
    public var setAsideTotalFormatted: String
    public var quarterLabel: String
    public var dueAmountTitle: String
    public var periodTitle: String
    public var isCurrentPeriodPaid: Bool
    public var paymentScheduleLabel: String
    public var coachLine: String

    public static let empty = TaxEnvelopeRemindersDisplay(
        nextDueDateLabel: nil,
        nextDueAmountFormatted: "—",
        setAsideTotalFormatted: "—",
        quarterLabel: "",
        dueAmountTitle: "",
        periodTitle: "",
        isCurrentPeriodPaid: false,
        paymentScheduleLabel: "",
        coachLine: ""
    )
}

public struct TaxEnvelopeOnboardingRecommendation: Equatable {
    public var saveRatePercent: Int
    public var saveRateSource: TaxEnvelopeRateSource
    public var countryCode: String
    public var paymentSchedule: String
    public var coachLine: String
}
