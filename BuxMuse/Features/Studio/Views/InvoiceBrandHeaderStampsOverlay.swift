//
//  InvoiceBrandHeaderStampsOverlay.swift
//  BuxMuse — renders card canvas shape stamps in invoice header bands
//

import SwiftUI

struct InvoiceBrandHeaderStampsOverlay: View {
    let stamps: [BrandShapeStamp]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                ForEach(stamps) { stamp in
                    stampView(stamp, width: w, height: h)
                }
            }
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func stampView(_ stamp: BrandShapeStamp, width w: CGFloat, height h: CGFloat) -> some View {
        let frameW = max(6, CGFloat(stamp.width * stamp.scale) * w)
        let frameH = max(6, CGFloat(stamp.height * stamp.scale) * h)
        let mappedY = min(h, CGFloat(stamp.centerY / headerBandHeight) * h)
        BuxGeometricShapeView(
            type: stamp.shapeType,
            fill: fill(for: stamp),
            stroke: stamp.strokeHex.map { Color(hex: $0) },
            strokeWidth: stamp.strokeWidth,
            cornerRadius: stamp.cornerRadius,
            symbolName: nil
        )
        .frame(width: frameW, height: frameH)
        .rotationEffect(.degrees(stamp.rotation))
        .opacity(stamp.opacity)
        .position(x: CGFloat(stamp.centerX) * w, y: mappedY)
    }

    private var headerBandHeight: Double { BrandVisualPackExtractor.headerBandCardHeight }

    private func fill(for stamp: BrandShapeStamp) -> AnyShapeStyle {
        if stamp.useGradient {
            return AnyShapeStyle(LinearGradient(
                colors: [Color(hex: stamp.fillHex), Color(hex: stamp.fillHex).opacity(0.45)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
        }
        return AnyShapeStyle(Color(hex: stamp.fillHex))
    }
}
