//
//  BuxNavigationChrome.swift
//  BuxMuse
//
//  Root / pushed navigation bar + scroll edge polish (iOS 26 glass, iOS 18 fallback).
//

import SwiftUI

// MARK: - Root tabs (Dashboard, Expenses, Studio, Settings)

private struct BuxRootNavigationChromeModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            // Let system Liquid Glass style the bar — no custom bar fill.
            content
        } else {
            content.toolbarBackground(.hidden, for: .navigationBar)
        }
    }
}

// MARK: - Pushed lists (Studio tools, settings drill-ins)

private struct BuxPushedNavigationChromeModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager

    func body(content: Content) -> some View {
        let background = themeManager.screenBackground(for: colorScheme)
        if #available(iOS 26, *) {
            content.containerBackground(background, for: .navigation)
        } else {
            content
                .toolbarBackground(.visible, for: .navigationBar)
                .containerBackground(background, for: .navigation)
        }
    }
}

// MARK: - Sheet / modal nav (visible bar, no mesh bleed)

private struct BuxPolishedNavigationBarModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
        } else {
            content.toolbarBackground(.visible, for: .navigationBar)
        }
    }
}

// MARK: - Sheet / modal nav (themed bar — no white slab)

private struct BuxSheetNavigationChromeModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager

    func body(content: Content) -> some View {
        let background = themeManager.screenBackground(for: colorScheme)
        content
            .toolbarBackground(background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .containerBackground(background, for: .navigation)
    }
}

// MARK: - Scroll edge (content ↔ bar separation on iOS 26)

@available(iOS 26, *)
private struct BuxSoftScrollEdgeModifier: ViewModifier {
    let edges: Edge.Set

    func body(content: Content) -> some View {
        content.scrollEdgeEffectStyle(.automatic, for: edges)
    }
}

// MARK: - Toolbar shared glass (plain icon items)

extension ToolbarContent {
    /// Hide the shared glass pill behind plain icon / menu toolbar items on iOS 26.
    @ToolbarContentBuilder
    func buxPlainToolbarBackground() -> some ToolbarContent {
        if #available(iOS 26, *) {
            self.sharedBackgroundVisibility(.hidden)
        } else {
            self
        }
    }
}

extension View {
    /// Large-title root screens — mesh shows through; system glass on iOS 26.
    func buxRootNavigationChrome() -> some View {
        modifier(BuxRootNavigationChromeModifier())
    }

    /// Pushed Studio / settings lists with mesh backdrop.
    /// Prefer `buxDetailNavigationChrome()` for headerless soft-scroll screens.
    func buxPushedNavigationChrome() -> some View {
        modifier(BuxPushedNavigationChromeModifier())
    }

    /// Detail hubs & drill-ins — mesh shows through; matches root tab bar chrome.
    func buxDetailNavigationChrome() -> some View {
        buxRootNavigationChrome()
    }

    /// Sheets that need a standard navigation bar surface.
    func buxPolishedNavigationBar() -> some View {
        modifier(BuxPolishedNavigationBarModifier())
    }

    /// Sheet / full-screen cover — themed nav bar matching M3 canvas.
    func buxSheetNavigationChrome() -> some View {
        modifier(BuxSheetNavigationChromeModifier())
    }

    /// Scroll views / lists under a navigation bar — soft edge on iOS 26.
    @ViewBuilder
    func buxSoftScrollChrome(edges: Edge.Set = .top) -> some View {
        if #available(iOS 26, *) {
            modifier(BuxSoftScrollEdgeModifier(edges: edges))
        } else {
            self
        }
    }

    /// Alias for root tabs and detail vertical scrolls.
    func buxRootScrollEdgeChrome() -> some View {
        buxSoftScrollChrome(edges: .top)
    }

    /// Horizontal carousels under mesh (renewals, category chips, etc.).
    func buxSoftHorizontalScrollChrome() -> some View {
        buxSoftScrollChrome(edges: .horizontal)
    }
}
