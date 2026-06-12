//
//  BuxPadExternalDisplayBridge.swift
//  BuxMuse — Opens/closes presentation window on external display connect/disconnect.
//

import SwiftUI
import UIKit

struct BuxPadExternalDisplayBridge: ViewModifier {
    let isPad: Bool

    @EnvironmentObject private var padBrain: BuxPadNavigationBrain
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow

    func body(content: Content) -> some View {
        content
            .onAppear {
                guard isPad else { return }
                refreshExternalDisplayState()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIScene.willConnectNotification)) { notification in
                guard isPad else { return }
                handleSceneConnect(notification)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIScene.didDisconnectNotification)) { notification in
                guard isPad else { return }
                handleSceneDisconnect(notification)
            }
            .onChange(of: padBrain.activeExternalPresentation) { _, _ in
                syncPresentationWindow()
            }
            .onChange(of: padBrain.externalPresentationSessionId) { _, _ in
                syncPresentationWindow()
            }
            .onChange(of: padBrain.externalDisplayConnection) { _, connection in
                guard isPad else { return }
                if !connection.isConnected {
                    dismissWindow(id: BuxPadWindowID.presentation)
                } else {
                    syncPresentationWindow()
                }
            }
    }

    @MainActor
    private func handleSceneConnect(_ notification: Notification) {
        if let scene = notification.object as? UIScene,
           BuxPadExternalDisplayMonitor.isExternalDisplayScene(scene) {
            refreshExternalDisplayState()
            return
        }
        refreshExternalDisplayState()
    }

    @MainActor
    private func handleSceneDisconnect(_ notification: Notification) {
        if let scene = notification.object as? UIScene,
           BuxPadExternalDisplayMonitor.isExternalDisplayScene(scene) {
            padBrain.handleExternalDisplayDisconnected()
            dismissWindow(id: BuxPadWindowID.presentation)
            return
        }
        refreshExternalDisplayState()
    }

    @MainActor
    private func refreshExternalDisplayState() {
        padBrain.handleExternalScreensChanged(
            extraScreenCount: BuxPadExternalDisplayMonitor.extraScreenCount()
        )
        syncPresentationWindow()
    }

    private func syncPresentationWindow() {
        guard isPad, padBrain.externalDisplayConnection.isConnected else { return }
        guard let kind = padBrain.activeExternalPresentation,
              let sessionId = padBrain.externalPresentationSessionId else { return }
        let payload = BuxPadPresentationPayload(sessionId: sessionId, kind: kind)
        openWindow(id: BuxPadWindowID.presentation, value: payload)
    }
}

extension View {
    func buxPadExternalDisplayBridge(isPad: Bool) -> some View {
        modifier(BuxPadExternalDisplayBridge(isPad: isPad))
    }
}
