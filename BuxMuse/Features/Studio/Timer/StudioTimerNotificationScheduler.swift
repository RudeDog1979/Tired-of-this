//
//  StudioTimerNotificationScheduler.swift
//  BuxMuse
//
//  Local notifications when a job-time estimate is nearly done or reached.
//

import Foundation
import UserNotifications

enum StudioTimerNotificationScheduler {
    private static let approachingId = "buxmuse.studio.timer.approaching"
    private static let atGoalId = "buxmuse.studio.timer.atgoal"

    static func requestAuthorizationIfNeeded() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        default:
            return false
        }
    }

    static func notifyApproaching(projectName: String, minutesLeft: Int) {
        Task {
            guard await requestAuthorizationIfNeeded() else { return }
            cancelAll()
            let locale = BuxInterfaceLocale.currentInterfaceLocale
            let content = UNMutableNotificationContent()
            content.title = BuxCatalogLabel.string("Job time almost up", locale: locale)
            content.body = BuxLocalizedString.format(
                "%@: about %lld min left on your estimate.",
                locale: locale,
                projectName,
                Int64(max(1, minutesLeft))
            )
            content.sound = .default
            let request = UNNotificationRequest(
                identifier: approachingId,
                content: content,
                trigger: nil
            )
            try? await UNUserNotificationCenter.current().add(request)
        }
    }

    static func notifyAtGoal(projectName: String) {
        Task {
            guard await requestAuthorizationIfNeeded() else { return }
            cancelAll()
            let locale = BuxInterfaceLocale.currentInterfaceLocale
            let content = UNMutableNotificationContent()
            content.title = BuxCatalogLabel.string("Estimate reached", locale: locale)
            content.body = BuxLocalizedString.format(
                "%@: planned time is up. Still working? Add time or finish in BuxMuse.",
                locale: locale,
                projectName
            )
            content.sound = .default
            let request = UNNotificationRequest(
                identifier: atGoalId,
                content: content,
                trigger: nil
            )
            try? await UNUserNotificationCenter.current().add(request)
        }
    }

    static func cancelAll() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [approachingId, atGoalId]
        )
        UNUserNotificationCenter.current().removeDeliveredNotifications(
            withIdentifiers: [approachingId, atGoalId]
        )
    }
}
