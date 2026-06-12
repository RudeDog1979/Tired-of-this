//
//  BuxPadWindowLauncher.swift
//  BuxMuse — Seed auxiliary window brains and open Stage Manager scenes.
//

import SwiftUI

enum BuxPadWindowLauncher {
    @MainActor
    static func openExpenseWindow(
        from brain: BuxPadNavigationBrain,
        registry: BuxPadSceneBrainRegistry,
        openWindow: OpenWindowAction
    ) {
        let sessionId = UUID()
        registry.restoreSnapshot(brain.exportSnapshot(), for: sessionId)
        openWindow(id: BuxPadWindowID.expense, value: sessionId)
    }

    @MainActor
    static func openStudioWindow(
        destination: String?,
        from brain: BuxPadNavigationBrain,
        registry: BuxPadSceneBrainRegistry,
        openWindow: OpenWindowAction
    ) {
        let sessionId = UUID()
        var snapshot = brain.exportSnapshot()
        if let destination {
            snapshot.selectedStudioDestination = destination
        }
        registry.restoreSnapshot(snapshot, for: sessionId)
        let payload = BuxPadStudioWindowPayload(sessionId: sessionId, destination: destination)
        openWindow(id: BuxPadWindowID.studio, value: payload)
    }
}

extension View {
    /// Right-click / long-press — open the current Studio tool in a new window.
    func buxPadStudioOpenInNewWindowContextMenu(
        destination: String?,
        enabled: Bool = true
    ) -> some View {
        modifier(BuxPadStudioOpenInNewWindowContextMenuModifier(
            destination: destination,
            enabled: enabled
        ))
    }

    /// Right-click — open Expenses with the current selection in a new window.
    func buxPadExpenseOpenInNewWindowContextMenu(enabled: Bool = true) -> some View {
        modifier(BuxPadExpenseOpenInNewWindowContextMenuModifier(enabled: enabled))
    }
}

private struct BuxPadStudioOpenInNewWindowContextMenuModifier: ViewModifier {
    let destination: String?
    let enabled: Bool

    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var padBrain: BuxPadNavigationBrain
    @EnvironmentObject private var padSceneBrainRegistry: BuxPadSceneBrainRegistry

    func body(content: Content) -> some View {
        content.contextMenu {
            if enabled, BuxPadIdiom.isPad, !padSceneBrainRegistry.isAuxiliary(padBrain) {
                Button {
                    BuxPadWindowLauncher.openStudioWindow(
                        destination: destination,
                        from: padBrain,
                        registry: padSceneBrainRegistry,
                        openWindow: openWindow
                    )
                } label: {
                    Label("Open in New Window", systemImage: "macwindow.on.rectangle")
                }
            }
        }
    }
}

private struct BuxPadExpenseOpenInNewWindowContextMenuModifier: ViewModifier {
    let enabled: Bool

    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var padBrain: BuxPadNavigationBrain
    @EnvironmentObject private var padSceneBrainRegistry: BuxPadSceneBrainRegistry

    func body(content: Content) -> some View {
        content.contextMenu {
            if enabled, BuxPadIdiom.isPad, !padSceneBrainRegistry.isAuxiliary(padBrain) {
                Button {
                    BuxPadWindowLauncher.openExpenseWindow(
                        from: padBrain,
                        registry: padSceneBrainRegistry,
                        openWindow: openWindow
                    )
                } label: {
                    Label("Open in New Window", systemImage: "macwindow.on.rectangle")
                }
            }
        }
    }
}
