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

extension View {
    func buxScrollEdgeMask(edges: Edge.Set, size: CGFloat = 20) -> some View {
        modifier(BuxScrollEdgeMaskModifier(edges: edges, fadeSize: size))
    }

    func buxHorizontalScrollEdgeFade(background: Color, width: CGFloat = 20) -> some View {
        modifier(BuxHorizontalScrollEdgeFadeModifier(fadeWidth: width))
    }

    func buxThemedHorizontalScrollEdgeFade(
        themeManager: ThemeManager,
        colorScheme: ColorScheme,
        width: CGFloat = 20
    ) -> some View {
        buxHorizontalScrollEdgeFade(background: .clear, width: width)
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

// MARK: - Navigation drawer search (visible by default; scroll up to minimize)

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
    @Binding var searchText: String
    let prompt: String
    @Binding var isPresented: Bool

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
                .searchable(text: $searchText, isPresented: $isPresented, prompt: prompt)
                .tint(semantic.accent)
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
    @Binding var searchText: String
    @Binding var selection: Scope
    @Binding var isPresented: Bool
    let prompt: String
    @ViewBuilder let scopes: () -> ScopeContent

    func body(content: Content) -> some View {
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
