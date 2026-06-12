//
//  BuxPadShareRenderBridge.swift
//  BuxMuse — Pad-only share/card render scale (window scene, not UIScreen.main).
//

import SwiftUI

enum BuxPadShareRenderBridge {
    @MainActor
    static func imageRendererScale(
        containerWidth: CGFloat = 0,
        containerHeight: CGFloat = 0,
        displayScale: CGFloat = 0
    ) -> CGFloat {
        if displayScale > 0 {
            return displayScale
        }
        return BuxPadSceneScale.displayScale(
            containerWidth: containerWidth,
            containerHeight: containerHeight
        )
    }

    @MainActor
    static func renderCard<V: View>(
        _ content: V,
        width: CGFloat,
        displayScale: CGFloat = 0,
        containerWidth: CGFloat = 0,
        containerHeight: CGFloat = 0
    ) -> UIImage? {
        let renderer = ImageRenderer(content: content.frame(width: width))
        renderer.scale = imageRendererScale(
            containerWidth: containerWidth,
            containerHeight: containerHeight,
            displayScale: displayScale
        )
        if #available(iOS 18.0, *) {
            renderer.proposedSize = ProposedViewSize(width: width, height: nil)
        }
        return renderer.uiImage
    }
}
