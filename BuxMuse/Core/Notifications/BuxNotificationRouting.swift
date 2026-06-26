//
//  BuxNotificationRouting.swift
//  BuxMuse — userInfo keys and routes for local notification taps.
//

import Foundation

enum BuxNotificationRoute: String, Sendable {
    case inboxItem = "inbox_item"
    case expense = "expense"
    case debt = "debt"
    case studioLogTime = "studio_log_time"
    case backup = "backup"
    case subscription = "subscription"
    case dailyTip = "daily_tip"
}

/// Keys written into `UNNotificationContent.userInfo`. Keep in sync with delegate extraction literals.
enum BuxNotificationUserInfoKey: String {
    case route = "bux_route"
    case itemId = "bux_item_id"
    case entityId = "bux_entity_id"
    case category = "bux_category"
}

struct BuxNotificationTapPayload: Sendable {
    var routeRaw: String?
    var itemId: String?
    var entityId: String?
    var categoryRaw: String?
}

enum BuxNotificationPayload {
    static func userInfo(
        route: BuxNotificationRoute,
        itemId: String? = nil,
        entityId: String? = nil,
        category: AppNotificationCategory? = nil
    ) -> [String: String] {
        var info: [String: String] = [BuxNotificationUserInfoKey.route.rawValue: route.rawValue]
        if let itemId { info[BuxNotificationUserInfoKey.itemId.rawValue] = itemId }
        if let entityId { info[BuxNotificationUserInfoKey.entityId.rawValue] = entityId }
        if let category { info[BuxNotificationUserInfoKey.category.rawValue] = category.rawValue }
        return info
    }

    static func route(from payload: BuxNotificationTapPayload) -> BuxNotificationRoute? {
        payload.routeRaw.flatMap(BuxNotificationRoute.init(rawValue:))
    }

    static func inboxItem(from payload: BuxNotificationTapPayload) -> (itemId: String, category: AppNotificationCategory?)? {
        guard let itemId = payload.itemId else { return nil }
        let category = payload.categoryRaw.flatMap(AppNotificationCategory.init(rawValue:))
        return (itemId, category)
    }
}
