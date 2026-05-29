//
//  BuxmationSystem.swift
//  BuxMuse
//
//  Master Motion System — All 20 animation primitives.
//  iOS 26 first, iOS 18 fallback via #available guards.
//

import SwiftUI

// MARK: - Global Spring Physics (delegates to BuxMotion design tokens)

extension Animation {
    static var buxBounce: Animation { BuxMotion.bounce }
    static var buxSoftPress: Animation { BuxMotion.press }
    static var buxSnap: Animation { BuxMotion.snap }
    static var buxHeavy: Animation { BuxMotion.heavy }
    static var buxPressStretch: Animation {
        BuxMotion.reducedMotion ? .easeInOut(duration: 0.15) : .spring(response: 0.16, dampingFraction: 0.85)
    }

    static func buxStagger(index: Int, base: Double = 0.05) -> Animation {
        BuxMotion.stagger(index: index, base: base)
    }

    static func buxStaggerCascade(index: Int, base: Double = 0.05) -> Animation {
        BuxMotion.reducedMotion ? BuxMotion.bounce : BuxMotion.bounce.delay(Double(index) * base)
    }

    static var buxLiquidSpring: Animation { BuxMotion.liquid }
    static var buxCategorySpring: Animation { BuxMotion.slide }

    static func buxCategoryCardDelay(index: Int) -> Animation {
        BuxMotion.categoryCardDelay(index: index)
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

/// Soft press feedback for buttons — gentle spring, safe inside ScrollView.
struct BuxPressFeedbackStyle: ButtonStyle {
    var pressedScale: CGFloat = 0.985
    var pressedOpacity: CGFloat = 0.96

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? pressedScale : 1.0)
            .opacity(configuration.isPressed ? pressedOpacity : 1.0)
            .animation(.buxSoftPress, value: configuration.isPressed)
    }
}

/// Scroll-friendly card / row tap — plain Button, no drag gesture.
struct BuxCardButton<Label: View>: View {
    let action: () -> Void
    @ViewBuilder var label: () -> Label

    var body: some View {
        Button(action: action, label: label)
            .buttonStyle(BuxPressFeedbackStyle())
    }
}

/// Taps on cards, pills, buttons, rows — instant tactile feedback.
struct BuxMicroShrinkStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        BuxPressFeedbackStyle().makeBody(configuration: configuration)
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
// Scale-only press — no shadow animation (shadow animating inside ScrollView causes lag).
struct BuxmationPressCardStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        BuxPressFeedbackStyle(pressedScale: 0.96, pressedOpacity: 0.90).makeBody(configuration: configuration)
    }
}

/// Home dashboard cards: no system button chrome; press feedback only.
struct BuxDashboardCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.90 : 1)
            .animation(.buxSoftPress, value: configuration.isPressed)
    }
}

// MARK: - MorphingPillButtonStyle (kept for Pill compatibility)
struct MorphingPillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1.0)
            .animation(.buxSoftPress, value: configuration.isPressed)
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

// MARK: - Semantic toolbar & chip styles (Freelance Hub, sheets, designer)

/// Segment / chip controls in designer panels.
struct BuxChipButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        BuxPressFeedbackStyle(pressedScale: 0.95, pressedOpacity: 0.88).makeBody(configuration: configuration)
    }
}

/// Filled primary actions (Save Invoice, Export PDF).
struct BuxPrimaryFillButtonStyle: ButtonStyle {
    var isEnabled: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(isEnabled && configuration.isPressed ? 0.985 : 1.0)
            .opacity(isEnabled ? (configuration.isPressed ? 0.96 : 1.0) : 0.55)
            .animation(.buxSoftPress, value: configuration.isPressed)
    }
}

/// Outlined / secondary actions (Save Default, Mark Sent).
struct BuxSecondaryFillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1.0)
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .animation(.buxSoftPress, value: configuration.isPressed)
    }
}

// MARK: - Bux Action Buttons (unified CTA system)

enum BuxActionButtonRole {
    case primary
    case secondary
    /// Status actions — green paid, blue sent, etc.
    case tinted(Color)
}

enum BuxActionButtonSize {
    case compact
    case regular
    case large

    var height: CGFloat {
        switch self {
        case .compact: return 34
        case .regular: return 44
        case .large: return BuxLayout.pillHeight
        }
    }

    var fontSize: CGFloat {
        switch self {
        case .compact: return 13
        case .regular, .large: return 15
        }
    }

    var iconSize: CGFloat {
        switch self {
        case .compact: return 13
        case .regular, .large: return 15
        }
    }

    var horizontalPadding: CGFloat {
        switch self {
        case .compact: return 14
        case .regular: return 18
        case .large: return 20
        }
    }
}

