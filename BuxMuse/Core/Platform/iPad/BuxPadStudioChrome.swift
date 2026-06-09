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

extension View {
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
