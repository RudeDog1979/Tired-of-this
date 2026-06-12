//
//  BuxPadKeyboardContextSync.swift
//  BuxMuse — Keeps pad keyboard context aligned with the active tab (iPad only).
//

import SwiftUI

private struct BuxPadKeyboardContextSyncModifier: ViewModifier {
    let isPad: Bool

    @EnvironmentObject private var navigation: NavigationCoordinator
    @EnvironmentObject private var padBrain: BuxPadNavigationBrain
    @ObservedObject private var settingsStore = SettingsStore.shared

    func body(content: Content) -> some View {
        content
            .onAppear {
                syncContext()
            }
            .onChange(of: navigation.selectedTab) { _, _ in
                syncContext()
            }
            .onChange(of: settingsStore.studioMode) { _, _ in
                syncContext()
            }
            .onChange(of: padBrain.selectedStudioDestination) { _, _ in
                syncContext()
            }
    }

    private func syncContext() {
        guard isPad else { return }
        padBrain.updateKeyboardContext(
            selectedTab: navigation.selectedTab,
            studioMode: settingsStore.studioMode,
            studioDestination: padBrain.selectedStudioDestination
        )
    }
}

private struct BuxPadEscapeKeyHandlerModifier: ViewModifier {
    let isPad: Bool

    @EnvironmentObject private var padBrain: BuxPadNavigationBrain

    func body(content: Content) -> some View {
        if isPad {
            content
                .focusable()
                .onKeyPress(.escape) {
                    padBrain.postPadKeyboardCommand(.close)
                    return .handled
                }
        } else {
            content
        }
    }
}

extension View {
    func buxPadKeyboardContextSync(isPad: Bool) -> some View {
        modifier(BuxPadKeyboardContextSyncModifier(isPad: isPad))
    }

    func buxPadEscapeKeyHandler(isPad: Bool) -> some View {
        modifier(BuxPadEscapeKeyHandlerModifier(isPad: isPad))
    }
}
