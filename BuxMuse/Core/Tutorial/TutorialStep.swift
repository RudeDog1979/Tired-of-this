//
//  TutorialStep.swift
//  BuxMuse
//

import Foundation

enum TutorialSheetAction: Equatable {
    case none
    case openAddIncome
    case openAddExpense
}

enum TutorialStepAction: Equatable {
    case selectTab(AppTab)
    case openSettings(SettingsDestinationType)
    case showSettingsOverview
    case presentSheet(TutorialSheetAction)
}

struct TutorialStepDefinition: Identifiable, Equatable {
    let id: String
    let titleKey: String
    let bodyKey: String
    let anchor: TutorialAnchorID?
    let onEnter: TutorialStepAction?
    let requiresStudio: Bool
    let isFinishStep: Bool

    init(
        id: String,
        titleKey: String,
        bodyKey: String,
        anchor: TutorialAnchorID?,
        onEnter: TutorialStepAction? = nil,
        requiresStudio: Bool = false,
        isFinishStep: Bool = false
    ) {
        self.id = id
        self.titleKey = titleKey
        self.bodyKey = bodyKey
        self.anchor = anchor
        self.onEnter = onEnter
        self.requiresStudio = requiresStudio
        self.isFinishStep = isFinishStep
    }
}

enum TutorialCoreSteps {
    static func all(studioEnabled: Bool) -> [TutorialStepDefinition] {
        var steps: [TutorialStepDefinition] = [
            TutorialStepDefinition(
                id: "home.welcome",
                titleKey: "Your budget ring",
                bodyKey: "Built from income you log, not your wallet balance. Log pay first, then spending.",
                anchor: .homeBudgetRing,
                onEnter: .selectTab(.home)
            ),
            TutorialStepDefinition(
                id: "home.income",
                titleKey: "Log income",
                bodyKey: "Tap here when you get paid. Each payment grows what you have left this period.",
                anchor: .homeIncomeButton,
                onEnter: .selectTab(.home)
            ),
            TutorialStepDefinition(
                id: "home.incomeSheet",
                titleKey: "Income entry",
                bodyKey: "Enter what you earned. Try it now or tap Next — both are fine.",
                anchor: .addIncomeAmount,
                onEnter: .presentSheet(.openAddIncome)
            ),
            TutorialStepDefinition(
                id: "home.expense",
                titleKey: "Add expenses",
                bodyKey: "Log what you spend. Do this after income so the ring stays meaningful.",
                anchor: .homeExpenseButton,
                onEnter: .selectTab(.home)
            ),
            TutorialStepDefinition(
                id: "home.debt",
                titleKey: "Track debt",
                bodyKey: "Optional. Turn on consumer debt tracking to log loans, cards, and informal lenders.",
                anchor: .homeDebtDiscovery,
                onEnter: .selectTab(.home)
            ),
            TutorialStepDefinition(
                id: "expense.sheetIntro",
                titleKey: "Merchant",
                bodyKey: "Name the store. Pick a suggestion or add a new one.",
                anchor: .addExpenseMerchant,
                onEnter: .presentSheet(.openAddExpense)
            ),
            TutorialStepDefinition(
                id: "expense.category",
                titleKey: "Category",
                bodyKey: "Organizes spending. Housing and utilities are essentials — they do not shrink your fun-money ring.",
                anchor: .addExpenseCategory
            ),
            TutorialStepDefinition(
                id: "expense.scan",
                titleKey: "Receipt scan",
                bodyKey: "Optional. On-device OCR fills merchant, date, and total.",
                anchor: .addExpenseScan
            ),
            TutorialStepDefinition(
                id: "expense.save",
                titleKey: "Save",
                bodyKey: "Your expense appears on Home and in Expenses. Next is fine without saving.",
                anchor: .addExpenseSave
            ),
            TutorialStepDefinition(
                id: "settings.intro",
                titleKey: "Settings",
                bodyKey: "Control budget rules, Studio, look and feel, profile, and backups here.",
                anchor: .settingsOverview,
                onEnter: .selectTab(.settings)
            ),
            TutorialStepDefinition(
                id: "settings.budget",
                titleKey: "Budget",
                bodyKey: "Pay cycle, optional spending cap, budget counts, and warnings.",
                anchor: .settingsBudgetRow,
                onEnter: .showSettingsOverview
            ),
            TutorialStepDefinition(
                id: "settings.budgetDetail",
                titleKey: "Pay period and cap",
                bodyKey: "Match when you get paid. Cap at zero uses your full logged income.",
                anchor: .settingsBudgetPayPeriod,
                onEnter: .openSettings(.budgets)
            ),
            TutorialStepDefinition(
                id: "settings.studio",
                titleKey: "Studio settings",
                bodyKey: "Turn on Simple or Pro Studio, connect work income to Home, and manage invoices and tax tools.",
                anchor: .settingsStudioDetail,
                onEnter: .openSettings(.studio)
            ),
            TutorialStepDefinition(
                id: "settings.appearance",
                titleKey: "Themes",
                bodyKey: "Accent color, glass look, and motion. Make BuxMuse yours.",
                anchor: .settingsAppearanceDetail,
                onEnter: .openSettings(.appearance)
            ),
            TutorialStepDefinition(
                id: "settings.backup",
                titleKey: "Backup",
                bodyKey: "Encrypted on-device archives. Manage backup reminders here.",
                anchor: .settingsBackupDetail,
                onEnter: .openSettings(.data)
            ),
        ]

        if studioEnabled {
            steps.append(contentsOf: [
                TutorialStepDefinition(
                    id: "studio.tab",
                    titleKey: "Studio tab",
                    bodyKey: "Separate ledger for client work. Home budget can include Studio income without double counting.",
                    anchor: .studioHubHeader,
                    onEnter: .selectTab(.studio),
                    requiresStudio: true
                ),
                TutorialStepDefinition(
                    id: "studio.simpleMoney",
                    titleKey: "Work income",
                    bodyKey: "Log gigs and payments here. Optionally bridge to Home budget in Settings.",
                    anchor: .studioMoneyEntry,
                    onEnter: .selectTab(.studio),
                    requiresStudio: true
                ),
            ])
        }

        steps.append(contentsOf: [
            TutorialStepDefinition(
                id: "home.expensesTab",
                titleKey: "Expenses tab",
                bodyKey: "Full history, search, filters, and merchant breakdown.",
                anchor: .expensesTabHeader,
                onEnter: .selectTab(.expense)
            ),
            TutorialStepDefinition(
                id: "home.finish",
                titleKey: "You're set",
                bodyKey: "Log income each pay period, add expenses as you go, and tune Settings anytime.",
                anchor: .homeFinish,
                onEnter: .selectTab(.home),
                isFinishStep: true
            ),
        ])

        return steps
    }
}
