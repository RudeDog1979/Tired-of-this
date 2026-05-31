//
//  BuxCanvasSelectionChrome.swift
//  BuxMuse — resize + rotate handles that don't block canvas taps
//

import SwiftUI

struct BuxCanvasSelectionChrome: View {
    let frame: CGRect
    let accent: Color
    var rotation: Double
    var onResize: (CGSize) -> Void
    var onResizeEnd: () -> Void
    var onRotate: (Double) -> Void
    var onRotateEnd: () -> Void

    @State private var originSize: CGSize = .zero
    @State private var rotateOrigin: Double = 0

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(accent, lineWidth: 2)
                .frame(width: frame.width, height: frame.height)
                .position(x: frame.midX, y: frame.midY)
                .allowsHitTesting(false)

            resizeHandle(at: CGPoint(x: frame.minX, y: frame.minY), deltaSign: (-1, -1))
            resizeHandle(at: CGPoint(x: frame.maxX, y: frame.minY), deltaSign: (1, -1))
            resizeHandle(at: CGPoint(x: frame.minX, y: frame.maxY), deltaSign: (-1, 1))
            resizeHandle(at: CGPoint(x: frame.maxX, y: frame.maxY), deltaSign: (1, 1))

            rotateHandle(at: CGPoint(x: frame.midX, y: frame.minY - 22))
        }
    }

    private func resizeHandle(at point: CGPoint, deltaSign: (CGFloat, CGFloat)) -> some View {
        Circle()
            .fill(accent)
            .frame(width: 16, height: 16)
            .position(point)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        if originSize == .zero { originSize = frame.size }
                        let dw = deltaSign.0 * v.translation.width * 2
                        let dh = deltaSign.1 * v.translation.height * 2
                        onResize(CGSize(width: max(20, originSize.width + dw), height: max(20, originSize.height + dh)))
                    }
                    .onEnded { _ in originSize = .zero; onResizeEnd() }
            )
    }

    private func rotateHandle(at point: CGPoint) -> some View {
        ZStack {
            Circle().fill(accent).frame(width: 18, height: 18)
            Image(systemName: "arrow.triangle.2.circlepath").font(.system(size: 9, weight: .bold)).foregroundStyle(.white)
        }
        .position(point)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { v in
                    if rotateOrigin == 0 { rotateOrigin = rotation }
                    let angle = atan2(v.translation.width, -v.translation.height) * 180 / .pi
                    onRotate(rotateOrigin + angle)
                }
                .onEnded { _ in rotateOrigin = 0; onRotateEnd() }
        )
    }
}
