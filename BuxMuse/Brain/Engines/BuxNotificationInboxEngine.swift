//
//  BuxNotificationInboxEngine.swift
//  BuxMuse
//
//  Builds in-app notification inbox and schedules local reminders.
//

import Foundation
import UserNotifications

@MainActor
final class BuxNotificationInboxEngine {
    private let readIdsKey = "buxmuse.notifications.readIds"
    private let dismissedIdsKey = "buxmuse.notifications.dismissedIds"

    func rebuildInbox(
        settings: SettingsStore,
        dashSnapshot: DashboardSnapshot,
        expenseRecords: [ExpenseRecord],
        studioAlerts: [StudioAlertDisplay],
        studioInvoices: [StudioInvoice],
        taxDeadlineDays: Int?,
        tipsHistory: [HistoricalTipRecord],
        currencyFormatter: (Decimal) -> String
    ) -> NotificationInboxDisplay {
        guard settings.notificationsEnabled else {
            return NotificationInboxDisplay(items: [], unreadCount: 0)
        }

        var items: [AppNotificationItem] = []
        let now = Date()

        for tip in tipsHistory {
            items.append(AppNotificationItem(
                id: "tip-\(tip.id)",
                title: tip.title,
                message: tip.message,
                date: tip.date,
                category: .digest,
                isRead: true,
                severity: "low"
            ))
        }

        if settings.budgetAlertsEnabled, let budgetName = dashSnapshot.activeBudgetName {
            let limit = dashSnapshot.activeBudgetLimit
            let spent = dashSnapshot.activeBudgetSpent
            if limit > 0 {
                let ratio = NSDecimalNumber(decimal: spent / limit).doubleValue
                if ratio >= 0.9 {
                    items.append(AppNotificationItem(
                        id: "budget-warning-\(budgetName)",
                        title: "Budget nearly exhausted",
                        message: "\(budgetName): \(currencyFormatter(spent)) spent of \(currencyFormatter(limit)).",
                        date: now,
                        category: .budget,
                        isRead: false,
                        severity: ratio >= 1.0 ? "high" : "medium"
                    ))
                }
            }
        }

        if settings.billRemindersEnabled {
            for record in expenseRecords where record.isSubscriptionLike || record.isTrial {
                if let next = record.nextExpectedDate, next > now {
                    let days = Calendar.current.dateComponents([.day], from: now, to: next).day ?? 0
                    if days <= 7 {
                        items.append(AppNotificationItem(
                            id: "bill-\(record.id.uuidString)",
                            title: record.isTrial ? "Trial ending soon" : "Upcoming renewal",
                            message: "\(record.name) — due in \(days) day(s).",
                            date: next,
                            category: .bill,
                            isRead: false,
                            severity: days <= 2 ? "high" : "medium"
                        ))
                    }
                }
            }
        }

        if settings.dailySummaryEnabled {
            let todayStart = Calendar.current.startOfDay(for: now)
            let dayKey = {
                let f = DateFormatter()
                f.dateFormat = "yyyy-MM-dd"
                return f.string(from: now)
            }()
            let todaySpend = expenseRecords
                .filter { $0.date >= todayStart && $0.amountValue < 0 }
                .reduce(Decimal(0)) { $0 + abs($1.amountValue) }
            let todayCount = expenseRecords.filter { $0.date >= todayStart }.count

            var parts: [String] = []
            parts.append("Today's spend: \(currencyFormatter(todaySpend))")
            if todayCount > 0 {
                parts.append("\(todayCount) transaction(s) logged")
            }
            if dashSnapshot.subscriptionCount > 0 {
                parts.append("\(dashSnapshot.subscriptionCount) active subscription(s)")
            }
            if let budgetName = dashSnapshot.activeBudgetName, dashSnapshot.activeBudgetLimit > 0 {
                parts.append(
                    "\(budgetName): \(currencyFormatter(dashSnapshot.activeBudgetSpent)) of \(currencyFormatter(dashSnapshot.activeBudgetLimit))"
                )
            }

            items.append(AppNotificationItem(
                id: "daily-summary-\(dayKey)",
                title: "Daily Financial Summary",
                message: parts.joined(separator: " · "),
                date: now,
                category: .digest,
                isRead: false,
                severity: "low"
            ))
        }

        if settings.studioEnabled {
            for alert in studioAlerts {
                items.append(AppNotificationItem(
                    id: "studio-\(alert.id)",
                    title: alert.title,
                    message: alert.message,
                    date: now,
                    category: .studio,
                    isRead: false,
                    severity: alert.severity
                ))
            }

            if settings.studioInvoiceRemindersEnabled {
                for invoice in studioInvoices where invoice.status == .sent || invoice.status == .overdue {
                    let title = invoice.status == .overdue ? "Invoice overdue" : "Invoice due soon"
                    items.append(AppNotificationItem(
                        id: "invoice-\(invoice.id.uuidString)",
                        title: title,
                        message: "Invoice #\(invoice.invoiceNumber) — due \(formattedDate(invoice.dueDate)).",
                        date: invoice.dueDate,
                        category: .invoice,
                        isRead: false,
                        severity: invoice.status == .overdue ? "high" : "medium"
                    ))
                }
            }

            if settings.taxDeadlineRemindersEnabled, let days = taxDeadlineDays, days <= 30 {
                items.append(AppNotificationItem(
                    id: "tax-deadline-\(days)",
                    title: "Tax deadline approaching",
                    message: "\(days) day(s) until your next scheduled tax payment.",
                    date: now,
                    category: .tax,
                    isRead: false,
                    severity: days <= 14 ? "high" : "medium"
                ))
            }
        }

        let readIds = Set(UserDefaults.standard.stringArray(forKey: readIdsKey) ?? [])
        let dismissedIds = Set(UserDefaults.standard.stringArray(forKey: dismissedIdsKey) ?? [])
        items = items.map { item in
            var copy = item
            copy.isRead = readIds.contains(item.id)
            return copy
        }
        .filter { !dismissedIds.contains($0.id) }
        .sorted { $0.date > $1.date }

        let unread = items.filter { !$0.isRead }.count
        return NotificationInboxDisplay(items: items, unreadCount: unread)
    }

