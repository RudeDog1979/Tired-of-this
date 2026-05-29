//
//  StudioListChrome.swift
//  BuxMuse
//
//  Shared mesh backdrop + themed list rows for Studio tools (matches Invoices / Expenses).
//

import SwiftUI

private struct StudioHubEmbeddedKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var studioHubEmbedded: Bool {
        get { self[StudioHubEmbeddedKey.self] }
        set { self[StudioHubEmbeddedKey.self] = newValue }
    }
}

enum StudioListMetrics {
    static let rowCornerRadius: CGFloat = 16
    static let rowInsets = EdgeInsets(top: 5, leading: 0, bottom: 5, trailing: 0)
}

/// Mesh + screen fill behind Studio pushed screens.
struct StudioThemedListBackdrop<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            themeManager.screenBackground(for: colorScheme)
                .ignoresSafeArea()

            BuxHeroMeshBackground()
                .ignoresSafeArea(.keyboard, edges: .bottom)

            content()
        }
        .environment(\.studioEnhancedTint, true)
        .buxDetailNavigationChrome()
    }
}

extension View {
    func studioThemedListRows() -> some View {
        listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .buxListContentMargins()
            .buxCustomTabBarScrollClearance()
            .buxStableNavigationBarWithKeyboard()
            .buxSoftScrollChrome()
    }

    func studioThemedListRowChrome() -> some View {
        buttonStyle(.plain)
            .listRowInsets(StudioListMetrics.rowInsets)
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }

    func studioThemedListRowCard() -> some View {
        padding(.horizontal, 14)
            .padding(.vertical, 12)
            .modifier(BuxThemedListRowChromeModifier(cornerRadius: StudioListMetrics.rowCornerRadius))
    }

    /// Pushed Studio screens keep their own inset; embedded Tax tabs rely on the hub `List` margins.
    func studioHubEmbeddedHorizontalPadding() -> some View {
        modifier(StudioHubEmbeddedHorizontalPaddingModifier())
    }
}

private struct StudioHubEmbeddedHorizontalPaddingModifier: ViewModifier {
    @Environment(\.studioHubEmbedded) private var studioHubEmbedded

    func body(content: Content) -> some View {
        if studioHubEmbedded {
            content
        } else {
            content.padding(.horizontal, BuxLayout.marginHorizontal)
        }
    }
}

// MARK: - Liquid glass section menu (Tax — matches Invoices chrome, no search field)

struct StudioGlassCapsuleBackground: View {
    var body: some View {
        BuxGlassCapsuleBackground()
    }
}

extension View {
    /// Frosted capsule behind horizontal section chips (Invoices-style floating bar).
    func studioGlassFloatingBar() -> some View {
        padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background {
                StudioGlassCapsuleBackground()
            }
            .clipShape(Capsule(style: .continuous))
    }
}

// MARK: - Glass horizontal section menu (overflow hint + auto-scroll to selection)

private struct StudioScrollContentWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct StudioScrollViewportWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

/// Scrollable section chips inside the liquid glass capsule; shows a trailing cue when more tabs sit off-screen.
struct StudioGlassHorizontalSectionMenu<Tab: Hashable & Identifiable>: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager

    @Binding var selection: Tab
    let tabs: [Tab]
    let label: (Tab) -> String

    @State private var contentWidth: CGFloat = 0
    @State private var viewportWidth: CGFloat = 0

    private var showsTrailingOverflowCue: Bool {
        contentWidth > viewportWidth + 6
    }

    var body: some View {
        ScrollViewReader { scrollProxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(tabs) { tab in
                        sectionButton(for: tab)
                            .id(tab.id)
                    }
                }
                .padding(.trailing, showsTrailingOverflowCue ? 18 : 4)
                .background {
                    GeometryReader { geometry in
                        Color.clear
                            .preference(
                                key: StudioScrollContentWidthKey.self,
                                value: geometry.size.width
                            )
                    }
                }
            }
            .overlay(alignment: .trailing) {
                if showsTrailingOverflowCue {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(themeManager.current.accentColor.opacity(0.85))
                        .padding(.trailing, 12)
                        .allowsHitTesting(false)
                }
            }
            .onAppear {
                scrollToSelection(scrollProxy, animated: false)
            }
            .onChange(of: selection.id) { _, _ in
                scrollToSelection(scrollProxy, animated: true)
            }
        }
        .frame(maxWidth: .infinity)
        .background {
            GeometryReader { geometry in
                Color.clear
                    .preference(
                        key: StudioScrollViewportWidthKey.self,
                        value: geometry.size.width
                    )
            }
        }
        .onPreferenceChange(StudioScrollContentWidthKey.self) { contentWidth = $0 }
        .onPreferenceChange(StudioScrollViewportWidthKey.self) { viewportWidth = $0 }
        .studioGlassFloatingBar()
    }

    private func sectionButton(for tab: Tab) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.32)) {
                selection = tab
            }
        } label: {
            Text(label(tab))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(
                    selection.id == tab.id
                        ? themeManager.current.accentColor
                        : themeManager.labelSecondary(for: colorScheme)
                )
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background {
                    if selection.id == tab.id {
                        Capsule(style: .continuous)
                            .fill(
                                themeManager.current.accentColor.opacity(
                                    colorScheme == .dark ? 0.24 : 0.16
                                )
                            )
                    }
                }
        }
        .buttonStyle(.plain)
    }

    private func scrollToSelection(_ proxy: ScrollViewProxy, animated: Bool) {
        guard tabs.contains(where: { $0.id == selection.id }) else { return }
        if animated {
            withAnimation(.buxSnap) {
                proxy.scrollTo(selection.id, anchor: .center)
            }
        } else {
            proxy.scrollTo(selection.id, anchor: .center)
        }
    }
}
