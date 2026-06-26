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

/// Shared Tier-2 Pro tool title inset — matches Studio Insights scroll layout.
enum StudioProToolHeaderLayout {
    static let topInset: CGFloat = BuxTokens.section
    static let bottomSpacing: CGFloat = BuxLayout.tight
}

/// M3 canvas behind Studio pushed screens.
struct StudioThemedListBackdrop<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.buxPadStudioUsesSplitLayout) private var usesPadSplitLayout
    @EnvironmentObject private var themeManager: ThemeManager
    @ViewBuilder var content: () -> Content

    var body: some View {
        Group {
            if usesPadSplitLayout {
                content()
                    .padding(.top, BuxTokens.tight)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .buxPadDashboardCardRail()
            } else {
                ZStack {
                    themeManager.screenBackground(for: colorScheme)
                        .ignoresSafeArea()

                    content()
                }
            }
        }
        .modifier(StudioPadSplitBackdropChromeModifier())
        .environment(\.studioEnhancedTint, true)
        .buxDetailNavigationChrome()
    }
}

extension View {
    func studioThemedListRows(isSheet: Bool = false) -> some View {
        Group {
            if isSheet {
                listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .scrollDismissesKeyboard(.interactively)
                    .buxListContentMargins()
                    .buxSoftScrollChrome()
            } else {
                listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .scrollDismissesKeyboard(.interactively)
                    .modifier(StudioThemedListPhoneMarginsModifier())
                    .buxStableNavigationBarWithKeyboard()
                    .buxSoftScrollChrome()
            }
        }
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

    /// First list row for Tier-2 Pro tool headers (Invoices, Clients, …).
    func studioProToolScreenHeaderRow() -> some View {
        listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: StudioProToolHeaderLayout.bottomSpacing, trailing: 0))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }

    /// Scroll / form content chrome — use `studioProToolScrollTopInset()` on the List / ScrollView instead.
    func studioProToolScreenScrollChrome() -> some View {
        self
    }

    /// Receipts reference — unified title top inset on List / ScrollView scroll content.
    func studioProToolScrollTopInset() -> some View {
        contentMargins(.top, StudioProToolHeaderLayout.topInset, for: .scrollContent)
    }

    /// Static tool column inside `StudioThemedListBackdrop` when there is no List / ScrollView shell.
    func studioProToolStaticTopInset() -> some View {
        padding(.top, StudioProToolHeaderLayout.topInset)
    }

    /// iPad split `List` tools — Expenses parity: scroll chrome on list, no rail on list shell.
    func studioProPadSplitListLayout() -> some View {
        modifier(StudioProPadSplitListLayoutModifier())
    }

    /// iPad split `ScrollView` shell — apply to the scroll surface after inner content uses `buxPadDashboardCardRail()`.
    func studioProPadSplitScrollLayout() -> some View {
        modifier(StudioProPadSplitScrollLayoutModifier())
    }

    /// Phone-only scroll horizontal inset — pair with `studioProPadSplitScrollLayout()` when the view does not use section/header padding.
    func studioPhoneScrollContentMargins() -> some View {
        modifier(StudioPhoneScrollContentMarginsModifier())
    }
}

private struct StudioProPadSplitListLayoutModifier: ViewModifier {
    @Environment(\.buxPadStudioUsesSplitLayout) private var usesPadSplitLayout

    func body(content: Content) -> some View {
        if usesPadSplitLayout {
            content
                .padding(.top, BuxTokens.tight)
                .modifier(StudioPadSplitScrollChromeModifier())
        } else {
            content
        }
    }
}

private struct StudioProPadSplitScrollLayoutModifier: ViewModifier {
    @Environment(\.buxPadStudioUsesSplitLayout) private var usesPadSplitLayout

    func body(content: Content) -> some View {
        if usesPadSplitLayout {
            content.modifier(StudioPadSplitScrollChromeModifier())
        } else {
            content
        }
    }
}

private struct StudioPhoneScrollContentMarginsModifier: ViewModifier {
    @Environment(\.buxPadStudioUsesSplitLayout) private var usesPadSplitLayout

    func body(content: Content) -> some View {
        if usesPadSplitLayout {
            content
        } else {
            content.buxScrollContentMargins()
        }
    }
}

private struct StudioThemedListPhoneMarginsModifier: ViewModifier {
    @Environment(\.buxPadStudioUsesSplitLayout) private var usesPadSplitLayout

    func body(content: Content) -> some View {
        if usesPadSplitLayout {
            content
        } else {
            content.buxListContentMargins()
        }
    }
}

