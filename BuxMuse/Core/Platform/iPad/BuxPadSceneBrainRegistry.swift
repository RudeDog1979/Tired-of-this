//
//  BuxPadSceneBrainRegistry.swift
//  BuxMuse — Per-window BuxPadNavigationBrain instances (primary + auxiliary scenes).
//

import SwiftUI
import Combine

@MainActor
final class BuxPadSceneBrainRegistry: ObservableObject {
    let primaryBrain: BuxPadNavigationBrain
    private var auxiliaryBrains: [UUID: BuxPadNavigationBrain] = [:]

    init(primaryBrain: BuxPadNavigationBrain) {
        self.primaryBrain = primaryBrain
    }

    /// Primary window uses `nil` session — auxiliary Stage Manager windows use a stable UUID.
    func brain(for windowSession: UUID?) -> BuxPadNavigationBrain {
        guard let windowSession else { return primaryBrain }
        if let existing = auxiliaryBrains[windowSession] {
            return existing
        }
        let created = BuxPadNavigationBrain()
        auxiliaryBrains[windowSession] = created
        return created
    }

    func restoreSnapshot(_ snapshot: BuxPadNavigationSnapshot, for windowSession: UUID?) {
        brain(for: windowSession).applySnapshot(snapshot)
    }

    func isAuxiliary(_ brain: BuxPadNavigationBrain) -> Bool {
        brain !== primaryBrain
    }
}
