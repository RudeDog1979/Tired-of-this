//
//  BuxPadSceneScaleEnvironment.swift
//  BuxMuse — Window-scene scale overrides (pad path; frozen views keep UIScreen reads).
//

import SwiftUI

private struct BuxPadDisplayScaleKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

private struct BuxPadReferenceWidthKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    /// Scene display scale for share/card renders. `0` = fall back to `UIScreen.main.scale`.
    var buxPadDisplayScale: CGFloat {
        get { self[BuxPadDisplayScaleKey.self] }
        set { self[BuxPadDisplayScaleKey.self] = newValue }
    }

    /// Active window container width — replaces `UIScreen.main.bounds.width` on pad hosts.
    var buxPadReferenceWidth: CGFloat {
        get { self[BuxPadReferenceWidthKey.self] }
        set { self[BuxPadReferenceWidthKey.self] = newValue }
    }
}

enum BuxPadSceneScale {
    @MainActor
    static func displayScale(containerWidth: CGFloat, containerHeight: CGFloat) -> CGFloat {
        let screenScale = UIScreen.main.scale
        guard BuxPadIdiom.isPad, containerWidth > 0, containerHeight > 0 else {
            return max(screenScale, 2)
        }
        let screenBounds = UIScreen.main.bounds
        let widthRatio = min(1, containerWidth / max(screenBounds.width, 1))
        let heightRatio = min(1, containerHeight / max(screenBounds.height, 1))
        let sceneRatio = min(widthRatio, heightRatio)
        return max(2, screenScale * sceneRatio)
    }
}
