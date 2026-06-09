//
//  BuxPadSimpleStudioSheets.swift
//  BuxMuse — iPad quick-capture sheets (medium detent + large).
//

import SwiftUI

extension View {
    /// Log money, scan, invoice, quote — medium detent on iPad compact/regular; iPhone unchanged.
    func buxPadSimpleStudioQuickSheet() -> some View {
        modifier(BuxPadSimpleStudioQuickSheetModifier())
    }
}

private struct BuxPadSimpleStudioQuickSheetModifier: ViewModifier {
    func body(content: Content) -> some View {
        if BuxPadIdiom.isPad {
            content
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        } else {
            content
        }
    }
}
