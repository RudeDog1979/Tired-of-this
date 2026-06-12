//
//  BuxPadExternalDisplayConnection.swift
//  BuxMuse — External display connect/disconnect state (iPad only).
//

import UIKit

enum BuxPadExternalDisplayConnection: Equatable {
    case disconnected
    case connected(extraScreens: Int)

    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }
}

@MainActor
enum BuxPadExternalDisplayMonitor {
    static func extraScreenCount() -> Int {
        if #available(iOS 26, *) {
            return externalDisplayCountModern()
        }
        return externalDisplayCountIOS18()
    }

    static func isExternalDisplayScene(_ scene: UIScene) -> Bool {
        guard let windowScene = scene as? UIWindowScene else { return false }
        return isExternalDisplaySession(windowScene.session)
    }

    @available(iOS 26, *)
    private static func externalDisplayCountModern() -> Int {
        let connected = externalConnectedScenes().count
        if connected > 0 { return connected }
        return externalOpenSessionCount()
    }

    private static func externalDisplayCountIOS18() -> Int {
        let connected = externalConnectedScenes().count
        if connected > 0 { return connected }
        return externalOpenSessionCount()
    }

    private static func externalConnectedScenes() -> [UIWindowScene] {
        UIApplication.shared.connectedScenes.compactMap { scene in
            guard let windowScene = scene as? UIWindowScene,
                  isExternalDisplaySession(windowScene.session) else { return nil }
            return windowScene
        }
    }

    private static func externalOpenSessionCount() -> Int {
        UIApplication.shared.openSessions.filter(isExternalDisplaySession).count
    }

    static func isExternalDisplaySession(_ session: UISceneSession) -> Bool {
        if session.role == .windowExternalDisplayNonInteractive {
            return true
        }
        if #available(iOS 18.0, *) {
            let role = session.role.rawValue
            if role.localizedCaseInsensitiveContains("external") {
                return true
            }
        }
        if let configurationName = session.configuration.name {
            if configurationName.localizedCaseInsensitiveContains("external") {
                return true
            }
            if configurationName == BuxPadWindowID.presentation {
                return true
            }
        }
        return false
    }
}