private struct BuxActionPressStyle: ButtonStyle {
    var isEnabled: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(
                x: isEnabled && configuration.isPressed ? 0.965 : 1.0,
                y: isEnabled && configuration.isPressed ? 1.015 : 1.0
            )
            .opacity(isEnabled ? (configuration.isPressed ? 0.94 : 1.0) : 0.55)
            .animation(.buxPressStretch, value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed && isEnabled {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.85)
                }
            }
    }
}

struct BuxActionButton: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager

    let title: String
    let systemImage: String
    let role: BuxActionButtonRole
    let accent: Color
    var expands: Bool = false
    var size: BuxActionButtonSize = .large
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: size.iconSize, weight: .semibold))
                Text(title)
                    .font(.system(size: size.fontSize, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .padding(.horizontal, size.horizontalPadding)
            .frame(maxWidth: expands ? .infinity : nil)
            .frame(height: size.height)
            .foregroundStyle(foregroundColor)
            .background(backgroundColor)
            .clipShape(Capsule())
            .overlay {
                if showsBorder {
                    Capsule()
                        .strokeBorder(borderColor, lineWidth: 1)
                }
            }
            .shadow(color: shadowColor, radius: shadowRadius, x: 0, y: shadowY)
        }
        .buttonStyle(BuxActionPressStyle(isEnabled: isEnabled))
        .disabled(!isEnabled)
    }

    private var tintColor: Color {
        switch role {
        case .primary, .secondary: accent
        case .tinted(let color): color
        }
    }

    private var foregroundColor: Color {
        switch role {
        case .primary:
            return isEnabled ? .white : Color.white.opacity(0.65)
        case .secondary:
            return isEnabled
                ? themeManager.labelPrimary(for: colorScheme)
                : themeManager.labelTertiary(for: colorScheme)
        case .tinted:
            return isEnabled ? tintColor : tintColor.opacity(0.45)
        }
    }

    private var backgroundColor: Color {
        switch role {
        case .primary:
            return isEnabled ? tintColor : Color(UIColor.systemGray3)
        case .secondary:
            return colorScheme == .dark
                ? Color.white.opacity(0.08)
                : Color.black.opacity(0.04)
        case .tinted:
            let wash = colorScheme == .dark ? 0.24 : 0.14
            return isEnabled ? tintColor.opacity(wash) : tintColor.opacity(wash * 0.45)
        }
    }

    private var showsBorder: Bool {
        switch role {
        case .primary: return false
        case .secondary: return isEnabled
        case .tinted: return isEnabled
        }
    }

    private var borderColor: Color {
        switch role {
        case .secondary:
            return themeManager.subtleCardStroke(for: colorScheme)
        case .tinted:
            return tintColor.opacity(colorScheme == .dark ? 0.45 : 0.32)
        case .primary:
            return .clear
        }
    }

    private var shadowColor: Color {
        guard isEnabled, case .primary = role else { return .clear }
        return tintColor.opacity(colorScheme == .dark ? 0.18 : 0.14)
    }

    private var shadowRadius: CGFloat {
        role.isPrimary && isEnabled ? BuxTokens.Shadow.ctaRadius : 0
    }

    private var shadowY: CGFloat {
        role.isPrimary && isEnabled ? BuxTokens.Shadow.ctaY : 0
    }
}

private extension BuxActionButtonRole {
    var isPrimary: Bool {
        if case .primary = self { return true }
        return false
    }
}

extension View {
    /// Primary filled pill — solid accent, white label.
    func buxPrimaryPillStyle(accent: Color, controlSize: ControlSize = .regular) -> some View {
        self
            .font(.system(size: controlSize == .large ? 15 : 14, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, controlSize == .large ? 20 : 16)
            .frame(height: controlSize == .large ? BuxLayout.pillHeight : 44)
            .background(accent)
            .clipShape(Capsule())
            .buttonStyle(BuxActionPressStyle())
    }

    /// Secondary pill — neutral chrome, primary label (legible on all themes).
    func buxSecondaryPillStyle(accent: Color, controlSize: ControlSize = .regular) -> some View {
        self
            .font(.system(size: controlSize == .small ? 13 : controlSize == .large ? 15 : 14, weight: .semibold))
            .foregroundStyle(.primary)
            .padding(.horizontal, controlSize == .small ? 12 : controlSize == .large ? 20 : 16)
            .frame(height: controlSize == .small ? 34 : controlSize == .large ? BuxLayout.pillHeight : 44)
            .background(Color.primary.opacity(0.06))
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(Color.primary.opacity(0.08), lineWidth: 1))
            .buttonStyle(BuxActionPressStyle())
    }
}
