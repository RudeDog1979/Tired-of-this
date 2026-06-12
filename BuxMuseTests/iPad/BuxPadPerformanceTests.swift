//
//  BuxPadPerformanceTests.swift
//

import Foundation
import Testing
import UIKit
@testable import BuxMuse

@MainActor
struct BuxPadPerformanceTests {

    @Test func containerResize_incrementsToken() {
        let brain = BuxPadNavigationBrain()
        brain.selectExpense(UUID())
        let before = brain.containerResizeToken
        brain.notifyContainerResize(width: 640, layoutMode: .compact)
        #expect(brain.containerResizeToken == before + 1)
        #expect(brain.lastContainerWidth == 640)
    }

    @Test func containerResize_reResolvesActivePresentation() {
        let brain = BuxPadNavigationBrain()
        brain.selectExpense(UUID())
        #expect(brain.resolvedSurface == .splitColumn)
        brain.notifyContainerResize(width: 400, layoutMode: .compact)
        #expect(brain.resolvedSurface == .splitColumn)
    }

    @Test func sceneScale_clampsToContainer() {
        let scale = BuxPadSceneScale.displayScale(containerWidth: 500, containerHeight: 700)
        #expect(scale >= 2)
        #expect(scale <= UIScreen.main.scale)
    }

    @Test func shareRenderBridge_prefersExplicitDisplayScale() {
        let scale = BuxPadShareRenderBridge.imageRendererScale(
            displayScale: 3
        )
        #expect(scale == 3)
    }

    @Test func brainDebounceInterval_isUnder16ms() {
        #expect(BuxPadMetricsConstants.brainResizeDebounceNs <= 16_000_000)
    }
}
