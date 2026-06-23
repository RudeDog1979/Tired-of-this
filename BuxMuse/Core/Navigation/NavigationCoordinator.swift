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
    @Published var pendingExpenseFilter: ExpenseFilterState?

    init() {}

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

    func openExpensesForEnvelope(
        categoryId: UUID?,
        systemCategoryRaw: String?,
        periodStart: Date?,
        periodEnd: Date?
    ) {
        var filters = ExpenseFilterState()
        filters.categoryId = categoryId
        filters.systemCategoryRaw = systemCategoryRaw
        filters.dateFrom = periodStart
        filters.dateTo = periodEnd
        pendingExpenseFilter = filters
        openExpensesTab()
    }

    func consumePendingExpenseFilter() -> ExpenseFilterState? {
        defer { pendingExpenseFilter = nil }
        return pendingExpenseFilter
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

    // MARK: - iPad keyboard routing (UI only — no-op on iPhone)

    @Published private(set) var padKeyboardNewExpenseToken: Int = 0
    @Published private(set) var padKeyboardFocusSearchToken: Int = 0

    func requestPadNewExpense() {
        guard BuxPadIdiom.isPad else { return }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            selectedTab = .expense
        }
        padKeyboardNewExpenseToken &+= 1
    }

    func requestPadFocusSearch() {
        guard BuxPadIdiom.isPad else { return }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            selectedTab = .expense
            isExpenseSearchPresented = true
        }
        padKeyboardFocusSearchToken &+= 1
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

    /// Set when Home discovery card routes to Studio settings.
    @Published var openStudioSettingsRequest = false

    /// Set when Money Map deep-links to Payment Sources in Settings.
    @Published var openPaymentSettingsRequest = false

    /// Set when dashboard debt card routes to the Debt Center hub.
    @Published var showDebtHub: Bool = false

    /// Set when dashboard debt card routes to Debts settings.
    @Published var openDebtsSettingsRequest = false

    /// Set when Home hero avatar opens Profile settings.
    @Published var openProfileSettingsRequest = false

    /// Set when FAB shortcut opens Appearance & Themes settings.
    @Published var openAppearanceSettingsRequest = false
    @Published var pendingSettingsDestination: SettingsDestinationType?

    func openStudioSettings() {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            selectedTab = .settings
            openStudioSettingsRequest = true
        }
    }

    func openPaymentSettings() {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            selectedTab = .settings
            openPaymentSettingsRequest = true
        }
    }

    func openDebtHub() {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            showDebtHub = true
        }
    }

    func closeDebtHub() {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            showDebtHub = false
        }
    }

    func openDebtsSettings() {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            selectedTab = .settings
            openDebtsSettingsRequest = true
        }
    }

    func consumeStudioSettingsRequest() -> Bool {
        guard openStudioSettingsRequest else { return false }
        openStudioSettingsRequest = false
        return true
    }

    func consumePaymentSettingsRequest() -> Bool {
        guard openPaymentSettingsRequest else { return false }
        openPaymentSettingsRequest = false
        return true
    }

    func consumeDebtsSettingsRequest() -> Bool {
        guard openDebtsSettingsRequest else { return false }
        openDebtsSettingsRequest = false
        return true
    }

    func openProfileSettings() {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            selectedTab = .settings
            openProfileSettingsRequest = true
        }
    }

    func consumeProfileSettingsRequest() -> Bool {
        guard openProfileSettingsRequest else { return false }
        openProfileSettingsRequest = false
        return true
    }

    func openAppearanceSettings() {
        pendingSettingsDestination = .appearance
        withAnimation(BuxMotion.appearanceSettingsEntry) {
            selectedTab = .settings
            openAppearanceSettingsRequest = true
        }
    }

    func consumeAppearanceSettingsRequest() -> Bool {
        guard openAppearanceSettingsRequest else { return false }
        openAppearanceSettingsRequest = false
        return true
    }

    func takePendingSettingsDestination() -> SettingsDestinationType? {
        defer { pendingSettingsDestination = nil }
        return pendingSettingsDestination
    }

    @Published var openTipPopupRequest = false

    /// Full-screen blueprint unlock — fade overlay (not a sheet).
    @Published var showStudioUnlockAnimation = false
    @Published var showStudioPersonaPicker = false
    /// Toggle is on visually; `studioEnabled` commits around mid-animation so Studio is revealed under the fade-out.
    @Published private(set) var studioUnlockAwaitingCommit = false

    func beginStudioUnlock() {
        guard StudioPurchaseManager.shared.hasSimpleStudio else { return }
        guard !studioUnlockAwaitingCommit, !SettingsStore.shared.studioEnabled else { return }
        studioUnlockAwaitingCommit = true
        withAnimation(.easeInOut(duration: 0.45)) {
            showStudioUnlockAnimation = true
        }
    }

    /// Reveal Studio tab + settings while the blueprint overlay is still playing (~halfway).
    func commitStudioUnlock() {
        guard studioUnlockAwaitingCommit else { return }
        studioUnlockAwaitingCommit = false
        withAnimation(.easeInOut(duration: 0.55)) {
            SettingsStore.shared.studioEnabled = true
            SettingsStore.shared.studioMode = .simple
        }
        SettingsStore.shared.save()
    }

    func finishStudioUnlockPresentation() {
        if studioUnlockAwaitingCommit {
            commitStudioUnlock()
        }
        if SettingsStore.shared.studioEnabled, !SettingsStore.shared.studioPersonaConfigured {
            showStudioPersonaPicker = true
        }
    }

    func cancelStudioUnlockIfPending() {
        guard studioUnlockAwaitingCommit else { return }
        studioUnlockAwaitingCommit = false
        showStudioUnlockAnimation = false
    }
}
