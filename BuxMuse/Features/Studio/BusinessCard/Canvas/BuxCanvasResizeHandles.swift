//
//  BuxCanvasResizeHandles.swift
//  BuxMuse
//

import SwiftUI

struct BuxCanvasResizeHandles: View {
    let frame: CGRect
    let accent: Color
    var onResize: (CGSize) -> Void
    var onResizeEnd: () -> Void

    @State private var originSize: CGSize = .zero

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(accent, lineWidth: 2)
                .frame(width: frame.width, height: frame.height)
                .position(x: frame.midX, y: frame.midY)

            handle(at: CGPoint(x: frame.minX, y: frame.minY), deltaSign: (-1, -1))
            handle(at: CGPoint(x: frame.maxX, y: frame.minY), deltaSign: (1, -1))
            handle(at: CGPoint(x: frame.minX, y: frame.maxY), deltaSign: (-1, 1))
            handle(at: CGPoint(x: frame.maxX, y: frame.maxY), deltaSign: (1, 1))
        }
    }

    private func handle(at point: CGPoint, deltaSign: (CGFloat, CGFloat)) -> some View {
        Circle()
            .fill(accent)
            .frame(width: 14, height: 14)
            .position(point)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        if originSize == .zero { originSize = frame.size }
                        let dw = deltaSign.0 * v.translation.width * 2
                        let dh = deltaSign.1 * v.translation.height * 2
                        onResize(CGSize(width: max(24, originSize.width + dw), height: max(24, originSize.height + dh)))
                    }
                    .onEnded { _ in originSize = .zero; onResizeEnd() }
            )
    }
}
