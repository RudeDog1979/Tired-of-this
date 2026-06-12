//
//  BuxNotificationInboxTests.swift
//  BuxMuseTests
//

import XCTest
@testable import BuxMuse

@MainActor
final class BuxNotificationInboxTests: XCTestCase {
    var engine: BuxNotificationInboxEngine!
    var settings: SettingsStore!

    override func setUp() {
        super.setUp()
        settings = SettingsStore.shared
        settings.resetAllData()
        settings.notificationsEnabled = true
        settings.budgetAlertsEnabled = false
        settings.billRemindersEnabled = false
        settings.dailySummaryEnabled = false
        settings.studioEnabled = false
        engine = BuxNotificationInboxEngine()
        UserDefaults.standard.removeObject(forKey: "buxmuse.notifications.readIds")
        UserDefaults.standard.removeObject(forKey: "buxmuse.notifications.dismissedIds")
        UserDefaults.standard.removeObject(forKey: "buxmuse.notifications.pushedIds")
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "buxmuse.notifications.readIds")
        UserDefaults.standard.removeObject(forKey: "buxmuse.notifications.dismissedIds")
        UserDefaults.standard.removeObject(forKey: "buxmuse.notifications.pushedIds")
        engine = nil
        settings = nil
        super.tearDown()
    }

    func testTipHistoryItemsStayReadInInbox() {
        let tips = [
            HistoricalTipRecord(id: "tip-a", date: Date(), title: "Save", message: "Body")
        ]
        let inbox = engine.rebuildInbox(
            settings: settings,
            dashSnapshot: .empty,
            expenseRecords: [],
            studioAlerts: [],
            studioInvoices: [],
            taxDeadlineDays: nil,
            tipsHistory: tips,
            currencyFormatter: { "\($0)" }
        )

        XCTAssertEqual(inbox.unreadCount, 0)
        XCTAssertTrue(inbox.items.first?.isRead == true)
    }

    func testDailySummaryUsesStablePerDayId() {
        settings.dailySummaryEnabled = true
        let inbox = engine.rebuildInbox(
            settings: settings,
            dashSnapshot: .empty,
            expenseRecords: [],
            studioAlerts: [],
            studioInvoices: [],
            taxDeadlineDays: nil,
            tipsHistory: [],
            currencyFormatter: { "\($0)" }
        )

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dayKey = formatter.string(from: Date())
        XCTAssertTrue(inbox.items.contains { $0.id == "daily-summary-\(dayKey)" })
    }

    func testTaxDeadlineDedupesStudioAlert() {
        settings.studioEnabled = true
        settings.taxDeadlineRemindersEnabled = true
        let alert = StudioAlertDisplay(
            id: "tax-deadline",
            title: "Tax deadline approaching",
            message: "14 days left",
            severity: "medium"
        )
        let inbox = engine.rebuildInbox(
            settings: settings,
            dashSnapshot: .empty,
            expenseRecords: [],
            studioAlerts: [alert],
            studioInvoices: [],
            taxDeadlineDays: 14,
            tipsHistory: [],
            currencyFormatter: { "\($0)" }
        )

        let taxItems = inbox.items.filter { $0.id == "tax-deadline" }
        XCTAssertEqual(taxItems.count, 1)
    }
}
