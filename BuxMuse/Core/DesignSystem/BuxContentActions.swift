//
//  BuxContentActions.swift
//  BuxMuse
//
//  Content-level CTAs + swipe action conventions (Phase 4).
//

import SwiftUI

extension View {
    /// Form / list destructive row — always system red, never brand accent.
    func buxDestructiveRowStyle() -> some View {
        foregroundStyle(BuxTokens.destructive)
    }
}

extension Button where Label == Text {
    /// Centered destructive form button (settings purge, reset, etc.).
    static func buxDestructive(_ title: String, action: @escaping () -> Void) -> Button {
        Button(title, role: .destructive, action: action)
    }
}
