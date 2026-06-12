//
//  WorkspaceCurrencyContext.swift
//  BuxMuse
//
//  Resolves display currency for the active virtual-desktop workspace.
//

import Foundation

struct WorkspaceBudgetResolution: Equatable {
    let workspaceName: String
    let limit: Decimal
}

enum WorkspaceCurrencyContext {
    static func resolveActiveDisplayCurrency(
        global: CurrencySetting,
        matrixEnabled: Bool,
        selectedHustleId: UUID?,
        hustles: [Hustle]
    ) -> CurrencySetting {
        guard matrixEnabled,
              let activeId = selectedHustleId,
              let hustle = hustles.first(where: { $0.id == activeId }),
              let code = hustle.currencyCode,
              let currency = AppSettingsManager.availableCurrencies.first(where: { $0.id == code })
        else { return global }
        return currency
    }

    static func resolveActiveWorkspaceBudget(
        matrixEnabled: Bool,
        selectedHustleId: UUID?,
        hustles: [Hustle]
    ) -> WorkspaceBudgetResolution? {
        guard matrixEnabled,
              let activeId = selectedHustleId,
              let hustle = hustles.first(where: { $0.id == activeId }),
              let limit = hustle.budgetLimit,
              limit > 0
        else { return nil }
        return WorkspaceBudgetResolution(workspaceName: hustle.name, limit: limit)
    }

    @MainActor
    static func activeDisplayCurrency(global: CurrencySetting) -> CurrencySetting {
        resolveActiveDisplayCurrency(
            global: global,
            matrixEnabled: SettingsStore.shared.sideHustleMatrixEnabled,
            selectedHustleId: HustleManager.shared.selectedHustleId,
            hustles: HustleManager.shared.hustles
        )
    }

    @MainActor
    static func activeWorkspaceBudget() -> WorkspaceBudgetResolution? {
        resolveActiveWorkspaceBudget(
            matrixEnabled: SettingsStore.shared.sideHustleMatrixEnabled,
            selectedHustleId: HustleManager.shared.selectedHustleId,
            hustles: HustleManager.shared.hustles
        )
    }
}
