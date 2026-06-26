//
//  BuxComponents.swift
//  BuxMuse Design System — buttons, headers, sheet scaffold.
//

import SwiftUI

// MARK: - Section header

struct BuxSectionHeader: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager

    let title: String

    var body: some View {
        BuxCatalogText.text(title)
            .buxSectionLabelStyle(color: themeManager.sectionHeaderColor(for: colorScheme))
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - BuxButton (canonical CTA — wraps BuxActionButton)

struct BuxButton: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager

    let title: String
    var systemImage: String = "checkmark"
    var role: BuxActionButtonRole = .primary
    var expands: Bool = false
    var size: BuxActionButtonSize = .large
    var isEnabled: Bool = true
    var celebrateOnSuccess: Bool = false
    var isSuccess: Bool = false
    let action: () -> Void

    var body: some View {
        BuxActionButton(
            title: title,
            systemImage: systemImage,
            role: role,
            accent: themeManager.materialScheme(for: colorScheme).primary,
            expands: expands,
            size: size,
            isEnabled: isEnabled,
            action: action
        )
        .buxSuccessPop(isActive: celebrateOnSuccess && isSuccess)
    }
}

// MARK: - Sheet scaffold

struct BuxSheetScaffold<Content: View, Footer: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager

    let title: String
    var cancelTitle: String = "Cancel"
    var showsCancel: Bool = true
    @ViewBuilder var content: () -> Content
    @ViewBuilder var footer: () -> Footer

    var body: some View {
        ZStack {
            themeManager.screenBackground(for: colorScheme)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                Divider().opacity(0.08)
                ScrollView(showsIndicators: false) {
                    content()
                        .padding(.top, BuxTokens.section)
                        .padding(.bottom, BuxTokens.block)
                }
                .buxScrollContentMargins()

                footer()
                    .padding(.horizontal, BuxLayout.marginHorizontal)
                    .padding(.bottom, BuxTokens.sheetBottomClearance)
            }
        }
    }

    private var header: some View {
        HStack {
            if showsCancel {
                BuxToolbarCancelButton { dismiss() }
            } else {
                Color.clear.frame(width: BuxToolbarMetrics.navButtonSize, height: 1)
            }

            Spacer()

            BuxCatalogText.text(title)
                .buxTitleStyle(color: themeManager.labelPrimary(for: colorScheme))

            Spacer()

            Color.clear.frame(width: 60, height: 1)
        }
        .padding(.horizontal, BuxLayout.marginHorizontal)
        .padding(.vertical, 16)
    }
}

extension BuxSheetScaffold where Footer == EmptyView {
    init(
        title: String,
        cancelTitle: String = "Cancel",
        showsCancel: Bool = true,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.cancelTitle = cancelTitle
        self.showsCancel = showsCancel
        self.content = content
        self.footer = { EmptyView() }
    }
}

// MARK: - Quick action (Studio hub — vertical capsule)

