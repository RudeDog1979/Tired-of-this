//
//  BuxPadUIScreenMitigation.swift
//  BuxMuse — Pad-host wrappers that compensate for frozen UIScreen.main reads.
//

import SwiftUI

private struct BuxPadDashboardUIScreenMitigation: ViewModifier {
    func body(content: Content) -> some View {
        // Hero sizing uses `buxContainerWidth` in DashboardView — no whole-view scale
        // (scaling vs full UIScreen width broke Stage Manager window layouts).
        content
    }
}

private struct BuxPadBusinessCardUIScreenMitigation: ViewModifier {
    @Environment(\.buxContainerWidth) private var containerWidth
    @Environment(\.buxContainerHeight) private var containerHeight

    func body(content: Content) -> some View {
        content
            .frame(
                maxWidth: containerWidth > 0 ? containerWidth : nil,
                maxHeight: containerHeight > 0 ? containerHeight : nil,
                alignment: .top
            )
    }
}

private struct BuxPadSceneScalePublisher: ViewModifier {
    @Environment(\.buxContainerWidth) private var containerWidth
    @Environment(\.buxContainerHeight) private var containerHeight

    func body(content: Content) -> some View {
        content
            .environment(
                \.buxPadReferenceWidth,
                containerWidth > 0 ? containerWidth : 0
            )
            .environment(
                \.buxPadDisplayScale,
                BuxPadSceneScale.displayScale(
                    containerWidth: containerWidth,
                    containerHeight: containerHeight
                )
            )
    }
}

extension View {
    /// Compensates `DashboardView` hero sizing that reads `UIScreen.main.bounds.width`.
    func buxPadDashboardUIScreenMitigation() -> some View {
        modifier(BuxPadDashboardUIScreenMitigation())
    }

    /// Bounds Business Card studio to the active scene column — never clip; hero rim/shadow paints outside.
    func buxPadBusinessCardUIScreenMitigation() -> some View {
        modifier(BuxPadBusinessCardUIScreenMitigation())
    }

    /// Publishes scene-scale env for share/card renders on the pad path.
    func buxPadPublishesSceneScale() -> some View {
        modifier(BuxPadSceneScalePublisher())
    }
}
