//
//  BuxPadSplitLayout.swift
//  BuxMuse — Shared NavigationSplitView column chrome for iPad hosts.
//

import SwiftUI

extension View {
    /// Sidebar column width — regular vs compact Split View.
    func buxPadSplitSidebarColumnWidth(layoutMode: BuxLayoutMode) -> some View {
        navigationSplitViewColumnWidth(
            min: BuxPadLayout.splitSidebarMin(for: layoutMode),
            ideal: BuxPadLayout.splitSidebarIdeal(for: layoutMode),
            max: BuxPadLayout.splitSidebarMax(for: layoutMode)
        )
    }
}
