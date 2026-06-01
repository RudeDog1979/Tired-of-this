//
//  BuxNavigationChrome.swift
//  BuxMuse
//
//  Root / pushed navigation bar + scroll edge polish (iOS 26 glass, iOS 18 content mask).
//

import SwiftUI

// MARK: - Root tabs (Dashboard, Expenses, Studio, Settings)

private struct BuxRootNavigationChromeModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
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

// MARK: - Scroll edge

@available(iOS 26, *)
private struct BuxSoftScrollEdgeModifier: ViewModifier {
    let edges: Edge.Set

    func body(content: Content) -> some View {
        content.scrollEdgeEffectStyle(.automatic, for: edges)
    }
}

private struct BuxSoftScrollChromeModifier: ViewModifier {
    let edges: Edge.Set
    var fadeSize: CGFloat

    private var isHorizontal: Bool {
        edges.contains(.leading) || edges.contains(.trailing)
    }

    func body(content: Content) -> some View {
        if isHorizontal {
            content.modifier(BuxScrollEdgeMaskModifier(edges: edges, fadeSize: fadeSize))
        } else if #available(iOS 26, *) {
            content.modifier(BuxSoftScrollEdgeModifier(edges: edges))
        } else {
            content.modifier(BuxScrollEdgeMaskModifier(edges: edges, fadeSize: fadeSize))
        }
    }
}

// MARK: - Toolbar shared glass (plain icon items)

extension ToolbarContent {
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
    func buxRootNavigationChrome() -> some View {
        modifier(BuxRootNavigationChromeModifier())
    }

    func buxPushedNavigationChrome() -> some View {
        modifier(BuxPushedNavigationChromeModifier())
    }

    /// Detail hubs & drill-ins — mesh shows through; matches root tab bar chrome.
    func buxDetailNavigationChrome() -> some View {
        buxRootNavigationChrome()
    }

    func buxPolishedNavigationBar() -> some View {
        modifier(BuxPolishedNavigationBarModifier())
    }

    func buxSheetNavigationChrome() -> some View {
        modifier(BuxSheetNavigationChromeModifier())
    }

    /// Scroll views — iOS 26 system scroll edge; iOS 18 content mask (no painted bars).
    func buxSoftScrollChrome(edges: Edge.Set = .top, fadeSize: CGFloat = 20) -> some View {
        modifier(BuxSoftScrollChromeModifier(edges: edges, fadeSize: fadeSize))
    }

    func buxRootScrollEdgeChrome() -> some View {
        buxSoftScrollChrome(edges: .top)
    }

    func buxSoftHorizontalScrollChrome(fadeSize: CGFloat = 20) -> some View {
        buxSoftScrollChrome(edges: .horizontal, fadeSize: fadeSize)
    }
}
