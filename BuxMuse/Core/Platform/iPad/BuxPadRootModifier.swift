//
//  BuxPadRootModifier.swift
//  BuxMuse — Applies pad environment + container metrics to the full root tree.
//

import SwiftUI

struct BuxPadRootModifier: ViewModifier {
    let isPad: Bool

    func body(content: Content) -> some View {
        if isPad {
            content
                .buxPadEnvironment()
                .buxPadReportsContainerMetrics()
                .buxPadPrefersProMotion()
                .buxPadDebouncedBrainResize(isPad: true)
                .overlay {
                    BuxPadExpenseUndoOverlay()
                }
        } else {
            content
        }
    }
}

extension View {
    func buxPadRootChrome(isPad: Bool) -> some View {
        modifier(BuxPadRootModifier(isPad: isPad))
    }
}
