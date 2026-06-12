//
//  BuxCanvasSelectionChrome.swift
//  BuxMuse — selection box + handles (same transform stack as CardCanvasRenderer)
//

import SwiftUI

struct BuxCanvasSelectionChrome: View {
    let frame: CGRect
    let accent: Color
    var rotation: Double
    var onMove: (CGSize) -> Void
    var onMoveEnd: () -> Void
    var onResize: (CGSize) -> Void
    var onResizeEnd: () -> Void
    var onRotate: (Double) -> Void
    var onRotateEnd: () -> Void

    @State private var originSize: CGSize = .zero
    @State private var rotateSessionBase: Double?
    @State private var rotateDragStartAngle: Double?

    private var pivotInCanvas: CGPoint {
        CGPoint(x: frame.midX, y: frame.midY)
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(accent, lineWidth: 2)
                .frame(width: frame.width, height: frame.height)
                .allowsHitTesting(false)

            Color.clear
                .frame(width: max(24, frame.width - 28), height: max(24, frame.height - 28))
                .contentShape(Rectangle())
                .gesture(moveGesture)

            resizeHandle(corner: CGPoint(x: 0, y: 0), deltaSign: (-1, -1))
            resizeHandle(corner: CGPoint(x: frame.width, y: 0), deltaSign: (1, -1))
            resizeHandle(corner: CGPoint(x: 0, y: frame.height), deltaSign: (-1, 1))
            resizeHandle(corner: CGPoint(x: frame.width, y: frame.height), deltaSign: (1, 1))

            rotateHandle(at: CGPoint(x: frame.width * 0.5, y: -24))
        }
        .frame(width: frame.width, height: frame.height)
        .rotationEffect(.degrees(rotation))
        .position(x: frame.midX, y: frame.midY)
    }

    private var moveGesture: some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .named(BuxCanvasLayerTransformMath.canvasCoordinateSpaceName))
            .onChanged { value in
                onMove(value.translation)
            }
            .onEnded { _ in onMoveEnd() }
    }

    private func resizeHandle(corner: CGPoint, deltaSign: (CGFloat, CGFloat)) -> some View {
        Circle()
            .fill(accent)
            .frame(width: 18, height: 18)
            .position(corner)
            .highPriorityGesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named(BuxCanvasLayerTransformMath.canvasCoordinateSpaceName))
                    .onChanged { value in
                        if originSize == .zero { originSize = frame.size }
                        let local = BuxCanvasLayerTransformMath.localDragDelta(value.translation, rotationDegrees: rotation)
                        let dw = deltaSign.0 * local.width * 2
                        let dh = deltaSign.1 * local.height * 2
                        onResize(CGSize(width: max(20, originSize.width + dw), height: max(20, originSize.height + dh)))
                    }
                    .onEnded { _ in
                        originSize = .zero
                        onResizeEnd()
                    }
            )
    }

    private func rotateHandle(at localPoint: CGPoint) -> some View {
        ZStack {
            Circle().fill(accent).frame(width: 20, height: 20)
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
        }
        .position(localPoint)
        .highPriorityGesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .named(BuxCanvasLayerTransformMath.canvasCoordinateSpaceName))
                .onChanged { value in
                    if rotateSessionBase == nil {
                        rotateSessionBase = rotation
                        rotateDragStartAngle = BuxCanvasLayerTransformMath.angleDegrees(
                            from: pivotInCanvas,
                            to: value.startLocation
                        )
                    }
                    guard let base = rotateSessionBase,
                          let startAngle = rotateDragStartAngle else { return }
                    let current = BuxCanvasLayerTransformMath.angleDegrees(from: pivotInCanvas, to: value.location)
                    onRotate(BuxCanvasLayerTransformMath.snapRotation(base + current - startAngle))
                }
                .onEnded { _ in
                    rotateSessionBase = nil
                    rotateDragStartAngle = nil
                    onRotateEnd()
                }
        )
    }
}
