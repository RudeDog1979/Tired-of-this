//
//  BackupNotificationScheduler.swift
//  BuxMuse
//
//  Manages scheduling local recurring notification alerts for backup reminders.
//

import Foundation
import UserNotifications

public final class BackupNotificationScheduler {
    private static let reminderId = "buxmuse.backup.reminder"

    public static func reschedule(frequency: AutoBackupFrequency) async {
        let policy = await MainActor.run { BuxNotificationSettingsSnapshot.current }
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [reminderId])
        center.removeDeliveredNotifications(withIdentifiers: [reminderId])

        guard BuxNotificationPolicy.backupRemindersAllowed(policy) else {
            return
        }

        guard await BuxNotificationPolicy.requestAuthorizationIfNeeded() else { return }

        let locale = BuxInterfaceLocale.currentInterfaceLocale
        let content = UNMutableNotificationContent()
        content.title = BuxCatalogLabel.string("BuxMuse Backup Reminder", locale: locale)
        content.body = BuxCatalogLabel.string(
            "Protect your ledger data. Open Settings → Data to create an encrypted backup.",
            locale: locale
        )
        content.sound = .default
        content.userInfo = BuxNotificationPayload.userInfo(route: .backup)

        let interval: TimeInterval
        switch frequency {
        case .weekly:
            interval = 604_800
        case .monthly:
            interval = 2_592_000
        case .custom:
            let days = await MainActor.run { SettingsStore.shared.customBackupIntervalDays }
            interval = TimeInterval(days * 86_400)
        default:
            return
        }

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: true)
        let request = UNNotificationRequest(
            identifier: reminderId,
            content: content,
            trigger: trigger
        )

        try? await center.add(request)
    }
}
