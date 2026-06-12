//
//  BuxThemeInkTransition.swift
//  BuxMuse
//
//  Accent wash layer for landing backgrounds (used during theme crossfade).
//

import SwiftUI

struct BuxThemeAccentWash: View {
    let theme: AppTheme
    let colorScheme: ColorScheme

    private var isDark: Bool { colorScheme == .dark }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    theme.accentColor.opacity(isDark ? 0.14 : 0.10),
                    theme.glowColor.opacity(isDark ? 0.08 : 0.05),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    theme.accentColor.opacity(isDark ? 0.22 : 0.14),
                    Color.clear
                ],
                center: UnitPoint(x: 0.08, y: 0.06),
                startRadius: 8,
                endRadius: 420
            )
        }
        .allowsHitTesting(false)
    }
}
