//
//  BuxMuseProductID.swift
//  BuxMuse — App Store product identifiers (Standard / Pro two-tier).
//

import Foundation

enum BuxMuseProductID: String, CaseIterable, Sendable {
    /// BuxMuse Standard — monthly (core app + Simple Studio).
    case standardMonthly = "com.buxmuse.app.standard.monthly.v3"
    /// BuxMuse Standard — yearly.
    case standardYearly = "com.buxmuse.app.standard.yearly.v3"
    /// BuxMuse Pro — monthly (includes Standard + Pro Studio).
    case proMonthly = "com.buxmuse.app.pro.monthly.v3"
    /// BuxMuse Pro — yearly.
    case proYearly = "com.buxmuse.app.pro.yearly.v3"

    /// Maps App Store / StoreKit product IDs (including deleted legacy IDs) to entitlements.
    static func fromStoreProductID(_ rawValue: String) -> BuxMuseProductID? {
        if let match = BuxMuseProductID(rawValue: rawValue) { return match }
        switch rawValue {
        // Standard (formerly base / premium)
        case "com.buxmuse.app.premium.monthly",
             "com.buxmuse.app.premium.monthly.v2":
            return .standardMonthly
        case "com.buxmuse.app.premium.yearly",
             "com.buxmuse.app.premium.yearly.v2":
            return .standardYearly
        // Legacy Simple one-time → Standard access (grandfather)
        case "com.buxmuse.app.studio.simple",
             "com.buxmuse.app.studio.simple.v2":
            return .standardMonthly
        // Pro (formerly studio.pro)
        case "com.buxmuse.app.studio.pro.monthly",
             "com.buxmuse.app.studio.pro.monthly.v2":
            return .proMonthly
        case "com.buxmuse.app.studio.pro.yearly",
             "com.buxmuse.app.studio.pro.yearly.v2":
            return .proYearly
        default:
            return nil
        }
    }

    static let standardProducts: [BuxMuseProductID] = [.standardMonthly, .standardYearly]
    static let proProducts: [BuxMuseProductID] = [.proMonthly, .proYearly]

    /// Legacy alias — Standard products.
    static var baseAppProducts: [BuxMuseProductID] { standardProducts }
    /// Legacy alias — Pro products.
    static var studioProProducts: [BuxMuseProductID] { proProducts }

    var isSubscription: Bool { true }

    var isStandard: Bool {
        Self.standardProducts.contains(self)
    }

    var isPro: Bool {
        Self.proProducts.contains(self)
    }

    /// Legacy alias for Standard.
    var isBaseApp: Bool { isStandard }

    /// Legacy alias for Pro.
    var isStudioPro: Bool { isPro }
}

typealias StudioProductID = BuxMuseProductID

extension StudioProductID {
    /// Prefer Pro yearly when a single “pro” SKU is needed for defaults.
    static var pro: StudioProductID { .proYearly }
}

extension BuxMuseBillingPeriod {
    var productID: BuxMuseProductID { standardProductID }
}
