//
//  BuxPadHostChrome.swift
//  BuxMuse — Shared layout chrome for iPad feature hosts.
//

import SwiftUI

extension View {
    /// Centers tab content in a readable column on regular width.
    func buxPadTabHostChrome() -> some View {
        modifier(BuxPadTabHostChromeModifier())
    }
}

private struct BuxPadTabHostChromeModifier: ViewModifier {
    @Environment(\.buxLayoutMode) private var layoutMode

    func body(content: Content) -> some View {
        Group {
            if layoutMode == .regular {
                content
                    .buxPadReadableColumn()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                content
            }
        }
    }
}
