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

/// M3 canvas behind Studio pushed screens.
struct StudioThemedListBackdrop<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            themeManager.screenBackground(for: colorScheme)
                .ignoresSafeArea()

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
        modifier(StudioGlassFloatingBarModifier())
    }
}

private struct StudioGlassFloatingBarModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @ObservedObject private var settings = SettingsStore.shared

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background {
                if settings.useGlassmorphism {
                    StudioGlassCapsuleBackground()
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

    @Binding var selection: Tab
    let tabs: [Tab]
    let label: (Tab) -> String

    var body: some View {
        ScrollViewReader { scrollProxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(tabs) { tab in
                        sectionButton(for: tab)
                            .id(tab.id)
                    }
                }
                .padding(.trailing, 4)
            }
            .onAppear {
                scrollToSelection(scrollProxy, animated: false)
            }
            .onChange(of: selection.id) { _, _ in
                scrollToSelection(scrollProxy, animated: true)
            }
        }
        .frame(maxWidth: .infinity)
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
                        ? themeManager.contrastAccentColor(for: colorScheme)
                        : themeManager.pillInactiveLabelColor(for: colorScheme)
                )
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background {
                    if selection.id == tab.id {
                        Capsule(style: .continuous)
                            .fill(
                                settings.brandThemesEnabled
                                    ? DashboardThemeTint.pillActiveChipFill(
                                        themeManager: themeManager,
                                        colorScheme: colorScheme
                                    )
                                    : themeManager.pillActiveChipFill(for: colorScheme)
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
