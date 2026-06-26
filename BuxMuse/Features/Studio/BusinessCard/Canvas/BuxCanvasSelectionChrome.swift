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
    var onPinch: (CGFloat) -> Void
    var onPinchEnd: () -> Void
    var onPinchRotate: (Angle) -> Void
    var onPinchRotateEnd: () -> Void

    @State private var originSize: CGSize = .zero
    @State private var rotateSessionBase: Double?
    @State private var rotateDragStartAngle: Double?
    /// Frozen at gesture start so SwiftUI does not cancel recognizers when the live frame updates.
    @State private var frozenGestureFrame: CGRect?
    @State private var frozenRotation: Double?
    @State private var activeGestureKinds: Set<String> = []

    private var pivotInCanvas: CGPoint {
        CGPoint(x: frame.midX, y: frame.midY)
    }

    private var gestureHostFrame: CGRect {
        frozenGestureFrame ?? frame
    }

    private var gestureHostRotation: Double {
        frozenRotation ?? rotation
    }

    var body: some View {
        ZStack {
            chromeVisual
            chromeGestureHost
        }
    }

    // MARK: - Visual (tracks live frame)

    private var chromeVisual: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(accent, lineWidth: 2)
                .frame(width: frame.width, height: frame.height)

            resizeHandleVisual(corner: CGPoint(x: 0, y: 0))
            resizeHandleVisual(corner: CGPoint(x: frame.width, y: 0))
            resizeHandleVisual(corner: CGPoint(x: 0, y: frame.height))
            resizeHandleVisual(corner: CGPoint(x: frame.width, y: frame.height))

            rotateHandleVisual(at: CGPoint(x: frame.width * 0.5, y: -24))
        }
        .frame(width: frame.width, height: frame.height)
        .rotationEffect(.degrees(rotation))
        .position(x: frame.midX, y: frame.midY)
        .allowsHitTesting(false)
    }

    private func resizeHandleVisual(corner: CGPoint) -> some View {
        Circle()
            .fill(accent)
            .frame(width: 18, height: 18)
            .position(corner)
    }

    private func rotateHandleVisual(at localPoint: CGPoint) -> some View {
        ZStack {
            Circle().fill(accent).frame(width: 20, height: 20)
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
        }
        .position(localPoint)
    }

    // MARK: - Gesture host (stable frame while a gesture is active)

    private var chromeGestureHost: some View {
        let hostFrame = gestureHostFrame
        let hostRotation = gestureHostRotation

        return ZStack {
            Color.clear
                .frame(width: hostFrame.width, height: hostFrame.height)
                .contentShape(Rectangle())
                .gesture(moveGesture)
                .simultaneousGesture(pinchRotateGesture)

            resizeHandleGesture(corner: CGPoint(x: 0, y: 0), deltaSign: (-1, -1), hostFrame: hostFrame, hostRotation: hostRotation)
            resizeHandleGesture(corner: CGPoint(x: hostFrame.width, y: 0), deltaSign: (1, -1), hostFrame: hostFrame, hostRotation: hostRotation)
            resizeHandleGesture(corner: CGPoint(x: 0, y: hostFrame.height), deltaSign: (-1, 1), hostFrame: hostFrame, hostRotation: hostRotation)
            resizeHandleGesture(corner: CGPoint(x: hostFrame.width, y: hostFrame.height), deltaSign: (1, 1), hostFrame: hostFrame, hostRotation: hostRotation)

            rotateHandleGesture(at: CGPoint(x: hostFrame.width * 0.5, y: -24), hostFrame: hostFrame)
        }
        .frame(width: hostFrame.width, height: hostFrame.height)
        .rotationEffect(.degrees(hostRotation))
        .position(x: hostFrame.midX, y: hostFrame.midY)
    }

    private func beginGestureSession(kind: String) {
        if frozenGestureFrame == nil {
            frozenGestureFrame = frame
            frozenRotation = rotation
        }
        activeGestureKinds.insert(kind)
    }

    private func endGestureSession(kind: String) {
        activeGestureKinds.remove(kind)
        guard activeGestureKinds.isEmpty else { return }
        frozenGestureFrame = nil
        frozenRotation = nil
        originSize = .zero
        rotateSessionBase = nil
        rotateDragStartAngle = nil
    }

    private var moveGesture: some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .named(BuxCanvasLayerTransformMath.canvasCoordinateSpaceName))
            .onChanged { value in
                beginGestureSession(kind: "move")
                onMove(value.translation)
            }
            .onEnded { _ in
                onMoveEnd()
                endGestureSession(kind: "move")
            }
    }

    private var pinchRotateGesture: some Gesture {
        SimultaneousGesture(
            MagnificationGesture()
                .onChanged { magnification in
                    beginGestureSession(kind: "pinch")
                    onPinch(magnification)
                }
                .onEnded { _ in
                    onPinchEnd()
                    endGestureSession(kind: "pinch")
                },
            RotateGesture()
                .onChanged { value in
                    beginGestureSession(kind: "pinchRotate")
                    onPinchRotate(value.rotation)
                }
                .onEnded { _ in
                    onPinchRotateEnd()
                    endGestureSession(kind: "pinchRotate")
                }
        )
    }

    private func resizeHandleGesture(
        corner: CGPoint,
        deltaSign: (CGFloat, CGFloat),
        hostFrame: CGRect,
        hostRotation: Double
    ) -> some View {
        Circle()
            .fill(accent.opacity(0.001))
            .frame(width: 28, height: 28)
            .position(corner)
            .highPriorityGesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named(BuxCanvasLayerTransformMath.canvasCoordinateSpaceName))
                    .onChanged { value in
                        beginGestureSession(kind: "resize")
                        if originSize == .zero { originSize = frame.size }
                        let local = BuxCanvasLayerTransformMath.localDragDelta(value.translation, rotationDegrees: hostRotation)
                        let dw = deltaSign.0 * local.width * 2
                        let dh = deltaSign.1 * local.height * 2
                        onResize(CGSize(width: max(20, originSize.width + dw), height: max(20, originSize.height + dh)))
                    }
                    .onEnded { _ in
                        onResizeEnd()
                        endGestureSession(kind: "resize")
                    }
            )
    }

    private func rotateHandleGesture(at localPoint: CGPoint, hostFrame: CGRect) -> some View {
        Circle()
            .fill(accent.opacity(0.001))
            .frame(width: 32, height: 32)
            .position(localPoint)
            .highPriorityGesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named(BuxCanvasLayerTransformMath.canvasCoordinateSpaceName))
                    .onChanged { value in
                        beginGestureSession(kind: "rotateHandle")
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
                        onRotateEnd()
                        endGestureSession(kind: "rotateHandle")
                    }
            )
    }
}
