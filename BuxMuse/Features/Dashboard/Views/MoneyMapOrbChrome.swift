//
//  MoneyMapOrbChrome.swift
//  BuxMuse
//
//  GPU-friendly orb fills — gradient glass + glow without live material sampling.
//

import SwiftUI

enum MoneyMapOrbChrome {
    /// Accent-tinted hub — identical live vs still (no material swap).
    static func hubTintFill(accent: Color, isDark: Bool) -> RadialGradient {
        RadialGradient(
            colors: isDark
                ? [accent.opacity(0.40), accent.opacity(0.26), Color(white: 0.15)]
                : [accent.opacity(0.24), accent.opacity(0.14), Color.white.opacity(0.84)],
            center: .topLeading,
            startRadius: 0,
            endRadius: 1.15
        )
    }

    /// Frosted territory fill — matches the still material look without live resampling.
    static func nodeTintFill(isDark: Bool) -> RadialGradient {
        RadialGradient(
            colors: isDark
                ? [Color.white.opacity(0.16), Color.white.opacity(0.09), Color(white: 0.13)]
                : [Color.white.opacity(0.78), Color.white.opacity(0.58), Color.white.opacity(0.42)],
            center: .center,
            startRadius: 0,
            endRadius: 1
        )
    }

    /// Single cheap shadow — Apple-style depth without radial glow passes.
    static func orbShadowColor(isDark: Bool) -> Color {
        .black.opacity(isDark ? 0.32 : 0.11)
    }
}
