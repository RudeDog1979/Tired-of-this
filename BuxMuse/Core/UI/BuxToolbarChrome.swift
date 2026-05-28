//
//  BuxToolbarChrome.swift
//  BuxMuse
//
//  Shared navigation bar presence + larger toolbar icons on root tabs.
//

import SwiftUI

enum BuxToolbarMetrics {
    static let iconPointSize: CGFloat = 22
    static let iconWeight: Font.Weight = .semibold
}

/// Standard SF Symbol sizing for navigation bar actions (Expenses, Studio, Settings).
struct BuxToolbarIcon: View {
    let systemName: String

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: BuxToolbarMetrics.iconPointSize, weight: BuxToolbarMetrics.iconWeight))
            .symbolRenderingMode(.hierarchical)
            .frame(minWidth: BuxLayout.minTapTarget, minHeight: BuxLayout.minTapTarget)
            .contentShape(Rectangle())
    }
}

extension View {
    /// Visible, themed navigation bar on root tabs (pairs with large titles).
    func buxPolishedNavigationBar() -> some View {
        toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackgroundVisibility(.visible, for: .navigationBar)
    }

    /// Root tab chrome: pinned bar + stronger material + keyboard stability.
    func buxRootNavigationChrome() -> some View {
        buxPolishedNavigationBar()
            .buxStableNavigationBarWithKeyboard()
    }
}
