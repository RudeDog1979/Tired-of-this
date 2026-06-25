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

    static func purgePersistedState() {
        UserDefaults.standard.removeObject(forKey: "buxmuse.notifications.readIds")
        UserDefaults.standard.removeObject(forKey: "buxmuse.notifications.dismissedIds")
        UserDefaults.standard.removeObject(forKey: "buxmuse.notifications.pushedIds")
    }

    func rebuildInbox(
        settings: SettingsStore,
        dashSnapshot: DashboardSnapshot,
        expenseRecords: [ExpenseRecord],
        debts: [Debt] = [],
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
                        id: "envelope-\(envelope.id.uuidString)",
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
                            id: "budget-warning-active",
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
                            category: record.isSubscriptionLike ? .subscription : .bill,
                            isRead: false,
                            severity: days <= 2 ? "high" : "medium"
                        ))
                    }
                }
            }

            for reminder in DebtReminderScheduler.upcomingReminders(debts: debts) where reminder.daysUntil <= 7 {
                items.append(AppNotificationItem(
                    id: "debt-\(reminder.debt.id.uuidString)",
                    title: line("Debt payment due soon", locale: locale),
                    message: format(
                        "%@ — due in %lld day(s).",
                        locale: locale,
                        reminder.debt.name,
                        Int64(reminder.daysUntil)
                    ),
                    date: reminder.dueDate,
                    category: .debt,
                    isRead: false,
                    severity: reminder.daysUntil <= 2 ? "high" : "medium"
                ))
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

        let studioIncludesTaxDeadline = studioAlerts.contains { $0.id == "tax-deadline" }

        if settings.studioEnabled {
            for alert in studioAlerts {
                let inboxId = alert.id == "tax-deadline" ? "tax-deadline" : "studio-\(alert.id)"
                items.append(AppNotificationItem(
                    id: inboxId,
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

            if settings.taxDeadlineRemindersEnabled,
               let days = taxDeadlineDays,
               days <= 30,
               !studioIncludesTaxDeadline {
                items.append(AppNotificationItem(
                    id: "tax-deadline",
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
            if item.id.hasPrefix("tip-") {
                // Historical tips are inbox archive rows — not actionable unread alerts.
                copy.isRead = true
            } else {
                copy.isRead = readIds.contains(item.id)
            }
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
        ids.forEach { id in
            stored.insert(id)
            cancelPendingNotification(for: id)
        }
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

        let eligible = inbox.items.filter { shouldScheduleLocalPush(for: $0) }
        let desiredNotificationIds = Set(eligible.map { managedNotificationId($0.id) })

        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let allPendingIds = Set(pending.map(\.identifier))
        let managedPendingIds = Set(
            pending.map(\.identifier).filter { $0.hasPrefix("buxmuse.inbox.") }
        )
        let delivered = await center.deliveredNotifications()
        let allDeliveredIds = Set(delivered.map(\.request.identifier))
        let managedDeliveredIds = Set(
            delivered.map(\.request.identifier).filter { $0.hasPrefix("buxmuse.inbox.") }
        )

        let stalePending = managedPendingIds.subtracting(desiredNotificationIds)
        if !stalePending.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: Array(stalePending))
        }

        var pushedIds = pushedIdsSet()
        let activeItemIds = Set(inbox.items.map(\.id))
        pushedIds = pushedIds.intersection(activeItemIds)

        for deliveredId in managedDeliveredIds {
            pushedIds.insert(inboxItemId(fromManagedNotificationId: deliveredId))
        }

        for item in eligible {
            if pushedIds.contains(item.id) { continue }

            if let expenseId = billExpenseId(from: item.id) {
                let renewalId = expenseRenewalNotificationId(expenseId)
                if allPendingIds.contains(renewalId) || allDeliveredIds.contains(renewalId) {
                    pushedIds.insert(item.id)
                    continue
                }
            }

            if let debtId = debtId(from: item.id) {
                let debtNotifId = debtNotificationId(debtId)
                if allPendingIds.contains(debtNotifId) || allDeliveredIds.contains(debtNotifId) {
                    pushedIds.insert(item.id)
                    continue
                }
            }

            let notificationId = managedNotificationId(item.id)
            if managedPendingIds.contains(notificationId) {
                pushedIds.insert(item.id)
                continue
            }
            if managedDeliveredIds.contains(notificationId) {
                pushedIds.insert(item.id)
                continue
            }
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
        await BuxNotificationPolicy.requestAuthorizationIfNeeded()
    }

    private func cancelAllManagedNotifications() async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let ids = pending.map(\.identifier).filter { $0.hasPrefix("buxmuse.inbox.") }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    private func schedule(item: AppNotificationItem, settings: SettingsStore) async -> Bool {
        let policy = BuxNotificationSettingsSnapshot(settings: settings)
        guard !BuxNotificationPolicy.isWithinQuietHours(policy) else { return false }
        guard var fireDate = fireDate(for: item) else { return false }
        if let adjusted = BuxNotificationPolicy.adjustedFireDate(fireDate, settings: policy) {
            fireDate = adjusted
        }
        guard fireDate > Date() else { return false }

        let content = UNMutableNotificationContent()
        content.title = item.title
        content.body = item.message
        content.sound = .default
        content.userInfo = BuxNotificationPayload.userInfo(
            route: .inboxItem,
            itemId: item.id,
            category: item.category
        )

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

    private func shouldScheduleLocalPush(for item: AppNotificationItem) -> Bool {
        guard !item.isRead else { return false }
        if item.id.hasPrefix("tip-") { return false }
        return isSchedulableCategory(item.category)
    }

    private func isSchedulableCategory(_ category: AppNotificationCategory) -> Bool {
        switch category {
        case .invoice, .tax, .budget, .bill, .subscription, .debt, .studio, .digest:
            return true
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

    /// Daily digest fires once per calendar day at 8:00 PM local time.
    private func dailySummaryFireDate(from now: Date) -> Date? {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = 20
        components.minute = 0
        components.second = 0
        guard let todayAtEight = calendar.date(from: components) else { return nil }
        if now < todayAtEight {
            return todayAtEight
        }
        return calendar.date(byAdding: .day, value: 1, to: todayAtEight)
    }

    private func inboxItemId(fromManagedNotificationId notificationId: String) -> String {
        String(notificationId.dropFirst("buxmuse.inbox.".count))
    }

    private func billExpenseId(from itemId: String) -> UUID? {
        guard itemId.hasPrefix("bill-") else { return nil }
        return UUID(uuidString: String(itemId.dropFirst(5)))
    }

    private func debtId(from itemId: String) -> UUID? {
        guard itemId.hasPrefix("debt-") else { return nil }
        return UUID(uuidString: String(itemId.dropFirst(5)))
    }

    private func debtNotificationId(_ debtId: UUID) -> String {
        "buxmuse.debt.due.\(debtId.uuidString)"
    }

    private func expenseRenewalNotificationId(_ expenseId: UUID) -> String {
        "buxmuse.expense.renewal.\(expenseId.uuidString)"
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
}
