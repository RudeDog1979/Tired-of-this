//
//  BackupNotificationScheduler.swift
//  BuxMuse
//
//  Manages scheduling local recurring notification alerts for backup reminders.
//

import Foundation
import UserNotifications

public final class BackupNotificationScheduler {
    public static func reschedule(frequency: AutoBackupFrequency) async {
        let center = UNUserNotificationCenter.current()
        // Always cancel existing backup reminder first to avoid duplicates
        center.removePendingNotificationRequests(withIdentifiers: ["buxmuse.backup.reminder"])
        
        guard frequency != .off else {
            print("BackupNotificationScheduler: Reminders disabled.")
            return
        }
        
        // Request authorization if needed
        let settings = await center.notificationSettings()
        var isAuthorized = false
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            isAuthorized = true
        case .notDetermined:
            isAuthorized = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        default:
            isAuthorized = false
        }
        
        guard isAuthorized else {
            print("BackupNotificationScheduler: Notifications not authorized.")
            return
        }
        
        let locale = BuxInterfaceLocale.currentInterfaceLocale
        let content = UNMutableNotificationContent()
        content.title = BuxCatalogLabel.string("BuxMuse Backup Reminder", locale: locale)
        content.body = BuxCatalogLabel.string(
            "Protect your ledger data. Open Settings → Data to create an encrypted backup.",
            locale: locale
        )
        content.sound = .default
        
        let interval: TimeInterval
        switch frequency {
        case .weekly:
            interval = 604800
        case .monthly:
            interval = 2592000
        case .custom:
            let days = await MainActor.run { SettingsStore.shared.customBackupIntervalDays }
            interval = TimeInterval(days * 86400)
        default:
            return
        }
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: true)
        let request = UNNotificationRequest(
            identifier: "buxmuse.backup.reminder",
            content: content,
            trigger: trigger
        )
        
        do {
            try await center.add(request)
            print("BackupNotificationScheduler: Scheduled reminder successfully (interval: \(interval)s).")
        } catch {
            print("BackupNotificationScheduler: Failed to schedule reminder: \(error)")
        }
    }
}
