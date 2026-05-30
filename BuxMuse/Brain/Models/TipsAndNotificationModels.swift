//
//  TipsAndNotificationModels.swift
//  BuxMuse
//

import Foundation

// MARK: - Remote news JSON

struct BuxMuseNewsPayload: Codable {
    var regions: [String: BuxNewsRegion]
    var updatedAt: String?
    var version: Int?
}

struct BuxNewsRegion: Codable {
    var home_tip: String
    var scam: BuxNewsAlertItem
    var alert: BuxNewsAlertItem
    var ticker: [String]
}

struct BuxNewsAlertItem: Codable {
    var title: String
    var desc: String
}

// MARK: - UI snapshots (brain → views)

public enum DailyTipKind: String, Equatable {
    case moneyTip = "Money Tip"
    case scam = "Scam Alert"
    case security = "Security Alert"

    public var badgeLabel: String {
        switch self {
        case .moneyTip: return "Save Money"
        case .scam: return "Watch Out"
        case .security: return "Stay Safe"
        }
    }

    public var systemImage: String {
        switch self {
        case .moneyTip: return "lightbulb.fill"
        case .scam: return "exclamationmark.triangle.fill"
        case .security: return "lock.shield.fill"
        }
    }
}

public struct DailyTipSection: Equatable, Identifiable {
    public var kind: DailyTipKind
    public var title: String
    public var body: String

    public var id: String { kind.rawValue }
}

public struct DailyTipDisplay: Equatable {
    public var id: String
    /// User's selected country (for flag display).
    public var regionCode: String
    public var regionFlag: String
    public var dateLabel: String
    /// JSON content locale actually loaded (e.g. DO user → `ES` content).
    public var contentRegion: String
    public var watchOutHeader: String
    public var moneyTip: DailyTipSection
    public var watchOut: [DailyTipSection]

    public static let empty = DailyTipDisplay(
        id: "",
        regionCode: "DEFAULT",
        regionFlag: "🌍",
        dateLabel: "",
        contentRegion: "DEFAULT",
        watchOutHeader: "ALSO WATCH OUT",
        moneyTip: DailyTipSection(kind: .moneyTip, title: "", body: ""),
        watchOut: []
    )

    public var isEmpty: Bool { id.isEmpty }
}

public enum AppNotificationCategory: String, Equatable {
    case subscription
    case budget
    case bill
    case invoice
    case tax
    case studio
    case digest
}

public struct AppNotificationItem: Identifiable, Equatable {
    public var id: String
    public var title: String
    public var message: String
    public var date: Date
    public var category: AppNotificationCategory
    public var isRead: Bool
    public var severity: String
}

public struct NotificationInboxDisplay: Equatable {
    public var items: [AppNotificationItem]
    public var unreadCount: Int

    public static let empty = NotificationInboxDisplay(items: [], unreadCount: 0)
}

public struct HistoricalTipRecord: Codable, Equatable {
    public let id: String
    public let date: Date
    public let title: String
    public let message: String

    public init(id: String, date: Date, title: String, message: String) {
        self.id = id
        self.date = date
        self.title = title
        self.message = message
    }
}