struct BuxQuickActionButton: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @ObservedObject private var settings = SettingsStore.shared

    let title: String
    let systemImage: String
    var role: BuxActionButtonRole = .secondary
    let action: () -> Void

    private var accent: Color { themeManager.contrastAccentColor(for: colorScheme) }

    var body: some View {
        Group {
            if settings.useGlassmorphism, BuxPlatform.supportsLiquidGlass, #available(iOS 26, *) {
                nativeGlassBody
            } else {
                legacyCapsuleBody
            }
        }
    }

    private var quickActionLabel: some View {
        VStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
            BuxCatalogText.text(title)
                .font(.system(size: 10, weight: .bold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var nativeGlassBody: some View {
        Button(action: action) {
            quickActionLabel
                .padding(.vertical, 12)
        }
        .buxNativeButtonStyle(role.nativeButtonRole, controlSize: .regular)
        .buxActionButtonChrome(role: role, accent: accent)
    }

    private var legacyCapsuleBody: some View {
        BuxCardButton(action: action) {
            quickActionLabel
                .foregroundStyle(foregroundColor)
                .padding(.vertical, 12)
                .background(backgroundColor)
                .clipShape(Capsule())
                .overlay {
                    if showsBorder {
                        Capsule().strokeBorder(borderColor, lineWidth: 1)
                    }
                }
                .shadow(color: shadowColor, radius: shadowRadius, x: 0, y: shadowY)
                .contentShape(Capsule())
        }
    }

    private var displayAccent: Color { themeManager.current.accentColor }
    private var readableAccent: Color { themeManager.contrastAccentColor(for: colorScheme) }

    private var foregroundColor: Color {
        switch role {
        case .primary, .destructive: return .white
        case .secondary, .tinted: return readableAccent
        }
    }

    private var backgroundColor: Color {
        switch role {
        case .primary: return displayAccent
        case .destructive: return BuxTokens.destructive
        case .secondary, .tinted: return themeManager.accentWash(for: colorScheme)
        }
    }

    private var showsBorder: Bool {
        switch role {
        case .primary, .destructive: return false
        case .secondary, .tinted: return true
        }
    }

    private var borderColor: Color {
        readableAccent.opacity(colorScheme == .dark ? 0.45 : 0.32)
    }

    private var shadowColor: Color {
        if case .primary = role {
            return displayAccent.opacity(colorScheme == .dark ? 0.18 : 0.14)
        }
        return .clear
    }

    private var shadowRadius: CGFloat {
        if case .primary = role { return BuxTokens.Shadow.ctaRadius }
        return 0
    }

    private var shadowY: CGFloat {
        if case .primary = role { return BuxTokens.Shadow.ctaY }
        return 0
    }
}

// MARK: - Card container

struct BuxCard<Content: View>: View {
    var elevation: BuxElevation = .card
    var cornerRadius: CGFloat = BuxTokens.Radius.card
    var padding: CGFloat = BuxTokens.section
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .buxThemedCardChrome(cornerRadius: cornerRadius, elevation: elevation)
    }
}

// MARK: - Scroll edge mask (clips content at edges — no painted header bars)

struct BuxScrollEdgeMaskModifier: ViewModifier {
    let edges: Edge.Set
    let fadeSize: CGFloat

    private var showsTop: Bool { edges.contains(.top) }
    private var showsBottom: Bool { edges.contains(.bottom) }
    private var showsLeading: Bool { edges.contains(.leading) }
    private var showsTrailing: Bool { edges.contains(.trailing) }

    func body(content: Content) -> some View {
        content.mask {
            Group {
                if showsLeading || showsTrailing {
                    horizontalMask
                } else {
                    verticalMask
                }
            }
        }
    }

    private var verticalMask: some View {
        VStack(spacing: 0) {
            if showsTop {
                LinearGradient(
                    colors: [.clear, .black],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: fadeSize)
            }
            Color.black
            if showsBottom {
                LinearGradient(
                    colors: [.black, .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: fadeSize)
            }
        }
    }

    private var horizontalMask: some View {
        HStack(spacing: 0) {
            if showsLeading {
                LinearGradient(
                    colors: [.clear, .black],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: fadeSize)
            }
            Color.black
            if showsTrailing {
                LinearGradient(
                    colors: [.black, .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: fadeSize)
            }
        }
    }
}

private struct BuxHorizontalScrollEdgeFadeModifier: ViewModifier {
    let fadeWidth: CGFloat

    func body(content: Content) -> some View {
        content.modifier(
            BuxScrollEdgeMaskModifier(edges: .horizontal, fadeSize: fadeWidth)
        )
    }
}

/// Trailing vignette overlay — soft edge fade without clipping scroll content.
private struct BuxTrailingScrollEdgeVignetteModifier: ViewModifier {
    let background: Color
    let width: CGFloat

    func body(content: Content) -> some View {
        content.overlay(alignment: .trailing) {
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: background.opacity(0.55), location: 0.45),
                    .init(color: background, location: 1),
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: width)
            .allowsHitTesting(false)
        }
    }
}

extension View {
    func buxScrollEdgeMask(edges: Edge.Set, size: CGFloat = 20) -> some View {
        modifier(BuxScrollEdgeMaskModifier(edges: edges, fadeSize: size))
    }

    /// Deprecated for horizontal carousels — use `buxHorizontalCarouselLane` in BuxLayout instead.
    func buxHorizontalScrollEdgeFade(background: Color, width: CGFloat = 20) -> some View {
        modifier(BuxHorizontalScrollEdgeFadeModifier(fadeWidth: width))
    }

    /// Deprecated for horizontal carousels — use `buxHorizontalCarouselLane` in BuxLayout instead.
    func buxThemedHorizontalScrollEdgeFade(
        themeManager: ThemeManager,
        colorScheme: ColorScheme,
        width: CGFloat = 20
    ) -> some View {
        buxHorizontalScrollEdgeFade(background: .clear, width: width)
    }

    /// Soft trailing edge overlay — not for horizontal carousels (use `buxHorizontalCarouselLane`).
    func buxTrailingScrollEdgeVignette(background: Color, width: CGFloat = 12) -> some View {
        modifier(BuxTrailingScrollEdgeVignetteModifier(background: background, width: width))
    }

    /// Soft drop shadow on chrome bars (tab bar, save bar) — not on scroll content.
    func buxChromeScrollEdgeShadow(_ edge: Edge, colorScheme: ColorScheme) -> some View {
        shadow(
            color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.08),
            radius: 8,
            x: 0,
            y: edge == .top ? 4 : -4
        )
    }
}

