//
//  MoneyMapTopoWavesView.swift
//  BuxMuse
//
//  Static topo backdrop — rasterized once per layout/theme, parallax via .offset only.
//

import SwiftUI

struct MoneyMapTopoWavesView: View, Equatable {
    let accent: Color
    let isDark: Bool

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.isDark == rhs.isDark && lhs.accent == rhs.accent
    }

    var body: some View {
        Canvas { context, size in
            let lineBoost = isDark ? 1.0 : 1.45
            for i in 0..<7 {
                var path = Path()
                let yBase = size.height * (0.15 + CGFloat(i) * 0.12)
                path.move(to: CGPoint(x: 0, y: yBase))
                for x in stride(from: 0, through: size.width, by: 8) {
                    let wave = sin((x / size.width) * .pi * 2 + Double(i) * 0.7) * 10
                    path.addLine(to: CGPoint(x: x, y: yBase + wave))
                }
                context.stroke(
                    path,
                    with: .color(accent.opacity((0.04 + Double(i) * 0.012) * lineBoost)),
                    lineWidth: 1
                )
            }
        }
        .drawingGroup(opaque: false, colorMode: .linear)
        .allowsHitTesting(false)
    }
}
