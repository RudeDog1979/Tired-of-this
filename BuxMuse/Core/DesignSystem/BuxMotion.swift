//
//  BuxMotion.swift
//  BuxMuse Design System — unified springs, transitions, modifiers.
//

import SwiftUI

enum BuxMotion {
    static var reducedMotion: Bool {
        SettingsStore.shared.reducedMotion
    }

    static var press: Animation {
        reducedMotion ? .easeInOut(duration: 0.18) : .spring(response: 0.28, dampingFraction: 0.9)
    }

    static var snap: Animation {
        reducedMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.25, dampingFraction: 0.6)
    }

    static var bounce: Animation {
        reducedMotion ? .easeInOut(duration: 0.28) : .spring(response: 0.5, dampingFraction: 0.65)
    }

    static var heavy: Animation {
        reducedMotion ? .easeInOut(duration: 0.3) : .spring(response: 0.6, dampingFraction: 0.72)
    }

    static var liquid: Animation {
        reducedMotion ? .easeInOut(duration: 0.28) : .spring(response: 0.55, dampingFraction: 0.62)
    }

    static var slide: Animation {
        reducedMotion ? .easeInOut(duration: 0.25) : .spring(response: 0.48, dampingFraction: 0.62)
    }

    static var stretch: Animation {
        reducedMotion ? .easeInOut(duration: 0.28) : .spring(response: 0.45, dampingFraction: 0.55)
    }

    /// Hero quick-action squash — Rory Bain-style spring (0.4 / 0.5).
    static var heroPress: Animation {
        reducedMotion ? .easeInOut(duration: 0.15) : .spring(response: 0.4, dampingFraction: 0.5)
    }

    /// Daily tip popup — bouncy present, soft dismiss.
    static var tipPopupPresent: Animation {
        reducedMotion ? .easeInOut(duration: 0.28) : .spring(response: 0.52, dampingFraction: 0.68)
    }

    static var tipPopupDismiss: Animation {
        reducedMotion ? .easeInOut(duration: 0.22) : .spring(response: 0.40, dampingFraction: 0.82)
    }

    static func stagger(index: Int, base: Double = 0.055) -> Animation {
        let anim = bounce
        return reducedMotion ? anim : anim.delay(Double(index) * base)
    }

    /// Mood tint on / off (expense edit + detail overview).
    static var emotionFadeIn: Animation {
        reducedMotion ? .easeInOut(duration: 0.28) : .easeOut(duration: 0.55)
    }

    static var emotionFadeOut: Animation {
        reducedMotion ? .easeInOut(duration: 0.28) : .easeOut(duration: 0.88)
    }

    static var emotionFadeOutDuration: TimeInterval {
        reducedMotion ? 0.28 : 0.88
    }

    /// Gap before swapping mood color during A → B crossfade.
    static var emotionCrossfadeSwapDelay: TimeInterval {
        reducedMotion ? 0.18 : 0.32
    }

    /// iPad FAB Themes → Settings Appearance detail slide + fade.
    static var appearanceSettingsEntry: Animation {
        reducedMotion ? .easeInOut(duration: 0.22) : .easeInOut(duration: 0.34)
    }

    /// Brand theme crossfade — smooth, ~1s ease.
    static var themeCrossfade: Animation {
        reducedMotion ? .easeInOut(duration: 0.2) : .easeInOut(duration: 1.0)
    }

    static func categoryCardDelay(index: Int) -> Animation {
        slide.delay(reducedMotion ? 0 : Double(index) * 0.055)
    }
}

extension AnyTransition {
    static var buxSheetPresent: AnyTransition {
        .asymmetric(
            insertion: .scale(scale: 0.92, anchor: .center).combined(with: .opacity),
            removal: .scale(scale: 0.96, anchor: .center).combined(with: .opacity)
        )
    }

    static var buxScreenPush: AnyTransition {
        .asymmetric(
            insertion: .offset(x: 24).combined(with: .opacity),
            removal: .offset(x: -16).combined(with: .opacity)
        )
    }

    static var buxFadeUp: AnyTransition {
        .asymmetric(
            insertion: .offset(y: 12).combined(with: .opacity),
            removal: .opacity
        )
    }
}

struct BuxScreenEntranceModifier: ViewModifier {
    let index: Int
    let isVisible: Bool

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 16)
            .scaleEffect(isVisible ? 1 : 0.98, anchor: .top)
            .animation(BuxMotion.stagger(index: index), value: isVisible)
    }
}

extension View {
    func buxScreenEntrance(index: Int, isVisible: Bool) -> some View {
        modifier(BuxScreenEntranceModifier(index: index, isVisible: isVisible))
    }

    func buxSheetTransition() -> some View {
        transition(BuxMotion.reducedMotion ? .opacity : .buxSheetPresent)
    }
}
