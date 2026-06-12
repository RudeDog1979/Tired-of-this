//
//  BuxPadNavigationBrainTests.swift
//

import Foundation
import Testing
@testable import BuxMuse

@MainActor
struct BuxPadNavigationBrainTests {

    @Test func expenseSelection_setsId() {
        let brain = BuxPadNavigationBrain()
        let id = UUID()
        brain.selectExpense(id)
        #expect(brain.selectedExpenseId == id)
    }

    @Test func presentationPolicy_expenseDetail_regular_isSplitColumn() {
        let surface = BuxAdaptivePresentation.surface(
            for: .expenseDetail,
            layoutMode: .regular,
            isPad: true
        )
        #expect(surface == .splitColumn)
    }

    @Test func presentationPolicy_expenseDetail_compact_isSplitColumn() {
        let surface = BuxAdaptivePresentation.surface(
            for: .expenseDetail,
            layoutMode: .compact,
            isPad: true
        )
        #expect(surface == .splitColumn)
    }

    @Test func padLayout_margins() {
        #expect(BuxPadLayout.horizontalMargin(layoutMode: .compact) == 16)
        #expect(BuxPadLayout.horizontalMargin(layoutMode: .regular) == 24)
    }

    @Test func padLayout_compactSidebarNarrowerThanRegular() {
        #expect(BuxPadLayout.splitSidebarIdeal(for: .compact) < BuxPadLayout.splitSidebarIdeal(for: .regular))
    }

    @Test func overlayRouter_subscription_regular_isSplitColumn() {
        let surface = BuxPadOverlayRouter.surface(for: .subscriptionHub, layoutMode: .regular)
        #expect(surface == .splitColumn)
    }

    @Test func overlayRouter_subscription_compact_isSplitColumn() {
        let surface = BuxPadOverlayRouter.surface(for: .subscriptionHub, layoutMode: .compact)
        #expect(surface == .splitColumn)
    }

    @Test func overlayRouter_goalDetail_compact_isSplitColumn() {
        let surface = BuxPadOverlayRouter.surface(for: .goalDetail, layoutMode: .compact)
        #expect(surface == .splitColumn)
    }

    @Test func keyboardCommand_incrementsToken() {
        let brain = BuxPadNavigationBrain()
        let before = brain.keyboardCommandToken
        brain.postPadKeyboardCommand(.focusSearch)
        #expect(brain.keyboardCommandToken == before + 1)
        #expect(brain.lastKeyboardCommand == .focusSearch)
    }

    @Test func adjacentExpenseSelection_cyclesList() {
        let brain = BuxPadNavigationBrain()
        let a = UUID()
        let b = UUID()
        let records = [
            ExpenseRecord(id: a, name: "A", amountValue: 1, currencyCode: "USD", date: Date(), categoryRaw: "food", merchantName: "A"),
            ExpenseRecord(id: b, name: "B", amountValue: 2, currencyCode: "USD", date: Date(), categoryRaw: "food", merchantName: "B")
        ]
        brain.selectExpense(a)
        brain.selectAdjacentExpense(in: records, direction: 1)
        #expect(brain.selectedExpenseId == b)
        brain.selectAdjacentExpense(in: records, direction: -1)
        #expect(brain.selectedExpenseId == a)
    }

    @Test func keyboardContext_updatesFromTab() {
        let brain = BuxPadNavigationBrain()
        brain.updateKeyboardContext(selectedTab: .studio, studioMode: .simple, studioDestination: "home")
        #expect(brain.keyboardContext.selectedTab == .studio)
        #expect(brain.keyboardContext.newItemMenuTitle == "Log Time")
    }

    @Test @MainActor func escapeStack_prioritizesInspectorsOverSearch() {
        let navigation = NavigationCoordinator()
        let goals = GoalsSheetCoordinator()
        let padBrain = BuxPadNavigationBrain()
        let financialEngine = LocalFinancialIntelligenceEngine18()
        let goalsVM = GoalsViewModel(goalsEngine: GoalsEngine(), financialEngine: financialEngine)
        let insights = InsightsViewModel(
            insightsEngine: InsightsEngine(),
            financialEngine: financialEngine,
            goalsViewModel: goalsVM,
            appSettingsManager: AppSettingsManager()
        )

        navigation.showSubscriptionHub = true
        navigation.isExpenseSearchPresented = true

        #expect(
            BuxPadEscapeStack.topLayer(
                navigation: navigation,
                goals: goals,
                insights: insights,
                padBrain: padBrain
            ) == .subscriptionHub
        )

        _ = BuxPadEscapeStack.dismissTopLayer(
            navigation: navigation,
            goals: goals,
            insights: insights,
            padBrain: padBrain
        )
        #expect(navigation.showSubscriptionHub == false)
        #expect(navigation.isExpenseSearchPresented)
    }

    @Test @MainActor func sceneRegistry_detectsAuxiliaryBrains() {
        let primary = BuxPadNavigationBrain()
        let registry = BuxPadSceneBrainRegistry(primaryBrain: primary)
        let auxiliary = registry.brain(for: UUID())
        #expect(registry.isAuxiliary(auxiliary))
        #expect(!registry.isAuxiliary(primary))
    }
}
