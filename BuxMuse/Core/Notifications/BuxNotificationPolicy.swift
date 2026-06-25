//
//  BuxNotificationPolicy.swift
//  BuxMuse — shared notification gating, quiet hours, and cancellation.
//

import Foundation
import UserNotifications

struct BuxNotificationSettingsSnapshot: Sendable {
    var notificationsEnabled: Bool
    var billRemindersEnabled: Bool
    var budgetAlertsEnabled: Bool
    var allowLocalBackups: Bool
    var backupFrequencyIsOff: Bool
    var studioEnabled: Bool
    var quietHoursStartHour: Int
    var quietHoursStartMinute: Int
    var quietHoursEndHour: Int
    var quietHoursEndMinute: Int

    @MainActor
    init(settings: SettingsStore) {
        notificationsEnabled = settings.notificationsEnabled
        billRemindersEnabled = settings.billRemindersEnabled
        budgetAlertsEnabled = settings.budgetAlertsEnabled
        allowLocalBackups = settings.allowLocalBackups
        backupFrequencyIsOff = settings.autoBackupFrequency == .off
        studioEnabled = settings.studioEnabled
        quietHoursStartHour = settings.quietHoursStartHour
        quietHoursStartMinute = settings.quietHoursStartMinute
        quietHoursEndHour = settings.quietHoursEndHour
        quietHoursEndMinute = settings.quietHoursEndMinute
    }

    @MainActor
    static var current: BuxNotificationSettingsSnapshot {
        BuxNotificationSettingsSnapshot(settings: .shared)
    }
}

enum BuxNotificationPolicy {
    private static var isTesting: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            || NSClassFromString("XCTestCase") != nil
    }

    static let managedPrefixes = [
        "buxmuse.inbox.",
        "buxmuse.expense.renewal.",
        "buxmuse.debt.due.",
        "buxmuse.studio.timer.",
        "buxmuse.backup.reminder"
    ]

    static func notificationsAllowed(_ settings: BuxNotificationSettingsSnapshot) -> Bool {
        settings.notificationsEnabled
    }

    static func billRemindersAllowed(_ settings: BuxNotificationSettingsSnapshot) -> Bool {
        settings.notificationsEnabled && settings.billRemindersEnabled
    }

    static func budgetAlertsAllowed(_ settings: BuxNotificationSettingsSnapshot) -> Bool {
        settings.notificationsEnabled && settings.budgetAlertsEnabled
    }

    static func backupRemindersAllowed(_ settings: BuxNotificationSettingsSnapshot) -> Bool {
        settings.notificationsEnabled
            && settings.allowLocalBackups
            && !settings.backupFrequencyIsOff
    }

    static func studioTimerAllowed(_ settings: BuxNotificationSettingsSnapshot) -> Bool {
        settings.notificationsEnabled && settings.studioEnabled
    }

    static func isWithinQuietHours(_ settings: BuxNotificationSettingsSnapshot, at date: Date = Date()) -> Bool {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: date)
        guard let hour = components.hour, let minute = components.minute else { return false }
        let current = hour * 60 + minute
        let start = settings.quietHoursStartHour * 60 + settings.quietHoursStartMinute
        let end = settings.quietHoursEndHour * 60 + settings.quietHoursEndMinute
        if start <= end {
            return current >= start && current < end
        }
        return current >= start || current < end
    }

    static func adjustedFireDate(_ proposed: Date, settings: BuxNotificationSettingsSnapshot) -> Date? {
        if isWithinQuietHours(settings, at: proposed) {
            return nextQuietHoursEnd(from: proposed, settings: settings)
        }
        return proposed
    }

    private static func nextQuietHoursEnd(from date: Date, settings: BuxNotificationSettingsSnapshot) -> Date? {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = settings.quietHoursEndHour
        components.minute = settings.quietHoursEndMinute
        components.second = 0
        guard var candidate = calendar.date(from: components) else { return nil }
        if candidate <= date {
            candidate = calendar.date(byAdding: .day, value: 1, to: candidate) ?? candidate
        }
        return candidate
    }

    static func requestAuthorizationIfNeeded() async -> Bool {
        if isTesting { return false }
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

    static func authorizationStatus() async -> UNAuthorizationStatus {
        if isTesting { return .denied }
        return await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    static func cancelAllScheduledNotifications() async {
        if isTesting { return }
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let delivered = await center.deliveredNotifications()

        let pendingIds = pending.map(\.identifier).filter(matchesManagedIdentifier)
        let deliveredIds = delivered.map(\.request.identifier).filter(matchesManagedIdentifier)

        if !pendingIds.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: pendingIds)
        }
        if !deliveredIds.isEmpty {
            center.removeDeliveredNotifications(withIdentifiers: deliveredIds)
        }
    }

    static func cancelNotifications(withPrefix prefix: String) {
        if isTesting { return }
        Task {
            let center = UNUserNotificationCenter.current()
            let pending = await center.pendingNotificationRequests()
            let delivered = await center.deliveredNotifications()
            let pendingIds = pending.map(\.identifier).filter { $0.hasPrefix(prefix) }
            let deliveredIds = delivered.map(\.request.identifier).filter { $0.hasPrefix(prefix) }
            if !pendingIds.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: pendingIds)
            }
            if !deliveredIds.isEmpty {
                center.removeDeliveredNotifications(withIdentifiers: deliveredIds)
            }
        }
    }

    private static func matchesManagedIdentifier(_ identifier: String) -> Bool {
        managedPrefixes.contains { identifier.hasPrefix($0) || identifier == String($0.dropLast()) }
    }
}
