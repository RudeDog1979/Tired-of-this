//
//  BuxPadAdaptiveOverlays.swift
//  BuxMuse — Routes hub overlays through BuxAdaptivePresentation on iPad.
//

import SwiftUI

enum BuxPadOverlayRouter {
    static func surface(
        for trigger: BuxPadPresentationTrigger,
        layoutMode: BuxLayoutMode
    ) -> BuxPadPresentationSurface {
        BuxAdaptivePresentation.surface(
            for: trigger,
            layoutMode: layoutMode,
            isPad: true
        )
    }
}

// MARK: - Sheet bridge (compact pad fallbacks)

struct BuxPadSheetPresentationModifier: ViewModifier {
    @Environment(\.buxLayoutMode) private var layoutMode

    @Binding var isPresented: Bool
    let trigger: BuxPadPresentationTrigger
    @ViewBuilder var sheetContent: () -> AnyView

    func body(content: Content) -> some View {
        let surface = BuxPadOverlayRouter.surface(for: trigger, layoutMode: layoutMode)
        content
            .sheet(isPresented: Binding(
                get: { isPresented && surface == .sheetLarge },
                set: { isPresented = $0 }
            )) {
                sheetContent()
            }
            .sheet(isPresented: Binding(
                get: { isPresented && surface == .sheetMedium },
                set: { isPresented = $0 }
            )) {
                sheetContent()
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
    }
}

extension View {
    func buxPadAdaptiveSheet(
        isPresented: Binding<Bool>,
        trigger: BuxPadPresentationTrigger,
        @ViewBuilder content: @escaping () -> some View
    ) -> some View {
        modifier(BuxPadSheetPresentationModifier(
            isPresented: isPresented,
            trigger: trigger,
            sheetContent: { AnyView(content()) }
        ))
    }
}
