//
//  StudioPurchaseFlow.swift
//  BuxMuse — Shared purchase + unlock choreography.
//

import Foundation

@MainActor
enum StudioPurchaseFlow {
    static func purchaseSimple(
        navigationCoordinator: NavigationCoordinator? = nil,
        purchaseManager: StudioPurchaseManager? = nil
    ) async throws {
        let manager = purchaseManager ?? StudioPurchaseManager.shared
        _ = try await manager.purchase(.simple)
        guard manager.hasSimpleStudio else { return }
        enableStudioTab(navigationCoordinator: navigationCoordinator)
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
        _ = try await manager.purchase(period.studioProProductID)
        guard manager.hasProStudio else { return }
        _ = SimpleStudioUpgradeCoordinator.upgradeToPro(
            simpleStore: simpleStore,
            studioStore: studioStore,
            settings: settingsStore,
            currencyCode: appSettingsManager.selectedCurrency.id
        )
        enableStudioTab(navigationCoordinator: navigationCoordinator)
    }

    private static func enableStudioTab(navigationCoordinator: NavigationCoordinator?) {
        guard !SettingsStore.shared.studioEnabled else { return }
        if let navigationCoordinator {
            navigationCoordinator.beginStudioUnlock()
        } else {
            SettingsStore.shared.studioEnabled = true
            SettingsStore.shared.save()
        }
    }
}
