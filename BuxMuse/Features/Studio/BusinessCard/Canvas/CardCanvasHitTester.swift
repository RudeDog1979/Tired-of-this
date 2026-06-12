//
//  CardCanvasHitTester.swift
//  BuxMuse
//

import CoreGraphics
import Foundation

enum CardCanvasHitTester {
    /// Returns topmost selectable layer at normalized point (0…1).
    static func hitTest(point: CGPoint, in document: CardCanvasDocument) -> UUID? {
        if let unlocked = hitTest(point: point, in: document, lockedOnly: false, skipLocked: true) {
            return unlocked
        }
        return hitTest(point: point, in: document, lockedOnly: false, skipLocked: false)
    }

    private static func hitTest(point: CGPoint, in document: CardCanvasDocument, lockedOnly: Bool, skipLocked: Bool) -> UUID? {
        let canvasSize = document.canvasSize
        let px = point.x * canvasSize.width
        let py = point.y * canvasSize.height

        for layer in document.layers.reversed() where !layer.isHidden {
            if skipLocked && layer.isLocked { continue }
            if lockedOnly && !layer.isLocked { continue }
            let frame = layer.transform.frame(in: canvasSize)
            if layer.transform.hitContains(point: CGPoint(x: px, y: py), frame: frame) {
                return layer.id
            }
        }
        return nil
    }
}
