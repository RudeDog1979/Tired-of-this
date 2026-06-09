//
//  BuxPadBrainResizeCoordinator.swift
//  BuxMuse — Debounces pad brain refresh on split drag / size-class transitions.
//

import SwiftUI

struct BuxPadBrainResizeCoordinator: ViewModifier {
    let isPad: Bool
    var columnVisibility: NavigationSplitViewVisibility?

    @Environment(\.buxContainerWidth) private var containerWidth
    @Environment(\.buxLayoutMode) private var layoutMode
    @EnvironmentObject private var padBrain: BuxPadNavigationBrain

    @State private var debounceTask: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .onChange(of: containerWidth) { _, newWidth in
                scheduleResize(width: newWidth)
            }
            .onChange(of: layoutMode) { _, _ in
                scheduleResize(width: containerWidth)
            }
            .onChange(of: columnVisibilityToken) { _, _ in
                scheduleResize(width: containerWidth)
            }
            .onDisappear {
                debounceTask?.cancel()
            }
    }

    private var columnVisibilityToken: String {
        columnVisibility.map { String(describing: $0) } ?? ""
    }

    private func scheduleResize(width: CGFloat) {
        guard isPad else { return }
        debounceTask?.cancel()
        debounceTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: BuxPadMetricsConstants.brainResizeDebounceNs)
            guard !Task.isCancelled else { return }
            padBrain.notifyContainerResize(width: width, layoutMode: layoutMode)
        }
    }
}

extension View {
    func buxPadDebouncedBrainResize(
        isPad: Bool = BuxPadIdiom.isPad,
        columnVisibility: NavigationSplitViewVisibility? = nil
    ) -> some View {
        modifier(BuxPadBrainResizeCoordinator(isPad: isPad, columnVisibility: columnVisibility))
    }
}
