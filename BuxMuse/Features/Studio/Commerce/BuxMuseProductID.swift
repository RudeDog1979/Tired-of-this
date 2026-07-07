//
//  BuxMuseProductID.swift
//  BuxMuse — App Store product identifiers.
//

import Foundation

enum BuxMuseProductID: String, CaseIterable, Sendable {
    /// Base BuxMuse app — monthly (v2, App Store Connect recreation).
    case baseMonthly = "com.buxmuse.app.premium.monthly.v2"
    /// Base BuxMuse app — yearly (v2).
    case baseYearly = "com.buxmuse.app.premium.yearly.v2"
    case studioSimple = "com.buxmuse.app.studio.simple.v2"
    case studioProMonthly = "com.buxmuse.app.studio.pro.monthly.v2"
    case studioProYearly = "com.buxmuse.app.studio.pro.yearly.v2"

    /// Maps App Store / StoreKit product IDs (including deleted legacy IDs) to entitlements.
    static func fromStoreProductID(_ rawValue: String) -> BuxMuseProductID? {
        if let match = BuxMuseProductID(rawValue: rawValue) { return match }
        switch rawValue {
        case "com.buxmuse.app.premium.monthly": return .baseMonthly
        case "com.buxmuse.app.premium.yearly": return .baseYearly
        case "com.buxmuse.app.studio.simple": return .studioSimple
        case "com.buxmuse.app.studio.pro.monthly": return .studioProMonthly
        case "com.buxmuse.app.studio.pro.yearly": return .studioProYearly
        default: return nil
        }
    }

    static let baseAppProducts: [BuxMuseProductID] = [.baseMonthly, .baseYearly]
    static let studioProProducts: [BuxMuseProductID] = [.studioProMonthly, .studioProYearly]

    var isSubscription: Bool {
        switch self {
        case .studioSimple: return false
        default: return true
        }
    }

    var isBaseApp: Bool {
        Self.baseAppProducts.contains(self)
    }

    var isStudioPro: Bool {
        Self.studioProProducts.contains(self)
    }
}

typealias StudioProductID = BuxMuseProductID

extension StudioProductID {
    static var simple: StudioProductID { .studioSimple }
    static var pro: StudioProductID { .studioProYearly }
}

extension BuxMuseBillingPeriod {
    var productID: BuxMuseProductID { baseProductID }
}
