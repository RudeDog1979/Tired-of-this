//
//  BuxAdaptiveUI.swift
//  BuxMuse
//
//  Platform gates + visual policy — all #available checks for UI live here.
//

import SwiftUI

// MARK: - Platform

enum BuxPlatform {
    static var supportsLiquidGlass: Bool {
        if #available(iOS 26, *) { return true }
        return false
    }

    static var supportsConfirmRole: Bool {
        if #available(iOS 26, *) { return true }
        return false
    }

    static var supportsCloseRole: Bool {
        if #available(iOS 26, *) { return true }
        return false
    }

    static var supportsSharedBackgroundVisibility: Bool {
        if #available(iOS 26, *) { return true }
        return false
    }
}

// MARK: - Card chrome tier

enum BuxCardChromeTier {
    /// One hero per screen — soft shadow, optional glass plate when useGlassmorphism.
    case hero
    /// List / grid rows — hairline stroke, no shadow, never glass.
    case list
}

extension BuxElevation {
    var chromeTier: BuxCardChromeTier {
        switch self {
        case .hero: return .hero
        case .card, .flat: return .list
        }
    }
}
