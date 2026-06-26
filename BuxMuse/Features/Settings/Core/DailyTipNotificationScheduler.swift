//
//  DailyTipNotificationScheduler.swift
//  BuxMuse
//
//  Schedules one local notification per day with the current regional tip + scam alert.
//

import Foundation
import UserNotifications

enum DailyTipNotificationScheduler {
    static let notificationId = "buxmuse.daily.tip"
    private static let fireHour = 9
    private static let fireMinute = 0

    @MainActor
    static func reschedule(settings: SettingsStore, countryCode: String, tipsEngine: BuxTipsEngine) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [notificationId])
        center.removeDeliveredNotifications(withIdentifiers: [notificationId])

        guard settings.notificationsEnabled, settings.dailyTipNotificationsEnabled else { return }
        guard await BuxNotificationPolicy.requestAuthorizationIfNeeded() else { return }

        let policy = BuxNotificationSettingsSnapshot(settings: settings)
        guard var fireDate = nextFireDate(from: Date()) else { return }
        if let adjusted = BuxNotificationPolicy.adjustedFireDate(fireDate, settings: policy) {
            fireDate = adjusted
        }
        guard fireDate > Date() else { return }

        let tip = tipsEngine.dailyTip(for: countryCode)
        guard !tip.isEmpty else { return }

        let locale = BuxInterfaceLocale.currentInterfaceLocale
        let content = UNMutableNotificationContent()
        content.title = BuxCatalogLabel.string("Daily tip & scam alert", locale: locale)
        content.body = notificationBody(for: tip)
        content.sound = .default
        content.userInfo = BuxNotificationPayload.userInfo(route: .dailyTip)

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: fireDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: notificationId,
            content: content,
            trigger: trigger
        )
        try? await center.add(request)
    }

    private static func notificationBody(for tip: DailyTipDisplay) -> String {
        var parts: [String] = []
        let money = tip.moneyTip.body.trimmingCharacters(in: .whitespacesAndNewlines)
        if !money.isEmpty { parts.append(money) }
        if let scam = tip.watchOut.first(where: { $0.kind == .scam }) {
            let scamLine = scam.title.trimmingCharacters(in: .whitespacesAndNewlines)
            if !scamLine.isEmpty {
                parts.append("⚠️ \(scamLine)")
            }
        }
        return parts.joined(separator: " ")
    }

    private static func nextFireDate(from now: Date) -> Date? {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = fireHour
        components.minute = fireMinute
        components.second = 0
        guard let today = calendar.date(from: components) else { return nil }
        if now < today { return today }
        return calendar.date(byAdding: .day, value: 1, to: today)
    }
}
