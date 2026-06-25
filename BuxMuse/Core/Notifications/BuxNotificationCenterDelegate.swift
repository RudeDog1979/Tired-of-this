//
//  BuxNotificationCenterDelegate.swift
//  BuxMuse — foreground presentation and tap routing for local notifications.
//

import Foundation
import UserNotifications

@MainActor
final class BuxNotificationCenterDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = BuxNotificationCenterDelegate()

    weak var navigationCoordinator: NavigationCoordinator?
    weak var brain: BuxMuseBrain?

    private override init() {
        super.init()
    }

    func configure(navigation: NavigationCoordinator, brain: BuxMuseBrain) {
        navigationCoordinator = navigation
        self.brain = brain
        UNUserNotificationCenter.current().delegate = self
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping @Sendable () -> Void
    ) {
        // String literals only — must match BuxNotificationUserInfoKey raw values.
        // Cannot reference that enum here: delegate callbacks are nonisolated under default @MainActor isolation.
        let userInfo = response.notification.request.content.userInfo
        let routeRaw = userInfo["bux_route"] as? String
        let itemId = userInfo["bux_item_id"] as? String
        let entityId = userInfo["bux_entity_id"] as? String
        let categoryRaw = userInfo["bux_category"] as? String

        Task { @MainActor in
            guard let navigation = self.navigationCoordinator else {
                completionHandler()
                return
            }
            let payload = BuxNotificationTapPayload(
                routeRaw: routeRaw,
                itemId: itemId,
                entityId: entityId,
                categoryRaw: categoryRaw
            )
            BuxNotificationRouter.apply(
                payload: payload,
                navigation: navigation,
                brain: self.brain
            )
            completionHandler()
        }
    }
}
