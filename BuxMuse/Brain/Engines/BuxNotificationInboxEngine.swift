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
    private let pushedIdsKey = "buxmuse.notifications.pushedIds"

    func rebuildInbox(
        settings: SettingsStore,
        dashSnapshot: DashboardSnapshot,
        expenseRecords: [ExpenseRecord],
        studioAlerts: [StudioAlertDisplay],
        studioInvoices: [StudioInvoice],
        taxDeadlineDays: Int?,
        tipsHistory: [HistoricalTipRecord],
        currencyFormatter: (Decimal) -> String,
        locale: Locale = BuxInterfaceLocale.currentInterfaceLocale
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

        if settings.budgetAlertsEnabled {
            let threshold = Double(max(1, min(100, dashSnapshot.approachingThresholdPercent))) / 100.0

            if dashSnapshot.budgetingMode == .envelope, !dashSnapshot.envelopeBudgets.isEmpty {
                for envelope in dashSnapshot.envelopeBudgets where envelope.effectiveLimit > 0 {
                    guard envelope.status != .ok else { continue }
                    let title: String
                    let severity: String
                    switch envelope.status {
                    case .over:
                        title = line("Envelope over limit", locale: locale)
                        severity = "high"
                    case .atLimit:
                        title = line("Envelope empty", locale: locale)
                        severity = "high"
                    case .approaching:
                        title = line("Envelope approaching limit", locale: locale)
                        severity = "medium"
                    case .ok:
                        continue
                    }
                    items.append(AppNotificationItem(
                        id: "envelope-\(envelope.id.uuidString)-\(envelope.status.rawValue)",
                        title: title,
                        message: format(
                            "%@: %@ of %@.",
                            locale: locale,
                            envelope.name,
                            currencyFormatter(envelope.spent),
                            currencyFormatter(envelope.effectiveLimit)
                        ),
                        date: now,
                        category: .budget,
                        isRead: false,
                        severity: severity
                    ))
                }
            } else if let budgetName = dashSnapshot.activeBudgetName {
                let limit = dashSnapshot.activeBudgetLimit
                let spent = dashSnapshot.activeBudgetSpent
                if limit > 0 {
                    let ratio = NSDecimalNumber(decimal: spent / limit).doubleValue
                    if ratio >= threshold {
                        items.append(AppNotificationItem(
                            id: "budget-warning-\(budgetName)",
                            title: line("Budget nearly exhausted", locale: locale),
                            message: format(
                                "%@: %@ spent of %@.",
                                locale: locale,
                                budgetName,
                                currencyFormatter(spent),
                                currencyFormatter(limit)
                            ),
                            date: now,
                            category: .budget,
                            isRead: false,
                            severity: ratio >= 1.0 ? "high" : "medium"
                        ))
                    }
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
                            title: line(record.isTrial ? "Trial ending soon" : "Upcoming renewal", locale: locale),
                            message: format(
                                "%@ — due in %lld day(s).",
                                locale: locale,
                                record.name,
                                Int64(days)
                            ),
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
            parts.append(format("Today's spend: %@", locale: locale, currencyFormatter(todaySpend)))
            if todayCount > 0 {
                parts.append(format("%lld transaction(s) logged", locale: locale, Int64(todayCount)))
            }
            if dashSnapshot.subscriptionCount > 0 {
                parts.append(format("%lld active subscription(s)", locale: locale, Int64(dashSnapshot.subscriptionCount)))
            }
            if let budgetName = dashSnapshot.activeBudgetName, dashSnapshot.activeBudgetLimit > 0 {
                parts.append(format(
                    "%@: %@ of %@",
                    locale: locale,
                    budgetName,
                    currencyFormatter(dashSnapshot.activeBudgetSpent),
                    currencyFormatter(dashSnapshot.activeBudgetLimit)
                ))
            }

            items.append(AppNotificationItem(
                id: "daily-summary-\(dayKey)",
                title: line("Daily Financial Summary", locale: locale),
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
                    let title = line(
                        invoice.status == .overdue ? "Invoice overdue" : "Invoice due soon",
                        locale: locale
                    )
                    items.append(AppNotificationItem(
                        id: "invoice-\(invoice.id.uuidString)",
                        title: title,
                        message: format(
                            "Invoice #%@ — due %@.",
                            locale: locale,
                            invoice.invoiceNumber,
                            formattedDate(invoice.dueDate, locale: locale)
                        ),
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
                    title: line("Tax deadline approaching", locale: locale),
                    message: format(
                        "%lld day(s) until your next scheduled tax payment.",
                        locale: locale,
                        Int64(days)
                    ),
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
        cancelPendingNotification(for: id)
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
        removePushedId(id)
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
            savePushedIds([])
            return
        }
        guard await requestAuthorizationIfNeeded() else { return }

        let eligible = inbox.items.filter { !$0.isRead && isSchedulableCategory($0.category) }
        let desiredNotificationIds = Set(eligible.map { managedNotificationId($0.id) })

        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let managedPendingIds = Set(
            pending.map(\.identifier).filter { $0.hasPrefix("buxmuse.inbox.") }
        )

        let stalePending = managedPendingIds.subtracting(desiredNotificationIds)
        if !stalePending.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: Array(stalePending))
        }

        var pushedIds = pushedIdsSet()
        let activeItemIds = Set(inbox.items.map(\.id))
        pushedIds = pushedIds.intersection(activeItemIds)

        for item in eligible {
            guard !pushedIds.contains(item.id) else { continue }
            let notificationId = managedNotificationId(item.id)
            guard !managedPendingIds.contains(notificationId) else { continue }
            if await schedule(item: item, settings: settings) {
                pushedIds.insert(item.id)
            }
        }

        savePushedIds(pushedIds)
    }

    // MARK: - Private

    private func formattedDate(_ date: Date, locale: Locale) -> String {
        let f = DateFormatter()
        f.locale = locale
        f.dateStyle = .medium
        f.timeStyle = .none
        return f.string(from: date)
    }

    private func line(_ key: String, locale: Locale) -> String {
        BuxCatalogLabel.string(key, locale: locale)
    }

    private func format(_ key: String, locale: Locale, _ arguments: CVarArg...) -> String {
        BuxLocalizedString.format(key, locale: locale, arguments)
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

    private func schedule(item: AppNotificationItem, settings: SettingsStore) async -> Bool {
        guard !isWithinQuietHours(settings) else { return false }
        guard let fireDate = fireDate(for: item), fireDate > Date() else { return false }

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
        do {
            try await UNUserNotificationCenter.current().add(request)
            return true
        } catch {
            return false
        }
    }

    private func isSchedulableCategory(_ category: AppNotificationCategory) -> Bool {
        switch category {
        case .invoice, .tax, .budget, .bill, .studio, .digest:
            return true
        default:
            return false
        }
    }

    private func fireDate(for item: AppNotificationItem) -> Date? {
        let now = Date()
        if item.id.hasPrefix("daily-summary-") {
            return dailySummaryFireDate(from: now)
        }
        if item.date > now {
            return item.date
        }
        return now.addingTimeInterval(180)
    }

    private func dailySummaryFireDate(from now: Date) -> Date? {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = 20
        components.minute = 0
        guard var target = calendar.date(from: components) else { return nil }
        if target <= now {
            target = calendar.date(byAdding: .day, value: 1, to: target) ?? target
        }
        return target
    }

    private func pushedIdsSet() -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: pushedIdsKey) ?? [])
    }

    private func savePushedIds(_ ids: Set<String>) {
        UserDefaults.standard.set(Array(ids), forKey: pushedIdsKey)
    }

    private func removePushedId(_ id: String) {
        var ids = pushedIdsSet()
        ids.remove(id)
        savePushedIds(ids)
    }

    private func cancelPendingNotification(for itemId: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [managedNotificationId(itemId)]
        )
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
