//
//  BuxContainerMetrics.swift
//  BuxMuse — Reports container size into environment (pad path). No UIScreen.main.
//

import SwiftUI

private struct BuxContainerMetricsModifier: ViewModifier {
    @State private var containerSize: CGSize = .zero

    private func applyContainerSize(_ newSize: CGSize) {
        guard newSize != containerSize else { return }
        // First valid size must land synchronously — async deferral left Home tab rail at width 0 on iPad cold launch.
        if containerSize == .zero, newSize.width >= BuxPadLayout.splitSidebarMin {
            containerSize = newSize
            return
        }
        DispatchQueue.main.async {
            containerSize = newSize
        }
    }

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                GeometryReader { geo in
                    Color.clear
                        .onAppear { applyContainerSize(geo.size) }
                        .onChange(of: geo.size) { _, newSize in
                            applyContainerSize(newSize)
                        }
                }
                .ignoresSafeArea(.keyboard)
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
