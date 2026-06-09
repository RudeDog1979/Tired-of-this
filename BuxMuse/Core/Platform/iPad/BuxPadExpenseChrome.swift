//
//  BuxPadExpenseChrome.swift
//  BuxMuse — iPad expense split layout environment + card rail.
//

import SwiftUI

private struct BuxPadExpenseUsesSplitLayoutKey: EnvironmentKey {
    static let defaultValue = false
}

private struct BuxPadExpenseDetailEmbeddedKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var buxPadExpenseUsesSplitLayout: Bool {
        get { self[BuxPadExpenseUsesSplitLayoutKey.self] }
        set { self[BuxPadExpenseUsesSplitLayoutKey.self] = newValue }
    }

    var buxPadExpenseDetailEmbedded: Bool {
        get { self[BuxPadExpenseDetailEmbeddedKey.self] }
        set { self[BuxPadExpenseDetailEmbeddedKey.self] = newValue }
    }
}

private enum BuxPadExpenseLayout {
    static let tabBarClearance: CGFloat = 44
}

private struct BuxPadExpenseSplitNavigationModifier: ViewModifier {
    @Environment(\.buxPadExpenseUsesSplitLayout) private var usesPadSplitLayout

    func body(content: Content) -> some View {
        if usesPadSplitLayout {
            content
                .navigationTitle("")
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.hidden, for: .navigationBar)
                .buxRootNavigationChrome()
        } else {
            content
                .buxCatalogNavigationTitle("Expenses")
                .navigationBarTitleDisplayMode(.large)
                .buxRootNavigationChrome()
        }
    }
}

extension View {
    /// Same 720pt centered rail as dashboard — list canvas stays full width.
    func buxPadExpenseCardRail() -> some View {
        buxPadDashboardCardRail()
    }

    func buxPadExpenseSplitNavigationChrome() -> some View {
        modifier(BuxPadExpenseSplitNavigationModifier())
    }

    @ViewBuilder
    func buxPadExpenseSplitScrollMargins() -> some View {
        contentMargins(.top, BuxPadExpenseLayout.tabBarClearance, for: .scrollContent)
    }
}

struct ExpensePadSplitScrollChromeModifier: ViewModifier {
    @Environment(\.buxPadExpenseUsesSplitLayout) private var usesPadSplitLayout

    func body(content: Content) -> some View {
        if usesPadSplitLayout {
            content
                .buxPadExpenseSplitScrollMargins()
                .buxRootTabScrollChrome()
        } else {
            content.buxRootTabScrollChrome()
        }
    }
}
