//
//  BuxMotion.swift
//  BuxMuse Design System — unified springs, transitions, modifiers.
//

import SwiftUI
import QuartzCore
import UIKit

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

    /// Brand themes on/off — preset block reveal in Appearance settings.
    /// Uses continuous spring smoothing so ProMotion can interpolate every refresh.
    static var brandThemesToggle: Animation {
        if reducedMotion {
            return .easeInOut(duration: 0.28)
        }
        if #available(iOS 17.0, *) {
            return .smooth(duration: 0.52, extraBounce: 0)
        }
        return .spring(response: 0.46, dampingFraction: 0.9, blendDuration: 0)
    }

    /// Wall-clock span for brand-theme preset swap — matches `brandThemesToggle`.
    static var brandThemesToggleDuration: TimeInterval {
        reducedMotion ? 0.28 : 0.54
    }

    /// Brand theme crossfade — smooth, ~1s ease.
    static var themeCrossfade: Animation {
        reducedMotion ? .easeInOut(duration: 0.2) : .easeInOut(duration: 1.0)
    }

    /// Light / dark / system display mode — matches theme crossfade timing.
    static var displayModeCrossfade: Animation { themeCrossfade }

    static var appearanceCrossfadeDuration: TimeInterval {
        reducedMotion ? 0.2 : 1.0
    }

    static func categoryCardDelay(index: Int) -> Animation {
        slide.delay(reducedMotion ? 0 : Double(index) * 0.055)
    }
}

// MARK: - ProMotion boost (animation window only — no idle FPS lock)

private final class BuxProMotionBoostAnchorView: UIView {
    private var displayLink: CADisplayLink?
    private var boostUntil: CFTimeInterval = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        isHidden = true

        let link = CADisplayLink(target: self, selector: #selector(tick))
        if #available(iOS 15.0, *) {
            let maxFPS = Float(UIScreen.main.maximumFramesPerSecond)
            link.preferredFrameRateRange = CAFrameRateRange(
                minimum: 60,
                maximum: max(60, maxFPS),
                preferred: max(60, maxFPS)
            )
        }
        link.add(to: .main, forMode: .common)
        link.isPaused = true
        displayLink = link
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    deinit {
        displayLink?.invalidate()
    }

    func boost(for duration: TimeInterval) {
        boostUntil = CACurrentMediaTime() + duration
        displayLink?.isPaused = false
    }

    @objc private func tick() {
        guard CACurrentMediaTime() >= boostUntil else { return }
        displayLink?.isPaused = true
    }
}

private final class BuxProMotionBoostCoordinator {
    var lastTrigger: Any?
}

private struct BuxProMotionBoostRepresentable<T: Equatable>: UIViewRepresentable {
    let trigger: T
    let duration: TimeInterval

    func makeCoordinator() -> BuxProMotionBoostCoordinator {
        BuxProMotionBoostCoordinator()
    }

    func makeUIView(context: Context) -> BuxProMotionBoostAnchorView {
        BuxProMotionBoostAnchorView()
    }

    func updateUIView(_ uiView: BuxProMotionBoostAnchorView, context: Context) {
        let coordinator = context.coordinator
        if let last = coordinator.lastTrigger as? T, last != trigger {
            uiView.boost(for: duration)
        }
        coordinator.lastTrigger = trigger
    }
}

extension View {
    /// Nudges the display to use full ProMotion headroom while `trigger` animates — pauses when idle.
    func buxProMotionBoost<T: Equatable>(
        on trigger: T,
        duration: TimeInterval = BuxMotion.brandThemesToggleDuration
    ) -> some View {
        background {
            BuxProMotionBoostRepresentable(trigger: trigger, duration: duration)
                .allowsHitTesting(false)
        }
    }
}

private struct BuxInstantAppearanceSectionChromeKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// When true, form section card fills/strokes snap instantly (Appearance settings rows below theme picker).
    var buxInstantAppearanceSectionChrome: Bool {
        get { self[BuxInstantAppearanceSectionChromeKey.self] }
        set { self[BuxInstantAppearanceSectionChromeKey.self] = newValue }
    }
}

extension View {
    /// Locks frames, shadows, and typography during brand-theme changes.
    func buxStableThemeLayout(themeId: String) -> some View {
        self
    }

    /// Crossfades theme-driven colors without shifting layout.
    func buxAnimateThemeColors(themeId: String) -> some View {
        modifier(BuxAnimateAppearanceColorsModifier(themeId: themeId))
    }
}

private struct BuxAnimateAppearanceColorsModifier: ViewModifier {
    let themeId: String
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.buxInstantAppearanceSectionChrome) private var instantAppearanceSectionChrome
    @ObservedObject private var settings = SettingsStore.shared

    func body(content: Content) -> some View {
        if instantAppearanceSectionChrome {
            content
        } else {
            content
                .animation(BuxMotion.themeCrossfade, value: themeId)
                .animation(BuxMotion.themeCrossfade, value: colorScheme)
                .animation(BuxMotion.themeCrossfade, value: settings.brandThemesEnabled)
        }
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