private struct StudioHubEmbeddedHorizontalPaddingModifier: ViewModifier {
    @Environment(\.studioHubEmbedded) private var studioHubEmbedded
    @Environment(\.buxPadStudioUsesSplitLayout) private var usesPadSplitLayout

    func body(content: Content) -> some View {
        if studioHubEmbedded || usesPadSplitLayout {
            content
        } else {
            content.padding(.horizontal, BuxLayout.marginHorizontal)
        }
    }
}

// MARK: - Liquid glass section menu (Tax — matches Invoices chrome, no search field)

struct StudioGlassCapsuleBackground: View {
    var castsShadow: Bool = true

    var body: some View {
        BuxGlassCapsuleBackground(castsShadow: castsShadow)
    }
}

extension View {
    /// Frosted capsule behind horizontal section chips (Invoices-style floating bar).
    func studioGlassFloatingBar(suppressShadow: Bool = false) -> some View {
        modifier(StudioGlassFloatingBarModifier(suppressShadow: suppressShadow))
    }
}

private struct StudioGlassFloatingBarModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @ObservedObject private var settings = SettingsStore.shared
    /// Section menus — flat glass track, no drop shadow stack under each chip.
    var suppressShadow: Bool = false

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background {
                if settings.useGlassmorphism {
                    StudioGlassCapsuleBackground(castsShadow: !suppressShadow)
                } else {
                    ZStack {
                        Capsule(style: .continuous)
                            .fill(themeManager.pillTrackFill(for: colorScheme))
                        if settings.brandThemesEnabled {
                            Capsule(style: .continuous)
                                .fill(DashboardThemeTint.pillTrackWash(
                                    themeManager: themeManager,
                                    colorScheme: colorScheme
                                ))
                            }
                    }
                }
            }
            .clipShape(Capsule(style: .continuous))
            .overlay {
                if !settings.useGlassmorphism {
                    Capsule(style: .continuous)
                        .stroke(
                            settings.brandThemesEnabled
                                ? DashboardThemeTint.themedCardStroke(
                                    themeManager: themeManager,
                                    colorScheme: colorScheme
                                )
                                : themeManager.cardOutlineStroke(for: colorScheme, branded: false),
                            lineWidth: 1
                        )
                }
            }
    }
}

// MARK: - Glass horizontal section menu (scrollable chips in liquid glass capsule)

/// Scrollable section chips inside the liquid glass capsule (Tax Studio, Home categories, Invoice tabs).
struct StudioGlassHorizontalSectionMenu<Tab: Hashable & Identifiable>: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @ObservedObject private var settings = SettingsStore.shared
    @Namespace private var selectionNamespace

    @Binding var selection: Tab
    let tabs: [Tab]
    let label: (Tab) -> String

    private let chipSpacing: CGFloat = 10

    private var accent: Color {
        themeManager.contrastAccentColor(for: colorScheme)
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            centeredChipRow
            scrollableChipRow
        }
        .frame(maxWidth: .infinity)
        .studioGlassFloatingBar(suppressShadow: true)
    }

    private var centeredChipRow: some View {
        HStack(spacing: chipSpacing) {
            ForEach(tabs) { tab in
                sectionButton(for: tab)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var scrollableChipRow: some View {
        ScrollViewReader { scrollProxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: chipSpacing) {
                    ForEach(tabs) { tab in
                        sectionButton(for: tab)
                            .id(tab.id)
                    }
                }
                .padding(.horizontal, 4)
            }
            .onAppear {
                scrollToSelection(scrollProxy, animated: false)
            }
            .onChange(of: selection.id) { _, _ in
                scrollToSelection(scrollProxy, animated: true)
            }
        }
    }

    private func sectionButton(for tab: Tab) -> some View {
        let isSelected = selection.id == tab.id
        return Button {
            withAnimation(.buxCategorySpring) {
                selection = tab
            }
        } label: {
            BuxCatalogDynamicText(key: label(tab))
                .font(.system(size: 13, weight: isSelected ? .bold : .semibold))
                .foregroundStyle(
                    isSelected
                        ? accent
                        : themeManager.pillInactiveLabelColor(for: colorScheme)
                )
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background {
                    if isSelected {
                        selectionBlob
                            .matchedGeometryEffect(id: "studioSectionSelectionBlob", in: selectionNamespace)
                    }
                }
        }
        .buttonStyle(MorphingPillButtonStyle())
    }

    private var selectionBlob: some View {
        Capsule(style: .continuous)
            .fill(selectionBlobFill)
    }

    private var selectionBlobFill: Color {
        if settings.useGlassmorphism {
            accent.opacity(colorScheme == .dark ? 0.22 : 0.14)
        } else {
            themeManager.pillActiveChipFill(for: colorScheme)
        }
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