// MARK: - Navigation drawer search (iPad studio rail; iPad expenses use system toolbar search)

private enum BuxPadDrawerSearchLayout {
    /// Full custom search + scope rail (Studio split).
    static func usesRailSearch(studioSplit: Bool, expenseSplit: Bool) -> Bool {
        BuxPadIdiom.isPad && studioSplit
    }

    /// iPad Expenses — system toolbar search (trailing, grouped with menus); scopes inside search UI.
    static func usesExpenseToolbarSearch(studioSplit: Bool, expenseSplit: Bool) -> Bool {
        BuxPadIdiom.isPad && expenseSplit && !studioSplit
    }
}

private struct BuxPadRailDrawerSearchBar: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.buxSemanticTheme) private var semantic

    @Binding var text: String
    @Binding var isPresented: Bool
    let prompt: String
    var focusOnPresent: FocusState<Bool>.Binding

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.secondary)

            TextField(
                "",
                text: $text,
                prompt: Text(prompt)
            )
            .textFieldStyle(.plain)
            .focused(focusOnPresent)
            .submitLabel(.search)
            .tint(semantic.accent)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(Text(BuxCatalogLabel.string("Clear", locale: BuxInterfaceLocale.currentInterfaceLocale)))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background {
            let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
            if #available(iOS 26.0, *) {
                shape
                    .fill(.clear)
                    .glassEffect(.regular, in: shape)
            } else {
                shape.fill(.quaternary.opacity(colorScheme == .dark ? 0.35 : 0.55))
            }
        }
        .onChange(of: isPresented) { _, presented in
            if presented {
                focusOnPresent.wrappedValue = true
            } else {
                focusOnPresent.wrappedValue = false
            }
        }
        .onChange(of: focusOnPresent.wrappedValue) { _, focused in
            if focused, !isPresented {
                isPresented = true
            }
        }
    }
}

private struct BuxPadRailDrawerSearchInsetModifier<ScopeContent: View>: ViewModifier {
    @Environment(\.buxSemanticTheme) private var semantic
    @Environment(\.buxPadStudioUsesSplitLayout) private var studioSplit
    @Environment(\.buxPadExpenseUsesSplitLayout) private var expenseSplit

    @Binding var searchText: String
    @Binding var isPresented: Bool
    let prompt: String
    @ViewBuilder var scopeContent: () -> ScopeContent

    @FocusState private var isSearchFocused: Bool

    private var usesPadSplitRailSearch: Bool {
        BuxPadDrawerSearchLayout.usesRailSearch(studioSplit: studioSplit, expenseSplit: expenseSplit)
    }

    func body(content: Content) -> some View {
        if usesPadSplitRailSearch {
            content
                .safeAreaInset(edge: .top, spacing: 0) {
                    VStack(alignment: .leading, spacing: 8) {
                        BuxPadRailDrawerSearchBar(
                            text: $searchText,
                            isPresented: $isPresented,
                            prompt: prompt,
                            focusOnPresent: $isSearchFocused
                        )
                        scopeContent()
                    }
                    .buxPadDashboardCardRail()
                    .padding(.top, BuxLayout.tight)
                    .padding(.bottom, BuxLayout.tight)
                }
                .tint(semantic.accent)
        } else {
            content
        }
    }
}

/// iPad Expenses — native toolbar search + scopes; placement handled in `ExpenseTabView` toolbar.
private struct BuxPadExpenseToolbarSearchModifier<Scope: Hashable, ScopeContent: View>: ViewModifier {
    @Environment(\.buxSemanticTheme) private var semantic

    @Binding var searchText: String
    @Binding var isPresented: Bool
    @Binding var selection: Scope
    let prompt: String
    @ViewBuilder var scopes: () -> ScopeContent

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
                .searchable(
                    text: $searchText,
                    isPresented: $isPresented,
                    placement: .toolbar,
                    prompt: Text(prompt)
                )
                .searchScopes($selection) {
                    scopes()
                }
                .searchToolbarBehavior(.minimize)
                .tint(semantic.accent)
        } else {
            content
                .searchable(
                    text: $searchText,
                    isPresented: $isPresented,
                    placement: .toolbar,
                    prompt: Text(prompt)
                )
                .searchScopes($selection) {
                    scopes()
                }
                .tint(semantic.accent)
        }
    }
}

