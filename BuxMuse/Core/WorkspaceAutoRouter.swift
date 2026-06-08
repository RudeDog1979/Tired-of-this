//
//  WorkspaceAutoRouter.swift
//  BuxMuse
//
//  Shared create-only auto-routing for unassigned ledger rows.
//

import Foundation

@MainActor
enum WorkspaceAutoRouter {
    static func applyCreateOnlyRouting(to record: inout ExpenseRecord, isNewRecord: Bool) {
        guard isNewRecord,
              record.hustleId == nil,
              SettingsStore.shared.sideHustleMatrixEnabled else { return }
        record.hustleId = HustleManager.shared.routeHustleId(
            merchantName: record.merchantName,
            notes: record.notes,
            paymentMethod: record.paymentMethod
        )
    }
}
