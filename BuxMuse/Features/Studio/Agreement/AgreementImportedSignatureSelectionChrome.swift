//
//  AgreementImportedSignatureSelectionChrome.swift
//  BuxMuse — Expanded-handle selection chrome for imported agreement signatures.
//

import SwiftUI

struct AgreementImportedSignatureSelectionChrome: View {
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

    private let horizontalPad: CGFloat = 18
    private let verticalPad: CGFloat = 16
    private let rotateStem: CGFloat = 30
    private let handleDiameter: CGFloat = 24
    private let handleHitDiameter: CGFloat = 44

    private var layoutSize: CGSize {
        CGSize(
            width: frame.width + horizontalPad * 2,
            height: frame.height + verticalPad * 2 + rotateStem
        )
    }

    private var boxOrigin: CGPoint {
        CGPoint(x: horizontalPad, y: verticalPad + rotateStem)
    }

    private var boxCenter: CGPoint {
        CGPoint(x: boxOrigin.x + frame.width / 2, y: boxOrigin.y + frame.height / 2)
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(accent, lineWidth: 2)
                .frame(width: frame.width, height: frame.height)
                .position(x: boxCenter.x, y: boxCenter.y)
                .allowsHitTesting(false)

            Color.clear
                .frame(
                    width: max(28, frame.width - handleDiameter),
                    height: max(28, frame.height - handleDiameter)
                )
                .contentShape(Rectangle())
                .position(x: boxCenter.x, y: boxCenter.y)
                .gesture(moveGesture)

            cornerHandle(at: CGPoint(x: boxOrigin.x, y: boxOrigin.y), deltaSign: (-1, -1))
            cornerHandle(at: CGPoint(x: boxOrigin.x + frame.width, y: boxOrigin.y), deltaSign: (1, -1))
            cornerHandle(at: CGPoint(x: boxOrigin.x, y: boxOrigin.y + frame.height), deltaSign: (-1, 1))
            cornerHandle(at: CGPoint(x: boxOrigin.x + frame.width, y: boxOrigin.y + frame.height), deltaSign: (1, 1))

            rotateHandle(at: CGPoint(x: boxCenter.x, y: boxOrigin.y - rotateStem * 0.55))
        }
        .frame(width: layoutSize.width, height: layoutSize.height)
        .rotationEffect(
            .degrees(rotation),
            anchor: UnitPoint(
                x: boxCenter.x / max(layoutSize.width, 1),
                y: boxCenter.y / max(layoutSize.height, 1)
            )
        )
        .position(
            x: frame.midX + (layoutSize.width / 2 - boxCenter.x),
            y: frame.midY + (layoutSize.height / 2 - boxCenter.y)
        )
    }

    private var moveGesture: some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .named(BuxCanvasLayerTransformMath.canvasCoordinateSpaceName))
            .onChanged { value in
                onMove(value.translation)
            }
            .onEnded { _ in
                onMoveEnd()
            }
    }

    private func cornerHandle(at point: CGPoint, deltaSign: (CGFloat, CGFloat)) -> some View {
        ZStack {
            Circle()
                .fill(accent)
                .frame(width: handleDiameter, height: handleDiameter)
            Circle()
                .fill(Color.clear)
                .frame(width: handleHitDiameter, height: handleHitDiameter)
                .contentShape(Circle())
        }
        .position(point)
        .highPriorityGesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .named(BuxCanvasLayerTransformMath.canvasCoordinateSpaceName))
                .onChanged { value in
                    if originSize == .zero {
                        originSize = frame.size
                    }
                    let local = BuxCanvasLayerTransformMath.localDragDelta(
                        value.translation,
                        rotationDegrees: rotation
                    )
                    let dw = deltaSign.0 * local.width * 2
                    let dh = deltaSign.1 * local.height * 2
                    onResize(
                        CGSize(
                            width: max(28, originSize.width + dw),
                            height: max(16, originSize.height + dh)
                        )
                    )
                }
                .onEnded { _ in
                    originSize = .zero
                    onResizeEnd()
                }
        )
    }

    private func rotateHandle(at point: CGPoint) -> some View {
        ZStack {
            Circle()
                .fill(accent)
                .frame(width: handleDiameter, height: handleDiameter)
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
            Circle()
                .fill(Color.clear)
                .frame(width: handleHitDiameter, height: handleHitDiameter)
                .contentShape(Circle())
        }
        .position(point)
        .highPriorityGesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .named(BuxCanvasLayerTransformMath.canvasCoordinateSpaceName))
                .onChanged { value in
                    if rotateSessionBase == nil {
                        rotateSessionBase = rotation
                        rotateDragStartAngle = BuxCanvasLayerTransformMath.angleDegrees(
                            from: CGPoint(x: frame.midX, y: frame.midY),
                            to: value.startLocation
                        )
                    }
                    guard let base = rotateSessionBase,
                          let startAngle = rotateDragStartAngle else { return }
                    let current = BuxCanvasLayerTransformMath.angleDegrees(
                        from: CGPoint(x: frame.midX, y: frame.midY),
                        to: value.location
                    )
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
