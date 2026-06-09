//
//  BuxPadDashboardChrome.swift
//  BuxMuse — Full-width dashboard canvas; cards centered, never stretched.
//

import SwiftUI

extension BuxPadLayout {
    /// Max width for dashboard cards on iPad regular — centered in full-width scroll.
    static let dashboardCardMaxWidth: CGFloat = 720
}

private struct BuxPadDashboardCardRailModifier: ViewModifier {
    @Environment(\.buxLayoutMode) private var layoutMode
    @Environment(\.buxContainerWidth) private var containerWidth

    func body(content: Content) -> some View {
        if BuxPadIdiom.isPad && layoutMode == .regular {
            let railWidth = dashboardRailWidth
            content
                .frame(maxWidth: railWidth, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .center)
        } else {
            content
        }
    }

    private var dashboardRailWidth: CGFloat {
        let margin = BuxPadLayout.horizontalMargin(layoutMode: layoutMode) * 2
        let available = containerWidth > 0
            ? containerWidth - margin
            : BuxPadLayout.dashboardCardMaxWidth
        return min(BuxPadLayout.dashboardCardMaxWidth, max(available, 0))
    }
}

extension View {
    /// iPad regular: keeps scroll full-width; centers card stack at `dashboardCardMaxWidth`.
    func buxPadDashboardCardRail() -> some View {
        modifier(BuxPadDashboardCardRailModifier())
    }
}
