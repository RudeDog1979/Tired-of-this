//
//  BuxTabBarScrollState.swift
//  BuxMuse
//
//  Lightweight scroll-linked tab bar minimize (custom pill — visual only).
//

import SwiftUI
import Combine

final class BuxTabBarScrollState: ObservableObject {
    static let shared = BuxTabBarScrollState()

    @Published private(set) var isMinimized = false

    private var lastOffset: CGFloat = 0

    var minimizeOffset: CGFloat { isMinimized ? 14 : 0 }
    var minimizeOpacity: Double { isMinimized ? 0.88 : 1.0 }

    func reset() {
        isMinimized = false
        lastOffset = 0
    }

    fileprivate func handleScrollOffset(_ offset: CGFloat) {
        let delta = offset - lastOffset
        if offset <= 8 {
            if isMinimized { isMinimized = false }
        } else if delta > 6 {
            if !isMinimized { isMinimized = true }
        } else if delta < -6 {
            if isMinimized { isMinimized = false }
        }
        lastOffset = offset
    }
}

private struct BuxTabBarScrollMinimizeModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content
                .onScrollGeometryChange(for: CGFloat.self) { geometry in
                    geometry.contentOffset.y + geometry.contentInsets.top
                } action: { _, newValue in
                    BuxTabBarScrollState.shared.handleScrollOffset(newValue)
                }
        } else {
            content
        }
    }
}

extension View {
    func buxTabBarScrollMinimizeTracking() -> some View {
        modifier(BuxTabBarScrollMinimizeModifier())
    }
}
