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
    /// - Parameters:
    ///   - studioEnabled: Studio tab is on.
    ///   - studioEntitled: User has Standard/Pro (or legacy) entitlement for Simple Studio.
    ///   - showStudioDiscovery: Home discovery card is visible (not dismissed).
    static func all(
        studioEnabled: Bool,
        studioEntitled: Bool = false,
        showStudioDiscovery: Bool = false
    ) -> [TutorialStepDefinition] {
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
                bodyKey: "Tap here anytime you get paid. For now, tap Next to continue — you do not need to enter anything.",
                anchor: .homeIncomeButton,
                onEnter: .selectTab(.home)
            ),
            TutorialStepDefinition(
                id: "home.expense",
                titleKey: "Add expenses",
                bodyKey: "Log what you spend after income so the ring stays meaningful. Tap Next anytime — no need to open the form.",
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
        } else if studioEntitled {
            // Opt-in coach-mark: entitled but tab still off.
            if showStudioDiscovery {
                steps.append(
                    TutorialStepDefinition(
                        id: "home.studioEnable",
                        titleKey: "Turn on Studio",
                        bodyKey: "Simple Studio is included with your plan. Turn it on from this card when you want invoices and work tools — or skip and keep Home clean.",
                        anchor: .homeStudioDiscovery,
                        onEnter: .selectTab(.home)
                    )
                )
            } else {
                steps.append(
                    TutorialStepDefinition(
                        id: "settings.studioEnable",
                        titleKey: "Turn on Studio",
                        bodyKey: "Simple Studio is included with your plan. Open Studio in Settings and turn on the Studio tab when you want work tools — or tap Next to skip.",
                        anchor: .settingsStudioRow,
                        onEnter: .showSettingsOverview
                    )
                )
            }
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
