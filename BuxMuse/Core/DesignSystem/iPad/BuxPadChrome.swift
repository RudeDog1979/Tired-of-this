//
//  BuxPadChrome.swift
//  BuxMuse — iPad scroll chrome, readable column, empty detail placeholder.
//

import SwiftUI

private struct BuxPadInspectorColumnKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// Trailing inspector column (Subscription Hub, etc.) — single surface, tighter insets.
    var buxPadInspectorColumn: Bool {
        get { self[BuxPadInspectorColumnKey.self] }
        set { self[BuxPadInspectorColumnKey.self] = newValue }
    }
}

struct BuxPadDetailEmptyState: View {
    let title: String
    let systemImage: String
    let message: String

    var body: some View {
        VStack(spacing: BuxPadLayout.unit * 2) {
            Image(systemName: systemImage)
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.title2.weight(.semibold))
            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(BuxPadLayout.marginRegular)
    }
}

private struct BuxPadRootChromeModifier: ViewModifier {
    @Environment(\.buxLayoutMode) private var layoutMode

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, BuxPadLayout.horizontalMargin(layoutMode: layoutMode))
    }
}

private struct BuxPadSystemSplitChromeModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .toolbar(.hidden, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
    }
}

private struct BuxPadReadableColumnModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(maxWidth: BuxPadLayout.readableMaxWidth)
            .frame(maxWidth: .infinity)
    }
}

extension View {
    func buxPadRootChrome() -> some View {
        modifier(BuxPadRootChromeModifier())
    }

    func buxPadReadableColumn() -> some View {
        modifier(BuxPadReadableColumnModifier())
    }

    func buxPadHoverable() -> some View {
        buxPointerReactive()
    }

    /// `NavigationSplitView` chrome — iOS 26 primary, iOS 18 fallback. Kills the full-width nav band only.
    func buxPadSystemSplitChrome() -> some View {
        modifier(BuxPadSystemSplitChromeModifier())
    }

    /// Root tab shell — compact / Slide Over.
    @ViewBuilder
    func buxPadRootTabShellStyle() -> some View {
        tabViewStyle(.tabBarOnly)
    }

    /// iPad regular — system sidebar tab rail (`.sidebarAdaptable`).
    @ViewBuilder
    func buxPadSidebarAdaptableTabStyle() -> some View {
        if #available(iOS 18.0, *) {
            tabViewStyle(.sidebarAdaptable)
        } else {
            tabViewStyle(.tabBarOnly)
        }
    }
}
