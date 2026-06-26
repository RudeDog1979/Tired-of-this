//
//  BuxPadStudioChrome.swift
//  BuxMuse — iPad Studio split layout flags.
//

import SwiftUI
import UIKit

private struct BuxPadStudioUsesSplitLayoutKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var buxPadStudioUsesSplitLayout: Bool {
        get { self[BuxPadStudioUsesSplitLayoutKey.self] }
        set { self[BuxPadStudioUsesSplitLayoutKey.self] = newValue }
    }
}

private enum BuxPadStudioLayout {
    /// Single clearance under the floating tab bar — not dashboard's 52pt large-title band.
    static let tabBarClearance: CGFloat = 44
}

/// System sidebar toggle uses UIKit `UINavigationBar.tintColor`, not SwiftUI `.tint()`.
private struct BuxPadSidebarToggleTint: UIViewControllerRepresentable {
    let color: UIColor

    func makeUIViewController(context: Context) -> UIViewController {
        let controller = UIViewController()
        controller.view.isUserInteractionEnabled = false
        controller.view.backgroundColor = .clear
        return controller
    }

    func updateUIViewController(_ controller: UIViewController, context: Context) {
        // Synchronous — already on main. iOS 27 beta: async here can trap with
        // -[OS_dispatch_mach_msg _setContext:] during SwiftUI representable updates.
        var chain: UIViewController? = controller
        while let current = chain {
            current.navigationController?.navigationBar.tintColor = color
            chain = current.parent
        }
    }
}

/// iPad split detail column — persistent landing/theme wash; tool content transitions above it.
struct BuxPadSplitDetailCanvas<Selection: Equatable, Content: View>: View {
    let selection: Selection
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            BuxLandingTintBackground()
                .ignoresSafeArea()
                .animation(nil, value: selection)

            content()
        }
    }
}

private struct BuxPadStudioToolShellModifier: ViewModifier {
    @Environment(\.buxPadStudioUsesSplitLayout) private var usesPadSplitLayout
    let navigationTitleKey: String

    func body(content: Content) -> some View {
        if usesPadSplitLayout {
            content
                .navigationTitle("")
                .navigationBarTitleDisplayMode(.inline)
                .buxPadStudioToolNavigationChrome()
        } else {
            content
                .buxCatalogNavigationTitle(navigationTitleKey)
                .navigationBarTitleDisplayMode(.large)
                .buxPadStudioToolNavigationChrome()
        }
    }
}

extension View {
    /// Pro Studio sidebar tools — inline nav on iPad split; embedded screen headers own the title.
    func buxPadStudioToolShell(titleKey: String) -> some View {
        modifier(BuxPadStudioToolShellModifier(navigationTitleKey: titleKey))
    }
}

private struct BuxPadStudioToolNavigationChromeModifier: ViewModifier {
    @Environment(\.buxPadStudioUsesSplitLayout) private var usesPadSplitLayout

    func body(content: Content) -> some View {
        if usesPadSplitLayout {
            content.buxDetailNavigationChrome()
        } else {
            content.buxPushedNavigationChrome()
        }
    }
}

struct StudioPadSplitBackdropChromeModifier: ViewModifier {
    @Environment(\.buxPadStudioUsesSplitLayout) private var usesPadSplitLayout

    func body(content: Content) -> some View {
        if usesPadSplitLayout {
            content.modifier(StudioPadSplitScrollChromeModifier())
        } else {
            content
        }
    }
}

extension View {
    /// Settings-parity iPad split column — centered rail + adaptive margins (Tax envelope, My Money, …).
    func buxPadStudioSplitDetailLayout() -> some View {
        modifier(StudioPadSplitDetailLayoutModifier())
    }
}

private struct StudioPadSplitDetailLayoutModifier: ViewModifier {
    @Environment(\.buxPadStudioUsesSplitLayout) private var usesPadSplitLayout

    func body(content: Content) -> some View {
        if usesPadSplitLayout {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .buxPadDashboardCardRail()
                .modifier(StudioPadSplitBackdropChromeModifier())
        } else {
            content
        }
    }
}

extension View {
    /// Pro Studio list tools — on iPad split keep nav transparent so landing wash shows through.
    func buxPadStudioToolNavigationChrome() -> some View {
        modifier(BuxPadStudioToolNavigationChromeModifier())
    }

