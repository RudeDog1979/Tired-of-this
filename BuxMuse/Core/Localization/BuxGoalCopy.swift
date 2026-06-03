//
//  BuxGoalCopy.swift
//  BuxMuse
//
//  Localizes goal engine output stored as English source keys.
//

import Foundation

enum BuxGoalCopy {
    static func line(_ sourceKey: String, locale: Locale = BuxInterfaceLocale.currentInterfaceLocale) -> String {
        BuxLocalizedString.string(String.LocalizationValue(stringLiteral: sourceKey), locale: locale)
    }
}

extension GoalRisk {
    func localizedDescription(locale: Locale = BuxInterfaceLocale.currentInterfaceLocale) -> String {
        BuxGoalCopy.line(description, locale: locale)
    }

    func localizedSuggestedFix(locale: Locale = BuxInterfaceLocale.currentInterfaceLocale) -> String {
        BuxGoalCopy.line(suggestedFix, locale: locale)
    }
}

extension GoalOpportunity {
    func localizedDescription(locale: Locale = BuxInterfaceLocale.currentInterfaceLocale) -> String {
        BuxGoalCopy.line(description, locale: locale)
    }

    func localizedBenefit(locale: Locale = BuxInterfaceLocale.currentInterfaceLocale) -> String {
        BuxGoalCopy.line(benefit, locale: locale)
    }
}

extension GoalMomentumResult {
    func localizedStatus(locale: Locale = BuxInterfaceLocale.currentInterfaceLocale) -> String {
        BuxGoalCopy.line(statusDescription, locale: locale)
    }

    func localizedMicroActions(locale: Locale = BuxInterfaceLocale.currentInterfaceLocale) -> [String] {
        microActions.map { BuxGoalCopy.line($0, locale: locale) }
    }

    func localizedHabitActions(locale: Locale = BuxInterfaceLocale.currentInterfaceLocale) -> [String] {
        habitActions.map { BuxGoalCopy.line($0, locale: locale) }
    }
}

extension GoalTimelineScenario {
    func localizedName(locale: Locale = BuxInterfaceLocale.currentInterfaceLocale) -> String {
        BuxGoalCopy.line(name, locale: locale)
    }

    func localizedDescription(locale: Locale = BuxInterfaceLocale.currentInterfaceLocale) -> String {
        BuxGoalCopy.line(description, locale: locale)
    }

    func localizedDelayRisk(locale: Locale = BuxInterfaceLocale.currentInterfaceLocale) -> String {
        BuxGoalCopy.line(delayRisk, locale: locale)
    }
}
