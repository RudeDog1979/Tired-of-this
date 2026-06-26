//
//  BuxPadInspectorPanel.swift
//  BuxMuse — Trailing inspector column for regular-width pad presentations.
//

import SwiftUI

struct BuxPadInspectorPanel<Content: View>: View {
    @Environment(\.buxLayoutMode) private var layoutMode
    @Environment(\.buxContainerWidth) private var containerWidth
    @ViewBuilder var content: () -> Content
    var onDismiss: () -> Void

    private var panelWidth: CGFloat {
        let base = BuxPadLayout.splitSidebarWidth(
            containerWidth: containerWidth,
            layoutMode: layoutMode
        )
        let minWidth: CGFloat = layoutMode == .regular ? 360 : 300
        let maxWidth: CGFloat = layoutMode == .regular ? 520 : 420
        return min(max(base, minWidth), maxWidth)
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0), location: 0),
                    .init(color: .black.opacity(0.04), location: 0.42),
                    .init(color: .black.opacity(0.12), location: 0.72),
                    .init(color: .black.opacity(0.2), location: 1)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            HStack(spacing: 0) {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onDismiss)
                    .accessibilityLabel(BuxCatalogLabel.string("Dismiss", locale: BuxInterfaceLocale.currentInterfaceLocale))

                content()
                    .frame(width: panelWidth)
                    .frame(maxHeight: .infinity)
                    .background(.regularMaterial)
                    .shadow(color: .black.opacity(0.14), radius: 28, x: -10, y: 0)
            }
            .ignoresSafeArea()
        }
        .transition(.move(edge: .trailing).combined(with: .opacity))
    }
}
