//
//  BuxTokens.swift
//  BuxMuse Design System
//
//  Spacing, radii, elevation — HIG-aligned 8pt grid.
//

import SwiftUI

enum BuxTokens {
    static let unit: CGFloat = 8
    static let marginCompact: CGFloat = 16
    static let marginRegular: CGFloat = 20
    static let compactWidthThreshold: CGFloat = 360
    /// Default card / section inset (8pt grid).
    static let section: CGFloat = 16
    static let block: CGFloat = 24
    static let tight: CGFloat = 8
    /// Detail hub card padding — alias for BuxDetailStyle.cardPadding.
    static let detailCard: CGFloat = 20
    static let minTap: CGFloat = 44
    static let pillHeight: CGFloat = 48
    static let sheetBottomClearance: CGFloat = 120

    enum Radius {
        static let field: CGFloat = 14
        static let card: CGFloat = 16
        static let hero: CGFloat = 24
        static let heroLarge: CGFloat = 32
    }

    /// Apple Music–style soft shadow — hero / floating only. GPU-friendly single layer.
    enum Shadow {
        static let heroColorOpacityLight: Double = 0.055
        static let heroColorOpacityDark: Double = 0.28
        static let heroRadius: CGFloat = 14
        static let heroY: CGFloat = 5
        static let ctaRadius: CGFloat = 5
        static let ctaY: CGFloat = 2
    }

    static func horizontalMargin(for width: CGFloat) -> CGFloat {
        width < compactWidthThreshold ? marginCompact : marginRegular
    }

    /// System red for destructive actions — never the brand accent.
    static let destructive = Color.red
}

/// Swipe action tints — delete is always `BuxTokens.destructive`, never accent.
enum BuxSwipeActionTint {
    static var delete: Color { BuxTokens.destructive }
    static let category = Color.orange
    static let duplicate = Color(red: 90/255, green: 85/255, blue: 245/255)
    static let note = Color.teal

    static func edit(accent: Color) -> Color { accent }
}

enum BuxElevation {
    /// List rows — no shadow, optional separator only.
    case flat
    /// Section cards — hairline on light, hairline on dark; never shadow (no clipping).
    case card
    /// Hero panels — soft shadow in light; hairline + shadow in dark.
    case hero
}

struct BuxCardChromeMetrics {
    var stroke: Color = .clear
    var strokeWidth: CGFloat = 0
    var shadowColor: Color = .clear
    var shadowRadius: CGFloat = 0
    var shadowY: CGFloat = 0
}
