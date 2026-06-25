//
//  BuxNotificationRouter.swift
//  BuxMuse — deep-link routing for inbox rows and system notification taps.
//

import SwiftUI

@MainActor
enum BuxNotificationRouter {
    static func applyInboxItem(_ item: AppNotificationItem, navigation: NavigationCoordinator, brain: BuxMuseBrain?) {
        brain?.markNotificationRead(item.id)
        route(category: item.category, itemId: item.id, navigation: navigation)
    }

    static func apply(payload: BuxNotificationTapPayload, navigation: NavigationCoordinator, brain: BuxMuseBrain?) {
        guard let payloadRoute = BuxNotificationPayload.route(from: payload) else { return }

        switch payloadRoute {
        case .inboxItem:
            guard let inbox = BuxNotificationPayload.inboxItem(from: payload) else { return }
            brain?.markNotificationRead(inbox.itemId)
            if let category = inbox.category {
                route(category: category, itemId: inbox.itemId, navigation: navigation)
            }
        case .expense:
            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                navigation.openExpensesTab()
            }
        case .debt:
            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                navigation.openDebtHub()
            }
        case .studioLogTime:
            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                navigation.openStudioLogTime()
            }
        case .backup:
            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                navigation.selectedTab = .settings
                navigation.pendingSettingsDestination = .data
            }
        case .subscription:
            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                navigation.openSubscriptionHub()
            }
        }
    }

    private static func route(category: AppNotificationCategory, itemId: String, navigation: NavigationCoordinator) {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            switch category {
            case .subscription:
                navigation.openSubscriptionHub()
            case .bill:
                navigation.openExpensesTab()
            case .budget:
                navigation.selectedTab = .settings
            case .invoice, .tax, .studio:
                navigation.selectedTab = .studio
            case .digest:
                navigation.selectedTab = .home
                navigation.openTipPopupRequest = true
            case .debt:
                navigation.openDebtHub()
            }
        }
        _ = itemId
    }
}
