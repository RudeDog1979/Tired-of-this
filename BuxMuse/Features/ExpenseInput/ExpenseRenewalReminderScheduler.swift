//
//  ExpenseRenewalReminderScheduler.swift
//  BuxMuse
//
//  Local notifications for subscription / trial renewal reminders.
//

import Foundation
import UserNotifications

enum ExpenseRenewalReminderScheduler {
    private static func notificationId(_ expenseId: UUID) -> String {
        "buxmuse.expense.renewal.\(expenseId.uuidString)"
    }

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

    static func schedule(for record: ExpenseRecord) async {
        guard record.isSubscriptionLike || record.isTrial else {
            cancel(for: record.id)
            return
        }
        guard await requestAuthorizationIfNeeded() else { return }
        guard let fireDate = reminderFireDate(for: record), fireDate > Date() else {
            cancel(for: record.id)
            return
        }

        cancel(for: record.id)

        let content = UNMutableNotificationContent()
        if record.isTrial {
            content.title = "Trial ending soon"
            content.body = "\(record.name) trial ends soon — review before you're charged."
        } else {
            content.title = "Subscription renewal"
            content.body = "\(record.name) renews soon. Tap to review in BuxMuse."
        }
        content.sound = .default

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: fireDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: notificationId(record.id),
            content: content,
            trigger: trigger
        )
        try? await UNUserNotificationCenter.current().add(request)
    }

    static func cancel(for expenseId: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [notificationId(expenseId)]
        )
    }

    static func reminderFireDate(for record: ExpenseRecord) -> Date? {
        let leadDays = max(1, record.renewalReminderDays ?? 3)
        let eventDate: Date?
        if record.isTrial {
            eventDate = record.trialEndDate
        } else {
            eventDate = record.nextExpectedDate
                ?? Calendar.current.date(byAdding: .month, value: 1, to: record.subscriptionStartDate ?? record.date)
        }
        guard let eventDate else { return nil }
        return Calendar.current.date(byAdding: .day, value: -leadDays, to: eventDate)
    }
}
