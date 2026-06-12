//
//  BuxPadSceneRestoration.swift
//  BuxMuse — NSUserActivity payloads for iPad auxiliary windows.
//

import Foundation

struct BuxPadNavigationSnapshot: Codable, Equatable {
    var selectedExpenseId: UUID?
    var selectedStudioDestination: String?
    var selectedSettingsPath: String?
}

extension BuxPadNavigationBrain {
    func exportSnapshot() -> BuxPadNavigationSnapshot {
        BuxPadNavigationSnapshot(
            selectedExpenseId: selectedExpenseId,
            selectedStudioDestination: selectedStudioDestination,
            selectedSettingsPath: selectedSettingsPath
        )
    }

    func applySnapshot(_ snapshot: BuxPadNavigationSnapshot) {
        selectedExpenseId = snapshot.selectedExpenseId
        selectedStudioDestination = snapshot.selectedStudioDestination
        selectedSettingsPath = snapshot.selectedSettingsPath
    }
}

enum BuxPadSceneRestoration {
    static func userInfo(
        sessionId: UUID,
        snapshot: BuxPadNavigationSnapshot,
        studioDestination: String? = nil,
        presentationKind: String? = nil
    ) -> [String: Any] {
        var info: [String: Any] = [
            BuxPadSceneActivity.sessionKey: sessionId.uuidString
        ]
        if let data = try? JSONEncoder().encode(snapshot) {
            info["snapshot"] = data
        }
        if let studioDestination {
            info[BuxPadSceneActivity.studioDestinationKey] = studioDestination
        }
        if let presentationKind {
            info[BuxPadSceneActivity.presentationKindKey] = presentationKind
        }
        return info
    }

    static func sessionId(from userInfo: [AnyHashable: Any]?) -> UUID? {
        guard let raw = userInfo?[BuxPadSceneActivity.sessionKey] as? String else { return nil }
        return UUID(uuidString: raw)
    }

    static func snapshot(from userInfo: [AnyHashable: Any]?) -> BuxPadNavigationSnapshot? {
        guard let data = userInfo?["snapshot"] as? Data else { return nil }
        return try? JSONDecoder().decode(BuxPadNavigationSnapshot.self, from: data)
    }

    static func studioDestination(from userInfo: [AnyHashable: Any]?) -> String? {
        userInfo?[BuxPadSceneActivity.studioDestinationKey] as? String
    }

    static func presentationKind(from userInfo: [AnyHashable: Any]?) -> String? {
        userInfo?[BuxPadSceneActivity.presentationKindKey] as? String
    }
}