// MARK: - Centered top bar (true screen-center title)

struct BuxCenteredTopBar<Leading: View, Trailing: View>: View {
    let title: String
    var titleFont: Font = .system(size: 15, weight: .bold)
    @ViewBuilder var leading: () -> Leading
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        ZStack {
            BuxCatalogText.text(title)
                .font(titleFont)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .center)
                .allowsHitTesting(false)

            HStack(alignment: .center, spacing: 0) {
                leading()
                Spacer(minLength: 0)
                trailing()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

struct BuxDrawerSearchModifier: ViewModifier {
    @Environment(\.buxSemanticTheme) private var semantic
    @Environment(\.buxPadStudioUsesSplitLayout) private var studioSplit
    @Environment(\.buxPadExpenseUsesSplitLayout) private var expenseSplit

    @Binding var searchText: String
    let prompt: String
    @Binding var isPresented: Bool

    private var usesPadSplitRailSearch: Bool {
        BuxPadDrawerSearchLayout.usesRailSearch(studioSplit: studioSplit, expenseSplit: expenseSplit)
    }

    func body(content: Content) -> some View {
        if usesPadSplitRailSearch {
            content
                .modifier(
                    BuxPadRailDrawerSearchInsetModifier(
                        searchText: $searchText,
                        isPresented: $isPresented,
                        prompt: prompt,
                        scopeContent: { EmptyView() }
                    )
                )
        } else {
            content
                .searchable(
                    text: $searchText,
                    isPresented: $isPresented,
                    placement: .navigationBarDrawer(displayMode: .automatic),
                    prompt: prompt
                )
                .tint(semantic.accent)
        }
    }
}

/// Navigation drawer + scope chips (Expenses / Studio Tax pattern).
struct BuxDrawerScopeModifier<Scope: Hashable, ScopeContent: View>: ViewModifier {
    @Environment(\.buxPadStudioUsesSplitLayout) private var studioSplit
    @Environment(\.buxPadExpenseUsesSplitLayout) private var expenseSplit

    @Binding var searchText: String
    @Binding var selection: Scope
    @Binding var isPresented: Bool
    let prompt: String
    @ViewBuilder let scopes: () -> ScopeContent

    private var usesPadSplitRailSearch: Bool {
        BuxPadDrawerSearchLayout.usesRailSearch(studioSplit: studioSplit, expenseSplit: expenseSplit)
    }

    private var usesPadExpenseToolbarSearch: Bool {
        BuxPadDrawerSearchLayout.usesExpenseToolbarSearch(studioSplit: studioSplit, expenseSplit: expenseSplit)
    }

    func body(content: Content) -> some View {
        if usesPadSplitRailSearch {
            content
                .modifier(
                    BuxPadRailDrawerSearchInsetModifier(
                        searchText: $searchText,
                        isPresented: $isPresented,
                        prompt: prompt,
                        scopeContent: {
                            Picker("", selection: $selection) {
                                scopes()
                            }
                            .buxThemedSegmentedPicker()
                        }
                    )
                )
        } else if usesPadExpenseToolbarSearch {
            content
                .modifier(BuxPadExpenseToolbarSearchModifier(
                    searchText: $searchText,
                    isPresented: $isPresented,
                    selection: $selection,
                    prompt: prompt,
                    scopes: scopes
                ))
        } else {
            content
                .modifier(BuxDrawerSearchModifier(
                    searchText: $searchText,
                    prompt: prompt,
                    isPresented: $isPresented
                ))
                .searchScopes($selection) {
                    scopes()
                }
        }
    }
}

// MARK: - Debug overlay

struct BuxDebugOverlay: View {
    let showMetrics: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            BuxCatalogDynamicText(key: "BuxMuse Debug")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
            BuxCatalogDynamicText(key: "Pipeline: Brain → UI")
                .font(.system(size: 9, design: .monospaced))
            if showMetrics {
                BuxCatalogDynamicText(key: "Perf metrics: on")
                    .font(.system(size: 9, design: .monospaced))
                Text(Date(), style: .time)
                    .font(.system(size: 9, design: .monospaced))
            }
        }
        .padding(8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .padding(8)
    }
}
