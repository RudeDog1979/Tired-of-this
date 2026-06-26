//
//  BuxMuseBrain+Engagement.swift
//  BuxMuse
//
//  Tips, notifications inbox — all fetch/logic lives in the brain.
//

import Foundation

extension BuxMuseBrain {
    // MARK: - Tips

    public func refreshTips(countryCode: String, force: Bool = false) async {
        let shouldFetch = tipsEngine.shouldFetchRemote(countryCode: countryCode, force: force)
        if !shouldFetch {
            let cachedTip = tipsEngine.dailyTip(for: countryCode)
            guard cachedTip.id != dailyTipDisplay.id else { return }
        }

        let isNewDay = tipsEngine.isNewTipDaySinceLastFetch(countryCode: countryCode)
        if shouldFetch {
            await tipsEngine.refreshIfNeeded(countryCode: countryCode, force: force)
        }
        let tip = tipsEngine.dailyTip(for: countryCode)
        dailyTipDisplay = tip
        tipsEngine.saveTipToHistory(tip: tip)

        let unseen = tipsEngine.isTipUnseen(for: countryCode)
        tipNeedsAttention = unseen
        if unseen && isNewDay {
            didPulseTipThisSession = false
        }
        if unseen && !didPulseTipThisSession {
            tipPulseToken += 1
            didPulseTipThisSession = true
        }

        await rescheduleDailyTipNotification(countryCode: countryCode, settings: SettingsStore.shared)
    }

    public func rescheduleDailyTipNotification(countryCode: String, settings: SettingsStore) async {
        await DailyTipNotificationScheduler.reschedule(
            settings: settings,
            countryCode: countryCode,
            tipsEngine: tipsEngine
        )
    }

    public func markDailyTipSeen() {
        guard !dailyTipDisplay.isEmpty else { return }
        tipsEngine.markTipSeen(dailyTipDisplay.id)
        tipNeedsAttention = false
    }

    // MARK: - Notifications inbox

    public func refreshNotificationInbox(
        settings: SettingsStore,
        appSettings: AppSettingsManager,
        debts: [Debt] = [],
        studioAlerts: [StudioAlertDisplay] = [],
        studioInvoices: [StudioInvoice] = [],
        taxDeadlineDays: Int? = nil,
        countryCode: String? = nil
    ) async {
        let records = (try? fetchAllExpenseRecords()) ?? []
        notificationInboxDisplay = inboxEngine.rebuildInbox(
            settings: settings,
            dashSnapshot: dashboardSnapshot,
            expenseRecords: records,
            debts: debts,
            studioAlerts: studioAlerts,
            studioInvoices: studioInvoices,
            taxDeadlineDays: taxDeadlineDays,
            tipsHistory: tipsEngine.loadTipHistory(),
            currencyFormatter: { appSettings.format($0) },
            locale: appSettings.interfaceLocale
        )
        await inboxEngine.syncLocalNotifications(settings: settings, inbox: notificationInboxDisplay)
        if let countryCode {
            await rescheduleDailyTipNotification(countryCode: countryCode, settings: settings)
        }
    }

    public func markNotificationRead(_ id: String) {
        inboxEngine.markRead(id)
        var items = notificationInboxDisplay.items
        items = items.map { item in
            guard item.id == id else { return item }
            var copy = item
            copy.isRead = true
            return copy
        }
        notificationInboxDisplay = NotificationInboxDisplay(
            items: items,
            unreadCount: items.filter { !$0.isRead }.count
        )
    }

    public func markAllNotificationsRead() {
        let ids = notificationInboxDisplay.items.map(\.id)
        inboxEngine.markAllRead(ids)
        let items = notificationInboxDisplay.items.map { item -> AppNotificationItem in
            var copy = item
            copy.isRead = true
            return copy
        }
        notificationInboxDisplay = NotificationInboxDisplay(items: items, unreadCount: 0)
    }

    public func dismissNotification(_ id: String) {
        inboxEngine.dismiss(id)
        let items = notificationInboxDisplay.items.filter { $0.id != id }
        notificationInboxDisplay = NotificationInboxDisplay(
            items: items,
            unreadCount: items.filter { !$0.isRead }.count
        )
    }

    public func dismissAllNotifications() {
        let ids = notificationInboxDisplay.items.map(\.id)
        inboxEngine.dismissAll(ids)
        notificationInboxDisplay = NotificationInboxDisplay(items: [], unreadCount: 0)
    }

    public func refreshEngagement(
        countryCode: String,
        settings: SettingsStore,
        appSettings: AppSettingsManager,
        debts: [Debt] = [],
        studioAlerts: [StudioAlertDisplay] = [],
        studioInvoices: [StudioInvoice] = [],
        taxDeadlineDays: Int? = nil
    ) async {
        await refreshNotificationInbox(
            settings: settings,
            appSettings: appSettings,
            debts: debts,
            studioAlerts: studioAlerts,
            studioInvoices: studioInvoices,
            taxDeadlineDays: taxDeadlineDays,
            countryCode: countryCode
        )
    }
}
