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
    static let section: CGFloat = 16
    static let block: CGFloat = 24
    static let tight: CGFloat = 8
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
        static let heroColorOpacityLight: Double = 0.10
        static let heroColorOpacityDark: Double = 0.28
        static let heroRadius: CGFloat = 20
        static let heroY: CGFloat = 8
        static let ctaRadius: CGFloat = 5
        static let ctaY: CGFloat = 2
    }

    static func horizontalMargin(for width: CGFloat) -> CGFloat {
        width < compactWidthThreshold ? marginCompact : marginRegular
    }
}

enum BuxElevation {
    /// List rows — no shadow, optional separator only.
    case flat
    /// Section cards — hairline pop in light mode, no shadow.
    case card
    /// Hero panels — soft diffuse shadow (Apple Music large cards).
    case hero
}
