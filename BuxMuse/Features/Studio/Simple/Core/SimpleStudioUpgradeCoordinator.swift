//
//  SimpleStudioUpgradeCoordinator.swift
//  BuxMuse
//
//  Runs Simple → Pro migration and switches studio mode.
//

import Foundation

@MainActor
enum SimpleStudioUpgradeCoordinator {

    /// Migrate Simple data into Pro, then enable Pro mode. Returns migration stats.
    @discardableResult
    static func upgradeToPro(
        simpleStore: SimpleStudioStore,
        studioStore: StudioStore,
        settings: SettingsStore,
        currencyCode: String
    ) -> SimpleStudioMigrationResult {
        let result = SimpleStudioProMigration.migrate(
            simple: simpleStore.snapshot,
            into: studioStore,
            currencyCode: currencyCode
        )
        settings.studioMode = .pro
        settings.save()
        studioStore.ensureBusinessCardLibrary(simpleCard: simpleStore.businessCard)
        return result
    }
}
