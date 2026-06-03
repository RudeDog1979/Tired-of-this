//
//  BuxCanvasLayerTransformMath.swift
//  BuxMuse — shared snap + angle helpers for canvas manipulation
//

import CoreGraphics
import Foundation

enum BuxCanvasLayerTransformMath {

    static let canvasCoordinateSpaceName = "buxCardCanvas"

    static func snapRotation(_ degrees: Double, step: Double = 15, threshold: Double = 4) -> Double {
        let snapped = (degrees / step).rounded() * step
        return abs(degrees - snapped) <= threshold ? snapped : degrees
    }

    static func angleDegrees(from center: CGPoint, to point: CGPoint) -> Double {
        atan2(point.x - center.x, center.y - point.y) * 180 / .pi
    }

    static func clampNormalized(_ value: Double) -> Double {
        min(1, max(0, value))
    }

    static func clampScale(_ scale: Double) -> Double {
        min(4, max(0.2, scale))
    }

    /// Maps finger drag in screen/card space into the layer's local width/height axes.
    static func localDragDelta(_ translation: CGSize, rotationDegrees: Double) -> CGSize {
        let r = rotationDegrees * .pi / 180
        let c = cos(r)
        let s = sin(r)
        return CGSize(
            width: translation.width * c + translation.height * s,
            height: -translation.width * s + translation.height * c
        )
    }
}
