//
//  BuxmationSystem.swift
//  BuxMuse
//
//  Master Motion System — All 20 animation primitives.
//  iOS 26 first, iOS 18 fallback via #available guards.
//

import SwiftUI

// MARK: - Global Spring Physics

extension Animation {
    /// Primitive 3: Soft Bounce — the core premium liquid feel.
    static var buxBounce: Animation {
        if #available(iOS 17.0, *) {
            return .spring(response: 0.5, dampingFraction: 0.65)
        } else {
            return .spring(response: 0.5, dampingFraction: 0.65)
        }
    }

    /// Quick snappy response for micro-interactions.
    static var buxSnap: Animation {
        .spring(response: 0.25, dampingFraction: 0.6)
    }

    /// Slower, weightier response for large element transitions.
    static var buxHeavy: Animation {
        .spring(response: 0.6, dampingFraction: 0.72)
    }

    /// Staggered entrance: add an index-based delay.
    static func buxStagger(index: Int, base: Double = 0.05) -> Animation {
        buxBounce.delay(Double(index) * base)
    }

    /// Liquid pill expand/collapse and selection slide (GIF-style water).
    static var buxLiquidSpring: Animation {
        .spring(response: 0.55, dampingFraction: 0.62)
    }

    /// Dashboard category deck — slide from right with visible bounce (no fade).
    static var buxCategorySpring: Animation {
        .spring(response: 0.48, dampingFraction: 0.62)
    }

    static func buxCategoryCardDelay(index: Int) -> Animation {
        buxCategorySpring.delay(Double(index) * 0.055)
    }
}

// MARK: - Dashboard category slide (no opacity)

private struct BuxCategorySlideModifier: ViewModifier, Animatable {
    var offset: CGFloat
    var scale: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(offset, scale) }
        set {
            offset = newValue.first
            scale = newValue.second
        }
    }

    func body(content: Content) -> some View {
        content
            .offset(x: offset)
            .scaleEffect(scale, anchor: .leading)
    }
}

extension AnyTransition {
    /// Whole category block — direction +1 forward (from right), -1 backward (from left).
    static func buxCategorySlide(direction: Int) -> AnyTransition {
        let enterOffset = CGFloat(direction) * 56
        let exitOffset = CGFloat(-direction) * 40
        return .asymmetric(
            insertion: .modifier(
                active: BuxCategorySlideModifier(offset: enterOffset, scale: 0.96),
                identity: BuxCategorySlideModifier(offset: 0, scale: 1)
            ),
            removal: .modifier(
                active: BuxCategorySlideModifier(offset: exitOffset, scale: 0.97),
                identity: BuxCategorySlideModifier(offset: 0, scale: 1)
            )
        )
    }
}

// MARK: - Expense header manage icons (roll off to the right when search opens)

struct ExpenseManageRollOutModifier: ViewModifier {
    let isHidden: Bool
    let staggerIndex: Int

    private var travel: CGFloat {
        CGFloat(44 + staggerIndex * 16)
    }

    func body(content: Content) -> some View {
        content
            .offset(x: isHidden ? travel : 0)
            .scaleEffect(isHidden ? 0.72 : 1, anchor: .trailing)
            .opacity(isHidden ? 0 : 1)
            .blur(radius: isHidden ? 3 : 0)
            .animation(.buxLiquidSpring.delay(Double(staggerIndex) * 0.04), value: isHidden)
    }
}

extension View {
    func expenseManageRollOut(isHidden: Bool, staggerIndex: Int) -> some View {
        modifier(ExpenseManageRollOutModifier(isHidden: isHidden, staggerIndex: staggerIndex))
    }
}

// MARK: - Per-card stagger + parallax (pill category change)

struct BuxCategoryCardEnterModifier: ViewModifier {
    let cardIndex: Int
    let direction: Int
    let motionToken: UUID

    @State private var offsetX: CGFloat = 0
    @State private var scale: CGFloat = 1

    /// Outer block travels farther; each card travels slightly less (parallax).
    private var travel: CGFloat {
        CGFloat(direction) * max(28, 62 - CGFloat(cardIndex) * 14)
    }

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale, anchor: .leading)
            .offset(x: offsetX)
            .onAppear { runEnter() }
            .onChange(of: motionToken) { _, _ in runEnter() }
    }

    private func runEnter() {
        offsetX = travel
        scale = 0.94
        withAnimation(.buxCategoryCardDelay(index: cardIndex)) {
            offsetX = 0
            scale = 1
        }
    }
}

extension View {
    /// Staggered slide + parallax for dashboard summary cards when the pill category changes.
    func buxDashboardCategoryCard(index: Int, direction: Int, motionToken: UUID) -> some View {
        modifier(BuxCategoryCardEnterModifier(cardIndex: index, direction: direction, motionToken: motionToken))
    }
}

// MARK: - Primitive 1: Micro-Shrink Button Style

/// Taps on cards, pills, buttons, rows — instant tactile feedback.
struct BuxMicroShrinkStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.buxSnap, value: configuration.isPressed)
    }
}

// MARK: - Primitive 2 & 18: Micro-Lift + Shadow Compression Button Style

/// Transaction rows, list items, cards that open details.
/// Lifts the element and compresses its shadow on press.
struct BuxMicroLiftStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 1.02 : 1.0)
            .shadow(
                color: Color.black.opacity(configuration.isPressed ? 0.04 : 0.10),
                radius: configuration.isPressed ? 3 : 10,
                x: 0, y: configuration.isPressed ? 2 : 6
            )
            .animation(.buxSnap, value: configuration.isPressed)
    }
}

