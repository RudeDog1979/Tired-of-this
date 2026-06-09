//
//  BuxPadLayoutPersistence.swift
//  BuxMuse — Preserve split state across Stage Manager resize (no reload on size-class flip).
//

import SwiftUI

extension View {
    /// Prevents implicit animations when moving between compact ↔ regular width.
    func buxPadPreservesLayoutAcrossResize() -> some View {
        self.transaction { transaction in
            transaction.disablesAnimations = true
        }
    }
}
