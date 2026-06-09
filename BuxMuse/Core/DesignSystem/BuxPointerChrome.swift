//
//  BuxPointerChrome.swift
//  BuxMuse — Apple Pencil + mouse hover feedback (custom — no system hoverEffect flash).
//

import SwiftUI

enum BuxPointerFeedback {
    static let hoverScale: CGFloat = 1.04
    static let hoverAnimation: Animation = .easeOut(duration: 0.16)

    static var isEnabled: Bool {
        !BuxMotion.reducedMotion
    }
}

private struct BuxPointerHoverScaleModifier: ViewModifier {
    var scale: CGFloat = BuxPointerFeedback.hoverScale

    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isHovered && BuxPointerFeedback.isEnabled ? scale : 1)
            .animation(BuxPointerFeedback.hoverAnimation, value: isHovered)
            .onContinuousHover { phase in
                switch phase {
                case .active:
                    isHovered = true
                case .ended:
                    isHovered = false
                }
            }
    }
}

/// Press + pointer hover for `ButtonStyle` labels — each button keeps its own hover state.
struct BuxPointerButtonStyleBody: View {
    let configuration: ButtonStyle.Configuration
    var pressedScale: CGFloat = 0.985
    var pressedOpacity: CGFloat?
    var hoverScale: CGFloat = BuxPointerFeedback.hoverScale

    @State private var isHovered = false

    var body: some View {
        configuration.label
            .scaleEffect(displayScale)
            .opacity(displayOpacity)
            .animation(BuxPointerFeedback.hoverAnimation, value: isHovered)
            .animation(.buxSoftPress, value: configuration.isPressed)
            .onContinuousHover { phase in
                guard BuxPointerFeedback.isEnabled else { return }
                switch phase {
                case .active:
                    isHovered = true
                case .ended:
                    isHovered = false
                }
            }
    }

    private var displayScale: CGFloat {
        if configuration.isPressed { return pressedScale }
        if isHovered && BuxPointerFeedback.isEnabled { return hoverScale }
        return 1
    }

    private var displayOpacity: CGFloat {
        if let pressedOpacity, configuration.isPressed { return pressedOpacity }
        return 1
    }
}

extension View {
    /// Subtle lift on Pencil / trackpad / mouse hover — safe inside ScrollView.
    func buxPointerReactive(scale: CGFloat = BuxPointerFeedback.hoverScale) -> some View {
        modifier(BuxPointerHoverScaleModifier(scale: scale))
    }

    /// Dense settings rows — press + hover (ScrollView cards; `List` rows get system hover).
    func buxSettingsRowInteraction() -> some View {
        buttonStyle(BuxMicroShrinkStyle())
    }
}
