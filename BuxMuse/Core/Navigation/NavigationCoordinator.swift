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

    /// Set when Home discovery card routes to Studio settings.
    @Published var openStudioSettingsRequest = false

    /// Set when Home hero avatar opens Profile settings.
    @Published var openProfileSettingsRequest = false

    func openStudioSettings() {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            selectedTab = .settings
            openStudioSettingsRequest = true
        }
    }

    func consumeStudioSettingsRequest() -> Bool {
        guard openStudioSettingsRequest else { return false }
        openStudioSettingsRequest = false
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

    @Published var openTipPopupRequest = false

    /// Full-screen blueprint unlock — fade overlay (not a sheet).
    @Published var showStudioUnlockAnimation = false
    /// Toggle is on visually; `studioEnabled` commits around mid-animation so Studio is revealed under the fade-out.
    @Published private(set) var studioUnlockAwaitingCommit = false

    func beginStudioUnlock() {
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
        }
        SettingsStore.shared.save()
    }

    func finishStudioUnlockPresentation() {
        if studioUnlockAwaitingCommit {
            commitStudioUnlock()
        }
    }

    func cancelStudioUnlockIfPending() {
        guard studioUnlockAwaitingCommit else { return }
        studioUnlockAwaitingCommit = false
        showStudioUnlockAnimation = false
    }
}
