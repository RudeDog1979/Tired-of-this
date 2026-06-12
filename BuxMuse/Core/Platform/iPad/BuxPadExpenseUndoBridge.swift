//
//  BuxPadExpenseUndoBridge.swift
//  BuxMuse — Snapshot + undo offer after expense deletion (all platforms).
//

import SwiftUI

enum BuxPadExpenseUndoBridge {
    @MainActor
    static func snapshotBeforeDelete(id: UUID, brain: BuxMuseBrain) -> ExpenseRecord? {
        try? brain.fetchExpenseRecord(id: id)
    }

    @MainActor
    static func offerUndoAfterDelete(_ snapshot: ExpenseRecord?, brain: BuxMuseBrain) {
        guard let snapshot else { return }
        brain.offerExpenseUndo(snapshot)
    }
}