    func markRead(_ id: String) {
        var ids = Set(UserDefaults.standard.stringArray(forKey: readIdsKey) ?? [])
        ids.insert(id)
        UserDefaults.standard.set(Array(ids), forKey: readIdsKey)
    }

    func markAllRead(_ ids: [String]) {
        var stored = Set(UserDefaults.standard.stringArray(forKey: readIdsKey) ?? [])
        ids.forEach { stored.insert($0) }
        UserDefaults.standard.set(Array(stored), forKey: readIdsKey)
    }

    func dismiss(_ id: String) {
        var ids = Set(UserDefaults.standard.stringArray(forKey: dismissedIdsKey) ?? [])
        ids.insert(id)
        UserDefaults.standard.set(Array(ids), forKey: dismissedIdsKey)
        markRead(id)
    }

    func dismissAll(_ ids: [String]) {
        var stored = Set(UserDefaults.standard.stringArray(forKey: dismissedIdsKey) ?? [])
        ids.forEach { stored.insert($0) }
        UserDefaults.standard.set(Array(stored), forKey: dismissedIdsKey)
        markAllRead(ids)
    }

    func syncLocalNotifications(
        settings: SettingsStore,
        inbox: NotificationInboxDisplay
    ) async {
        guard settings.notificationsEnabled else {
            await cancelAllManagedNotifications()
            return
        }
        guard await requestAuthorizationIfNeeded() else { return }

        await cancelAllManagedNotifications()

        for item in inbox.items {
            switch item.category {
            case .invoice, .tax, .budget, .bill, .studio, .digest:
                await schedule(item: item, settings: settings)
            default:
                break
            }
        }
    }

    // MARK: - Private

    private func formattedDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f.string(from: date)
    }

    private func managedNotificationId(_ itemId: String) -> String {
        "buxmuse.inbox.\(itemId)"
    }

    private func requestAuthorizationIfNeeded() async -> Bool {
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

    private func cancelAllManagedNotifications() async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let ids = pending.map(\.identifier).filter { $0.hasPrefix("buxmuse.inbox.") }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    private func schedule(item: AppNotificationItem, settings: SettingsStore) async {
        guard !isWithinQuietHours(settings) else { return }

        let fireDate = max(Date().addingTimeInterval(60), item.date)
        guard fireDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = item.title
        content.body = item.message
        content.sound = .default

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: managedNotificationId(item.id),
            content: content,
            trigger: trigger
        )
        try? await UNUserNotificationCenter.current().add(request)
    }

    private func isWithinQuietHours(_ settings: SettingsStore) -> Bool {
        let calendar = Calendar.current
        let now = calendar.dateComponents([.hour, .minute], from: Date())
        guard let hour = now.hour, let minute = now.minute else { return false }
        let current = hour * 60 + minute
        let start = settings.quietHoursStartHour * 60 + settings.quietHoursStartMinute
        let end = settings.quietHoursEndHour * 60 + settings.quietHoursEndMinute
        if start <= end {
            return current >= start && current < end
        }
        return current >= start || current < end
    }
}
