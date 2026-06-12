//
//  BuxPadEscapeStack.swift
//  BuxMuse — Ordered dismiss stack for Esc / ⌘W on iPad (inspector → search → selection).
//

import SwiftUI

enum BuxPadEscapeLayer: Equatable {
    case cryptoCard
    case insightDetail
    case goalDetail
    case subscriptionHub
    case expenseSearch
    case expenseSelection
    case externalPresentation
}

enum BuxPadEscapeStack {
    @MainActor
    static func topLayer(
        navigation: NavigationCoordinator,
        goals: GoalsSheetCoordinator,
        insights: InsightsViewModel,
        padBrain: BuxPadNavigationBrain
    ) -> BuxPadEscapeLayer? {
        if navigation.selectedCryptoCard != nil { return .cryptoCard }
        if insights.showInsightDetail { return .insightDetail }
        if goals.showGoalDetail { return .goalDetail }
        if navigation.showSubscriptionHub { return .subscriptionHub }
        if navigation.isExpenseSearchPresented { return .expenseSearch }
        if padBrain.selectedExpenseId != nil { return .expenseSelection }
        if padBrain.activeExternalPresentation != nil { return .externalPresentation }
        return nil
    }

    @MainActor
    @discardableResult
    static func dismissTopLayer(
        navigation: NavigationCoordinator,
        goals: GoalsSheetCoordinator,
        insights: InsightsViewModel,
        padBrain: BuxPadNavigationBrain
    ) -> Bool {
        guard let layer = topLayer(
            navigation: navigation,
            goals: goals,
            insights: insights,
            padBrain: padBrain
        ) else { return false }

        switch layer {
        case .cryptoCard:
            navigation.selectedCryptoCard = nil
        case .insightDetail:
            insights.dismissInsightDetail()
        case .goalDetail:
            goals.dismissGoalDetail()
        case .subscriptionHub:
            navigation.closeSubscriptionHub()
        case .expenseSearch:
            navigation.dismissExpenseSearch()
        case .expenseSelection:
            padBrain.clearExpenseSelection()
        case .externalPresentation:
            padBrain.clearExternalPresentation()
        }
        return true
    }
}
