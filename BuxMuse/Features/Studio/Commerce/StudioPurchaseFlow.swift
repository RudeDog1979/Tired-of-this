//
//  StudioPurchaseFlow.swift
//  BuxMuse — Shared purchase + unlock choreography.
//

import Foundation

@MainActor
enum StudioPurchaseFlow {
    static func purchaseStandard(
        navigationCoordinator: NavigationCoordinator? = nil,
        purchaseManager: StudioPurchaseManager? = nil,
        period: BuxMuseBillingPeriod = .yearly
    ) async throws {
        let manager = purchaseManager ?? StudioPurchaseManager.shared
        _ = try await manager.purchaseStandardSubscription(period: period)
        // Studio tab stays off until the user opts in (Settings / discovery → unlock animation).
        _ = navigationCoordinator
    }

    static func purchasePro(
        simpleStore: SimpleStudioStore,
        studioStore: StudioStore,
        settings: SettingsStore? = nil,
        appSettingsManager: AppSettingsManager,
        navigationCoordinator: NavigationCoordinator? = nil,
        purchaseManager: StudioPurchaseManager? = nil,
        period: BuxMuseBillingPeriod = .yearly
    ) async throws {
        let manager = purchaseManager ?? StudioPurchaseManager.shared
        let settingsStore = settings ?? SettingsStore.shared
        _ = try await manager.purchaseProSubscription(period: period)
        guard manager.hasProStudio else { return }
        // Only migrate Simple→Pro data if Studio is already enabled; do not force the tab on.
        if settingsStore.studioEnabled {
            _ = SimpleStudioUpgradeCoordinator.upgradeToPro(
                simpleStore: simpleStore,
                studioStore: studioStore,
                settings: settingsStore,
                currencyCode: appSettingsManager.selectedCurrency.id
            )
        }
        _ = navigationCoordinator
    }

    /// Call when the user explicitly turns on Studio (Settings toggle / discovery).
    static func enableStudioTab(navigationCoordinator: NavigationCoordinator?) {
        guard !SettingsStore.shared.studioEnabled else { return }
        if let navigationCoordinator {
            navigationCoordinator.beginStudioUnlock()
        } else {
            SettingsStore.shared.studioEnabled = true
            SettingsStore.shared.save()
        }
    }
}
