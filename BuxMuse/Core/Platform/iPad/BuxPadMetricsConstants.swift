//
//  BuxPadMetricsConstants.swift
//  BuxMuse — iPad performance tuning (M-series 120Hz target).
//

import Foundation

enum BuxPadMetricsConstants {
    /// Brain snapshot / presentation re-resolve debounce (spec: < 16ms refresh).
    static let brainResizeDebounceNs: UInt64 = 16_000_000

    /// Reference phone width used by frozen Dashboard hero layout.
    static let dashboardHeroReferenceWidth: CGFloat = 430
}
