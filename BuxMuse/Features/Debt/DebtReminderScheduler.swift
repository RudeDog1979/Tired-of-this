//
//  DebtReminderScheduler.swift
//  BuxMuse
//
//  Local due-date reminders for consumer debts.
//

import Foundation
import UserNotifications

enum DebtReminderScheduler {
    private static let leadDays = 3

    private static var isTesting: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil || NSClassFromString("XCTestCase") != nil
    }

    private static func notificationId(_ debtId: UUID) -> String {
        "buxmuse.debt.due.\(debtId.uuidString)"
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

    static func rescheduleAll(debts: [Debt]) async {
        if isTesting { return }
        guard await requestAuthorizationIfNeeded() else { return }
        let activeIds = Set(debts.filter { !$0.isArchived }.map(\.id))
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let staleIds = pending
            .map(\.identifier)
            .filter { $0.hasPrefix("buxmuse.debt.due.") }
            .filter { id in
                guard let uuidString = id.split(separator: ".").last,
                      let uuid = UUID(uuidString: String(uuidString)) else { return true }
                return !activeIds.contains(uuid)
            }
        center.removePendingNotificationRequests(withIdentifiers: staleIds)

        for debt in debts where !debt.isArchived {
            await schedule(for: debt)
        }
    }

    static func cancelAllDebtReminders() async {
        if isTesting { return }
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let ids = pending
            .map(\.identifier)
            .filter { $0.hasPrefix("buxmuse.debt.due.") }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    static func schedule(for debt: Debt) async {
        if isTesting { return }
        cancel(for: debt.id)
        guard debt.remindersEnabled, debt.dueDayOfMonth != nil, debt.currentBalance > 0 else { return }
        guard await requestAuthorizationIfNeeded() else { return }
        guard let fireDate = reminderFireDate(for: debt), fireDate > Date() else { return }

        let locale = BuxInterfaceLocale.currentInterfaceLocale
        let content = UNMutableNotificationContent()
        content.title = BuxCatalogLabel.string("Debt payment due soon", locale: locale)
        content.body = BuxLocalizedString.format(
            "%@ is due in %lld days. Open BuxMuse to log a payment.",
            locale: locale,
            debt.name,
            String(leadDays)
        )
        content.sound = .default

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: fireDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: notificationId(debt.id),
            content: content,
            trigger: trigger
        )
        try? await UNUserNotificationCenter.current().add(request)
    }

    static func cancel(for debtId: UUID) {
        if isTesting { return }
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [notificationId(debtId)]
        )
    }

    static func reminderFireDate(for debt: Debt) -> Date? {
        guard let dueDate = debt.nextDueDate else { return nil }
        var components = Calendar.current.dateComponents([.year, .month, .day], from: dueDate)
        components.hour = 9
        components.minute = 0
        guard let dueMorning = Calendar.current.date(from: components) else { return nil }
        return Calendar.current.date(byAdding: .day, value: -leadDays, to: dueMorning)
    }

    static func upcomingReminders(debts: [Debt]) -> [(debt: Debt, dueDate: Date, daysUntil: Int)] {
        debts
            .filter { !$0.isArchived && $0.remindersEnabled && $0.currentBalance > 0 }
            .compactMap { debt in
                guard let due = debt.nextDueDate, let days = debt.daysUntilDue, days >= 0 else { return nil }
                return (debt, due, days)
            }
            .sorted { $0.daysUntil < $1.daysUntil }
    }
}