// MARK: - Primitive 4: Pulse Modifier

/// Auto-reversing scale animation. Used on Expense tab icon and confirm actions.
struct BuxPulseModifier: ViewModifier {
    let isActive: Bool

    func body(content: Content) -> some View {
        content
            .scaleEffect(isActive ? 1.22 : 1.0)
            .animation(
                isActive
                    ? .spring(response: 0.15, dampingFraction: 0.4)
                    : .spring(response: 0.2, dampingFraction: 0.5),
                value: isActive
            )
    }
}

extension View {
    func buxPulse(isActive: Bool) -> some View {
        modifier(BuxPulseModifier(isActive: isActive))
    }
}

// MARK: - Primitive 5: Wiggle Modifier

/// Left-right rotation wiggle. Used on Freelance tab icon.
struct BuxWiggleModifier: ViewModifier {
    let angle: Double

    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(angle))
    }
}

// MARK: - Primitive 6: Rotate Modifier

/// Continuous or stepped rotation. Used on Settings gear icon.
struct BuxRotateModifier: ViewModifier {
    let degrees: Double

    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(degrees))
    }
}

// MARK: - Primitives 7 & 8: Slide-Up / Slide-Down Fade Transitions

extension AnyTransition {
    /// Primitive 7: Element fades in sliding upward.
    static var slideUpFade: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .opacity
        )
    }

    /// Primitive 8: Element fades out sliding downward.
    static var slideDownFade: AnyTransition {
        .asymmetric(
            insertion: .opacity,
            removal: .move(edge: .bottom).combined(with: .opacity)
        )
    }
}

// MARK: - Primitive 9: Staggered Reveal Modifier

/// Items appear one after another with a small delay based on index.
struct BuxStaggeredRevealModifier: ViewModifier {
    let index: Int
    let isVisible: Bool

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 20)
            .animation(.buxBounce.delay(Double(index) * 0.06), value: isVisible)
    }
}

extension View {
    func buxStaggeredReveal(index: Int, isVisible: Bool) -> some View {
        modifier(BuxStaggeredRevealModifier(index: index, isVisible: isVisible))
    }
}

// MARK: - Primitive 13: Opacity Dim Background

/// A full-screen dimming overlay for expanded cards, modals, FAB menus.
struct BuxDimOverlay: View {
    let isVisible: Bool
    var opacity: Double = 0.5
    var onTap: (() -> Void)? = nil

    var body: some View {
        if isVisible {
            Color.black
                .opacity(opacity)
                .ignoresSafeArea()
                .transition(.opacity)
                .onTapGesture { onTap?() }
        }
    }
}

// MARK: - Primitive 19 & 20: Floating Elevation + Blur Reveal
// Handled structurally via .background(.thickMaterial) and .shadow()
// in CustomTabBar and FAB — no separate modifier needed.

// MARK: - Legacy: BuxmationPressCardStyle (kept for compatibility)
// This is equivalent to BuxMicroShrinkStyle with shadow compression.
struct BuxmationPressCardStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .shadow(
                color: Color.black.opacity(configuration.isPressed ? 0.02 : 0.04),
                radius: configuration.isPressed ? 3 : 8,
                x: 0, y: 3
            )
            .animation(.buxSnap, value: configuration.isPressed)
    }
}

// MARK: - MorphingPillButtonStyle (kept for Pill compatibility)
struct MorphingPillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.buxSnap, value: configuration.isPressed)
    }
}

// MARK: - List & sheet micro-motion (lightweight — no layout thrash)

extension AnyTransition {
    /// Autocomplete / inline panels — scale + fade, GPU-friendly.
    static var buxScaleReveal: AnyTransition {
        .scale(scale: 0.96, anchor: .top).combined(with: .opacity)
    }

    /// Row insert/remove in expense list.
    static var buxRowInsert: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .leading).combined(with: .opacity),
            removal: .scale(scale: 0.92, anchor: .trailing).combined(with: .opacity)
        )
    }

    /// Pill tab labels — slide from leading inside clip, no fade.
    static var buxPillLabelReveal: AnyTransition {
        .asymmetric(
            insertion: .offset(x: -12).combined(with: .scale(scale: 0.94, anchor: .leading)),
            removal: .offset(x: -8).combined(with: .scale(scale: 0.96, anchor: .leading))
        )
    }

    /// Category block under pill — emerges downward, minimal opacity.
    static var buxUnderPillEmergence: AnyTransition {
        .asymmetric(
            insertion: .offset(y: 10).combined(with: .scale(scale: 0.98, anchor: .top)),
            removal: .offset(y: -6).combined(with: .scale(scale: 0.98, anchor: .top))
        )
    }
}

// MARK: - Under-pill content motion

struct BuxUnderPillEmergenceModifier: ViewModifier {
    let category: String

    func body(content: Content) -> some View {
        content
            .id(category)
            .transition(.buxUnderPillEmergence)
    }
}

extension View {
    func buxUnderPillContent(category: String) -> some View {
        modifier(BuxUnderPillEmergenceModifier(category: category))
    }
}

struct BuxSuccessPopModifier: ViewModifier {
    let isActive: Bool

    func body(content: Content) -> some View {
        content
            .scaleEffect(isActive ? 1.04 : 1.0)
            .animation(.buxSnap, value: isActive)
    }
}

extension View {
    func buxSuccessPop(isActive: Bool) -> some View {
        modifier(BuxSuccessPopModifier(isActive: isActive))
    }

}
