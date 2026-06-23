//
//  BuxMuseProductID.swift
//  BuxMuse — App Store product identifiers.
//

import Foundation

enum BuxMuseProductID: String, CaseIterable, Sendable {
    /// Base BuxMuse app — monthly. Store ID retains legacy `premium` segment.
    case baseMonthly = "com.buxmuse.app.premium.monthly"
    /// Base BuxMuse app — yearly.
    case baseYearly = "com.buxmuse.app.premium.yearly"
    case studioSimple = "com.buxmuse.app.studio.simple"
    case studioProMonthly = "com.buxmuse.app.studio.pro.monthly"
    case studioProYearly = "com.buxmuse.app.studio.pro.yearly"

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
