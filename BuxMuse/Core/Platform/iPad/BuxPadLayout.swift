//
//  BuxPadLayout.swift
//  BuxMuse — iPad-only spacing tokens (8pt grid). iPhone uses BuxTokens/BuxLayout unchanged.
//

import SwiftUI

enum BuxPadLayout {
    static let unit: CGFloat = 8

    // Horizontal margins
    static let marginCompact: CGFloat = 16
    static let marginRegular: CGFloat = 24

    // Readable content column
    static let readableMaxWidth: CGFloat = 720

    // Split columns
    static let splitSidebarMin: CGFloat = 280
    static let splitSidebarIdeal: CGFloat = 320
    static let splitSidebarMax: CGFloat = 380

    /// Narrow Split View / Stage Manager tile — sidebar stays, detail gets priority.
    static let compactSplitSidebarMin: CGFloat = 220
    static let compactSplitSidebarIdeal: CGFloat = 250
    static let compactSplitSidebarMax: CGFloat = 280

    /// Expenses detail column — wider than nav sidebars; detail cards need more room.
    static let expenseDetailColumnMin: CGFloat = 320
    static let expenseDetailColumnIdeal: CGFloat = 400
    static let expenseDetailColumnMax: CGFloat = 440

    static let columnGap: CGFloat = 16

    // Detail pane card inset
    static let detailInsetCompact: CGFloat = 16
    static let detailInsetRegular: CGFloat = 20

    // Toolbar
    static let toolbarSpacing: CGFloat = 12

    static func horizontalMargin(layoutMode: BuxLayoutMode) -> CGFloat {
        layoutMode == .regular ? marginRegular : marginCompact
    }

    static func detailInset(layoutMode: BuxLayoutMode) -> CGFloat {
        layoutMode == .regular ? detailInsetRegular : detailInsetCompact
    }

    /// Proportional sidebar width clamped to min/ideal/max.
    static func splitSidebarWidth(containerWidth: CGFloat, layoutMode: BuxLayoutMode) -> CGFloat {
        guard layoutMode == .regular, containerWidth > 0 else { return splitSidebarIdeal }
        let proposed = containerWidth * 0.32
        return min(splitSidebarMax, max(splitSidebarMin, proposed))
    }

    static func splitSidebarMin(for layoutMode: BuxLayoutMode) -> CGFloat {
        layoutMode == .regular ? splitSidebarMin : compactSplitSidebarMin
    }

    static func splitSidebarIdeal(for layoutMode: BuxLayoutMode) -> CGFloat {
        layoutMode == .regular ? splitSidebarIdeal : compactSplitSidebarIdeal
    }

    static func splitSidebarMax(for layoutMode: BuxLayoutMode) -> CGFloat {
        layoutMode == .regular ? splitSidebarMax : compactSplitSidebarMax
    }
}
