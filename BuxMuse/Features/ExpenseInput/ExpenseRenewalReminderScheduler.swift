//
//  ExpenseRenewalReminderScheduler.swift
//  BuxMuse
//
//  Local notifications for subscription / trial renewal reminders.
//

import Foundation
import UserNotifications

enum ExpenseRenewalReminderScheduler {
    private static var isTesting: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil || NSClassFromString("XCTestCase") != nil
    }

    private static func notificationId(_ expenseId: UUID) -> String {
        "buxmuse.expense.renewal.\(expenseId.uuidString)"
    }

    static func requestAuthorizationIfNeeded() async -> Bool {
        await BuxNotificationPolicy.requestAuthorizationIfNeeded()
    }

    static func rescheduleAll(records: [ExpenseRecord]) async {
        if isTesting { return }
        let policy = await MainActor.run { BuxNotificationSettingsSnapshot.current }
        guard BuxNotificationPolicy.billRemindersAllowed(policy) else {
            cancelAll()
            return
        }
        guard await requestAuthorizationIfNeeded() else { return }

        let activeIds = Set(records.map(\.id))
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let staleIds = pending
            .map(\.identifier)
            .filter { $0.hasPrefix("buxmuse.expense.renewal.") }
            .filter { id in
                guard let uuidString = id.split(separator: ".").last,
                      let uuid = UUID(uuidString: String(uuidString)) else { return true }
                return !activeIds.contains(uuid)
            }
        center.removePendingNotificationRequests(withIdentifiers: staleIds)

        for record in records {
            await schedule(for: record)
        }
    }

    static func schedule(for record: ExpenseRecord) async {
        if isTesting { return }
        let policy = await MainActor.run { BuxNotificationSettingsSnapshot.current }
        guard BuxNotificationPolicy.billRemindersAllowed(policy) else {
            cancel(for: record.id)
            return
        }
        guard record.isSubscriptionLike || record.isTrial else {
            cancel(for: record.id)
            return
        }
        guard await requestAuthorizationIfNeeded() else { return }
        guard var fireDate = reminderFireDate(for: record) else {
            cancel(for: record.id)
            return
        }
        if let adjusted = BuxNotificationPolicy.adjustedFireDate(fireDate, settings: policy) {
            fireDate = adjusted
        }
        guard fireDate > Date() else {
            cancel(for: record.id)
            return
        }

        cancel(for: record.id)

        let locale = BuxInterfaceLocale.currentInterfaceLocale
        let content = UNMutableNotificationContent()
        if record.isTrial {
            content.title = BuxCatalogLabel.string("Trial ending soon", locale: locale)
            content.body = BuxLocalizedString.format(
                "%@ trial ends soon — review before you're charged.",
                locale: locale,
                record.name
            )
        } else {
            content.title = BuxCatalogLabel.string("Subscription renewal", locale: locale)
            content.body = BuxLocalizedString.format(
                "%@ renews soon. Tap to review in BuxMuse.",
                locale: locale,
                record.name
            )
        }
        content.sound = .default
        content.userInfo = BuxNotificationPayload.userInfo(
            route: .expense,
            entityId: record.id.uuidString
        )

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
        if isTesting { return }
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [notificationId(expenseId)]
        )
    }

    static func cancelAll() {
        if isTesting { return }
        BuxNotificationPolicy.cancelNotifications(withPrefix: "buxmuse.expense.renewal.")
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