    /// iPad split **detail column** — ease slide/fade only; keeps spring bounce off chrome and backdrop.
    func buxPadSplitDetailTransition() -> some View {
        transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .opacity
        ))
    }

    /// Pair with `buxPadSplitDetailTransition()` on the detail column (matches Settings split host).
    func buxPadSplitDetailNavigationAnimation<ID: Equatable>(value: ID) -> some View {
        animation(BuxMotion.appearanceSettingsEntry, value: value)
    }

    /// Sidebar column only — tints the system collapse/expand control with BuxMuse readable accent.
    func buxPadSidebarToggleTint(_ color: Color) -> some View {
        background {
            BuxPadSidebarToggleTint(color: UIColor(color))
        }
    }

    /// Detail column — transparent bar; system split owns sidebar collapse.
    func buxPadStudioSplitDetailChrome() -> some View {
        navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
    }
}

extension View {

    @ViewBuilder
    func buxStudioHubPadNavigationChrome<Trailing: View>(
        usesPadSplitLayout: Bool,
        brand: BuxStudioRootTabBrand = .pro,
        @ViewBuilder trailingToolbar: () -> Trailing
    ) -> some View {
        if usesPadSplitLayout {
            self
                .navigationTitle("")
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.hidden, for: .navigationBar)
                .buxRootNavigationChrome()
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        trailingToolbar()
                    }
                }
        } else {
            self
                .buxStudioRootTabChrome(brand: brand)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        trailingToolbar()
                    }
                }
        }
    }

    @ViewBuilder
    func buxStudioHubPadScrollMargins(usesPadSplitLayout: Bool) -> some View {
        if usesPadSplitLayout {
            contentMargins(.top, BuxPadStudioLayout.tabBarClearance, for: .scrollContent)
        } else {
            self
        }
    }
}

/// iPad split detail column — same scroll padding stack as `ExpensePadSplitScrollChromeModifier`.
struct StudioPadSplitScrollChromeModifier: ViewModifier {
    @Environment(\.buxPadStudioUsesSplitLayout) private var usesPadSplitLayout

    func body(content: Content) -> some View {
        if usesPadSplitLayout {
            content
                .buxStudioHubPadScrollMargins(usesPadSplitLayout: true)
                .buxRootTabScrollChrome()
        } else {
            content
                .contentMargins(.top, BuxLayout.dashboardRootTabScrollTopInset, for: .scrollContent)
                .buxRootTabScrollChrome()
        }
    }
}

private struct StudioPadAdaptiveScrollContentModifier: ViewModifier {
    @Environment(\.buxPadStudioUsesSplitLayout) private var usesPadSplitLayout

    func body(content: Content) -> some View {
        if usesPadSplitLayout {
            content.buxPadDashboardCardRail()
        } else {
            content
        }
    }
}

private struct StudioPadAdaptiveScrollSurfaceModifier: ViewModifier {
    @Environment(\.buxPadStudioUsesSplitLayout) private var usesPadSplitLayout

    func body(content: Content) -> some View {
        if usesPadSplitLayout {
            content.modifier(StudioPadSplitScrollChromeModifier())
        } else {
            content
        }
    }
}

private struct StudioPadSectionInsetModifier: ViewModifier {
    @Environment(\.buxPadStudioUsesSplitLayout) private var usesPadSplitLayout

    func body(content: Content) -> some View {
        if usesPadSplitLayout {
            content
        } else {
            content.padding(.horizontal, BuxTokens.marginRegular)
        }
    }
}

private struct StudioThemedListPadLayoutModifier: ViewModifier {
    @Environment(\.buxPadStudioUsesSplitLayout) private var usesPadSplitLayout

    func body(content: Content) -> some View {
        if usesPadSplitLayout {
            content
                .buxPadDashboardCardRail()
                .modifier(StudioPadSplitScrollChromeModifier())
        } else {
            content.buxListContentMargins()
        }
    }
}

extension View {
    /// iPad split list/scroll **content** — centered 720pt rail (apply to `VStack` / `LazyVStack` inside scroll).
    func buxPadStudioAdaptiveScrollContent() -> some View {
        modifier(StudioPadAdaptiveScrollContentModifier())
    }

    /// iPad split list/scroll **surface** — adaptive margins + tab clearance (apply to `ScrollView` / `List`).
    func buxPadStudioAdaptiveScrollSurface() -> some View {
        modifier(StudioPadAdaptiveScrollSurfaceModifier())
    }

    /// iPad split static column — rail + adaptive scroll chrome (Tax envelope, etc.).
    func buxPadStudioAdaptiveColumnLayout() -> some View {
        modifier(StudioPadAdaptiveScrollContentModifier())
            .modifier(StudioPadAdaptiveScrollSurfaceModifier())
    }

    /// Section/card inset — phone keeps 20pt rails; iPad split relies on adaptive chrome.
    func buxPadStudioSectionInset() -> some View {
        modifier(StudioPadSectionInsetModifier())
    }

    func buxPadStudioThemedListPadLayout() -> some View {
        modifier(StudioThemedListPadLayoutModifier())
    }
}
