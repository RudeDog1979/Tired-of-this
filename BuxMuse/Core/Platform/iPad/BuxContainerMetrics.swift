//
//  BuxContainerMetrics.swift
//  BuxMuse — Reports container size into environment (pad path). No UIScreen.main.
//

import SwiftUI

private struct BuxContainerMetricsModifier: ViewModifier {
    @State private var containerSize: CGSize = .zero

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                GeometryReader { geo in
                    Color.clear
                        .onAppear { containerSize = geo.size }
                        .onChange(of: geo.size) { _, newSize in
                            containerSize = newSize
                        }
                }
            }
            .environment(\.buxContainerWidth, containerSize.width)
            .environment(\.buxContainerHeight, containerSize.height)
            .environment(\.buxPadReferenceWidth, containerSize.width)
            .environment(
                \.buxPadDisplayScale,
                BuxPadSceneScale.displayScale(
                    containerWidth: containerSize.width,
                    containerHeight: containerSize.height
                )
            )
    }
}

extension View {
    /// Publishes container metrics via background geometry (no layout squeeze).
    func buxPadReportsContainerMetrics() -> some View {
        modifier(BuxContainerMetricsModifier())
    }
}
