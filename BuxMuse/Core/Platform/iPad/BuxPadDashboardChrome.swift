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
    @Environment(\.buxPadStudioUsesSplitLayout) private var studioSplit
    @Environment(\.buxPadSettingsUsesSplitLayout) private var settingsSplit
    @Environment(\.buxPadExpenseUsesSplitLayout) private var expenseSplit

    private var usesSplitDetailColumn: Bool {
        studioSplit || settingsSplit || expenseSplit
    }

    private var shouldApplyRail: Bool {
        BuxPadIdiom.isPad && (layoutMode == .regular || usesSplitDetailColumn)
    }

    private var railLayoutMode: BuxLayoutMode {
        usesSplitDetailColumn ? .regular : layoutMode
    }

    func body(content: Content) -> some View {
        if shouldApplyRail {
            let railWidth = dashboardRailWidth(for: resolvedColumnWidth)
            content
                .frame(maxWidth: railWidth, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .center)
        } else {
            content
        }
    }

    private static let columnMeasureFloor: CGFloat = BuxPadLayout.splitSidebarMin

    /// Width used to cap the centered card rail — no local GeometryReader (avoids layout feedback loops).
    private var resolvedColumnWidth: CGFloat {
        if usesSplitDetailColumn {
            // Split columns already receive the correct width from NavigationSplitView.
            // Never read intrinsic content width — empty states are narrow and lie about column size.
            return 0
        }

        // Home / root tabs: sidebarAdaptable can report narrow intrinsic widths on cold launch.
        if containerWidth >= Self.columnMeasureFloor { return containerWidth }
        return 0
    }

    private func dashboardRailWidth(for width: CGFloat) -> CGFloat {
        let margin = BuxPadLayout.horizontalMargin(layoutMode: railLayoutMode) * 2
        let available = width > 0
            ? width - margin
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

// MARK: - iPad Home scroll GPU budget

private struct BuxPadFlatDashboardChromeKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// iPad Home tab only — flat strokes instead of drop shadows / glow stacks in scroll content.
    var buxPadFlatDashboardChrome: Bool {
        get { self[BuxPadFlatDashboardChromeKey.self] }
        set { self[BuxPadFlatDashboardChromeKey.self] = newValue }
    }
}
