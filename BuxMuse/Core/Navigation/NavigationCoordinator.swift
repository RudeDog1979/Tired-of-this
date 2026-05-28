//
//  NavigationCoordinator.swift
//  BuxMuse
//
//  UI routing state only — no business data.
//

import SwiftUI
import Combine

@MainActor
final class NavigationCoordinator: ObservableObject {
    @Published var selectedTab: AppTab = .home
    @Published var showSubscriptionHub: Bool = false
    @Published var selectedCryptoCard: String? = nil
    @Published var isScreenLoaded: Bool = false
    @Published var isTransactionsExpanded: Bool = false
    @Published var activeCategoryPill: String = "Expenses"
    @Published var isBalanceVisible: Bool = true
    /// Driven by bottom search accessory (iOS 26) or toolbar search button (iOS 18).
    @Published var isExpenseSearchPresented: Bool = false

    /// Increments when user selects a tab — drives tab-bar icon animations.
    @Published private(set) var tabSelectionTick: Int = 0

    init() {}

    func registerTabSelection() {
        tabSelectionTick += 1
    }

    func restore(tab: AppTab, activeCategory: String, isBalanceVisible: Bool) {
        selectedTab = tab
        activeCategoryPill = activeCategory
        self.isBalanceVisible = isBalanceVisible
    }

    func openExpensesTab() {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            selectedTab = .expense
            isTransactionsExpanded = false
        }
    }

    func openSubscriptionHub() {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            showSubscriptionHub = true
        }
    }

    func closeSubscriptionHub() {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            showSubscriptionHub = false
        }
    }

    func dismissExpenseSearch() {
        isExpenseSearchPresented = false
    }

    /// Set when the Studio timer Live Activity is tapped (`buxmuse://studio/log-time`).
    @Published var openStudioLogTimeRequest = false

    func openStudioLogTime() {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            selectedTab = .studio
            openStudioLogTimeRequest = true
        }
    }

    func consumeStudioLogTimeRequest() -> Bool {
        guard openStudioLogTimeRequest else { return false }
        openStudioLogTimeRequest = false
        return true
    }
}
