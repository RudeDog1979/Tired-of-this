//
//  BuxRootTheme.swift
//  BuxMuse
//
//  Root semantic brand theme — M3 material surfaces + accent for system UI.
//

import SwiftUI
import UIKit

// MARK: - Segmented control accent (SwiftUI Picker → UISegmentedControl tint bridge)

/// Applies `selectedSegmentTintColor` to the native UISegmentedControl backing a SwiftUI segmented Picker.
private struct BuxSegmentedControlAccentBridge: UIViewRepresentable {
    let accent: Color

    func makeUIView(context: Context) -> BuxSegmentedTintAnchorView {
        let view = BuxSegmentedTintAnchorView()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: BuxSegmentedTintAnchorView, context: Context) {
        uiView.accent = UIColor(accent)
        uiView.applyAccent()
    }
}

private final class BuxSegmentedTintAnchorView: UIView {
    var accent: UIColor = .systemBlue

    override func didMoveToWindow() {
        super.didMoveToWindow()
        applyAccent()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        applyAccent()
    }

    func applyAccent() {
        if let segmented = findHostedSegmentedControl() {
            Self.styleSegmentedControl(segmented, accent: accent)
        }
    }

    private func findHostedSegmentedControl() -> UISegmentedControl? {
        var current: UIView? = self
        while let view = current {
            if let superview = view.superview {
                for child in superview.subviews where child !== view {
                    if let segmented = Self.findSegmentedControl(in: child) { return segmented }
                }
            }
            if let segmented = Self.findSegmentedControl(in: view) { return segmented }
            current = view.superview
        }
        return nil
    }

    static func styleSegmentedControl(_ segmented: UISegmentedControl, accent: UIColor) {
        segmented.selectedSegmentTintColor = accent
        segmented.setTitleTextAttributes(
            [.foregroundColor: UIColor.label],
            for: .normal
        )
        segmented.setTitleTextAttributes(
            [.foregroundColor: UIColor.white],
            for: .selected
        )
    }

    private static func findSegmentedControl(in view: UIView) -> UISegmentedControl? {
        if let control = view as? UISegmentedControl { return control }
        for subview in view.subviews {
            if let control = findSegmentedControl(in: subview) { return control }
        }
        return nil
    }
}

extension View {
    /// Forces brand accent on the native UISegmentedControl behind a segmented Picker.
    func buxSegmentedControlAccent(_ accent: Color) -> some View {
        overlay {
            BuxSegmentedControlAccentBridge(accent: accent)
                .frame(width: 0, height: 0)
                .allowsHitTesting(false)
        }
    }
}

// MARK: - Semantic palette (resolved per theme + color scheme)

struct BuxSemanticTheme: Equatable {
    let accent: Color
    let labelPrimary: Color
    let labelSecondary: Color
    let labelTertiary: Color
    let chevronMuted: Color
    let cardFill: Color
    let accentWash: Color
    let chipMutedFill: Color

    static func resolve(themeManager: ThemeManager, colorScheme: ColorScheme) -> BuxSemanticTheme {
        let settings = SettingsStore.shared
        let scheme = themeManager.materialScheme(for: colorScheme, branded: settings.brandThemesEnabled)
        let accent = themeManager.contrastAccentColor(for: colorScheme)
        return BuxSemanticTheme(
            accent: accent,
            labelPrimary: scheme.onSurface,
            labelSecondary: scheme.onSurfaceVariant,
            labelTertiary: scheme.onSurfaceVariant.opacity(0.88),
            chevronMuted: themeManager.chevronMuted(for: colorScheme),
            cardFill: scheme.surface,
            accentWash: scheme.primaryContainer.opacity(colorScheme == .dark ? 0.55 : 0.85),
            chipMutedFill: scheme.surfaceContainerHighest
        )
    }
}

private struct BuxSemanticThemeKey: EnvironmentKey {
    static let defaultValue = BuxSemanticTheme.resolve(
        themeManager: ThemeManager(),
        colorScheme: .light
    )
}

extension EnvironmentValues {
    var buxSemanticTheme: BuxSemanticTheme {
        get { self[BuxSemanticThemeKey.self] }
        set { self[BuxSemanticThemeKey.self] = newValue }
    }
}

// MARK: - Global branded surfaces (BuxCard + shared chrome)

private struct BuxBrandSurfacesKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// When true, `BuxCard` uses M3-toned chrome (app-wide).
    var buxBrandSurfaces: Bool {
        get { self[BuxBrandSurfacesKey.self] }
        set { self[BuxBrandSurfacesKey.self] = newValue }
    }
}

// MARK: - Root modifier (apply once at app root)

struct BuxRootBrandThemeModifier: ViewModifier {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var settings = SettingsStore.shared

    func body(content: Content) -> some View {
        // Observe theme id so semantic + material environments refresh on every pick.
        let _ = themeManager.current.id
        let semantic = BuxSemanticTheme.resolve(themeManager: themeManager, colorScheme: colorScheme)
        let material = themeManager.materialScheme(for: colorScheme, branded: settings.brandThemesEnabled)
        content
            .tint(semantic.accent)
            .accentColor(semantic.accent)
            .environment(\.buxSemanticTheme, semantic)
            .environment(\.buxMaterialScheme, material)
            .environment(\.buxBrandSurfaces, settings.brandThemesEnabled)
            .animation(BuxMotion.themeCrossfade, value: themeManager.current.id)
    }
}

// MARK: - Native Liquid Glass buttons (parent tint → see-through chrome)

enum BuxNativeGlassGate {
    static var isActive: Bool {
        SettingsStore.shared.useGlassmorphism && BuxPlatform.supportsLiquidGlass
    }
}

enum BuxNativeButtonRole {
    case secondary
    case primary
}

private struct BuxNativeButtonStyleModifier: ViewModifier {
    let role: BuxNativeButtonRole
    var controlSize: ControlSize = .small

    func body(content: Content) -> some View {
        if SettingsStore.shared.useGlassmorphism, BuxPlatform.supportsLiquidGlass, #available(iOS 26, *) {
            switch role {
            case .secondary:
                content
                    .buttonStyle(.glass)
                    .controlSize(controlSize)
            case .primary:
                content
                    .buttonStyle(.glassProminent)
                    .controlSize(controlSize)
            }
        } else {
            switch role {
            case .secondary:
                content
                    .buttonStyle(.bordered)
                    .controlSize(controlSize)
            case .primary:
                content
                    .buttonStyle(.borderedProminent)
                    .controlSize(controlSize)
            }
        }
    }
}

enum BuxNativeButtonRowRole {
    /// Clear glass — accent on label/icon only.
    case secondary
    /// Tinted glassProminent — white label via parent tint.
    case primary
}

private struct BuxNativeButtonRowChromeModifier: ViewModifier {
    let accent: Color
    let role: BuxNativeButtonRowRole

    func body(content: Content) -> some View {
        switch role {
        case .secondary:
            content.foregroundStyle(accent)
        case .primary:
            content.tint(accent)
        }
    }
}

extension View {
    /// Native button chrome — pair with `buxNativeButtonRowChrome` on the parent HStack.
    func buxNativeButtonStyle(
        _ role: BuxNativeButtonRole = .secondary,
        controlSize: ControlSize = .small
    ) -> some View {
        modifier(BuxNativeButtonStyleModifier(role: role, controlSize: controlSize))
    }

    /// Single-button tint — secondary: accent label; primary/destructive: white via tint.
    @ViewBuilder
    func buxActionButtonChrome(
        role: BuxActionButtonRole,
        accent: Color,
        isEnabled: Bool = true
    ) -> some View {
        let tint = role.actionTint(defaultAccent: accent)
        let applied = isEnabled ? tint : tint.opacity(0.45)
        switch role {
        case .primary, .destructive:
            self.tint(applied)
        case .secondary, .tinted:
            self.foregroundStyle(applied)
        }
    }

    /// Parent row tint — secondary: tinted labels; primary: white labels on prominent glass.
    func buxNativeButtonRowChrome(accent: Color, role: BuxNativeButtonRowRole = .secondary) -> some View {
        modifier(BuxNativeButtonRowChromeModifier(accent: accent, role: role))
    }

    /// Shared glass sampling for adjacent `.glass` buttons — prevents seam shadows between pills.
    @ViewBuilder
    func buxNativeGlassButtonRowContainer(spacing: CGFloat = 8) -> some View {
        if SettingsStore.shared.useGlassmorphism, BuxPlatform.supportsLiquidGlass, #available(iOS 26, *) {
            GlassEffectContainer(spacing: spacing) {
                self
            }
        } else {
            self
        }
    }
}

// MARK: - Segmented picker (liquid glass + brand accent)

private struct BuxThemedSegmentedPickerModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager

    private var accent: Color {
        themeManager.contrastAccentColor(for: colorScheme)
    }

    func body(content: Content) -> some View {
        HStack {
            content
                .pickerStyle(.segmented)
                .labelsHidden()
        }
        .tint(accent)
        .buxSegmentedControlAccent(accent)
    }
}

extension View {
    /// Native segmented control with liquid-glass chrome and brand accent on the selected segment.
    func buxThemedSegmentedPicker() -> some View {
        modifier(BuxThemedSegmentedPickerModifier())
    }

    /// Apple-native tint + semantic labels + branded surfaces for custom components.
    func buxRootBrandTheme() -> some View {
        modifier(BuxRootBrandThemeModifier())
    }

    /// Sheets / covers: accent tint on controls only — system backgrounds (HIG).
    func buxThemedPresentation() -> some View {
        buxRootBrandTheme()
    }

    /// Sheets / covers: accent tint + M3 canvas + themed navigation bar.
    func buxThemedSheetContent() -> some View {
        buxThemedPresentation()
            .buxInterfaceLocale()
            .buxMeshSheetPresentation()
            .buxSheetNavigationChrome()
    }

    /// Studio sheets / covers — M3 canvas + studio form margins.
    func buxStudioSheetContent() -> some View {
        buxThemedSheetContent()
            .environment(\.studioEnhancedTint, true)
    }

    /// Detail / hub sheets — flat M3 canvas behind sheet chrome.
    func buxMeshSheetPresentation() -> some View {
        modifier(BuxMeshSheetPresentationModifier())
    }
}

private struct BuxMeshSheetPresentationModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager

    func body(content: Content) -> some View {
        content.presentationBackground {
            themeManager.screenBackground(for: colorScheme)
        }
    }
}

extension View {
    func buxLabelPrimary() -> some View {
        modifier(BuxSemanticForegroundModifier(\.labelPrimary))
    }

    func buxLabelSecondary() -> some View {
        modifier(BuxSemanticForegroundModifier(\.labelSecondary))
    }

    func buxLabelTertiary() -> some View {
        modifier(BuxSemanticForegroundModifier(\.labelTertiary))
    }

    func buxChevronMuted() -> some View {
        modifier(BuxSemanticForegroundModifier(\.chevronMuted))
    }
}

// MARK: - Chevron (Settings / navigation rows)

struct BuxChevron: View {
    enum Direction { case left, right }

    var direction: Direction = .right

    var body: some View {
        Image(systemName: direction == .left ? "chevron.left" : "chevron.right")
            .font(.system(size: 12, weight: .semibold))
            .buxChevronMuted()
    }
}

private struct BuxSemanticForegroundModifier: ViewModifier {
    @Environment(\.buxSemanticTheme) private var semantic
    let keyPath: KeyPath<BuxSemanticTheme, Color>

    init(_ keyPath: KeyPath<BuxSemanticTheme, Color>) {
        self.keyPath = keyPath
    }

    func body(content: Content) -> some View {
        content.foregroundStyle(semantic[keyPath: keyPath])
    }
}

// MARK: - Native Form / List (material shows screen behind)

extension View {
    /// Hides default Form/List chrome so M3 screen background reads through native sheet material.
    func buxNativeFormAppearance() -> some View {
        scrollContentBackground(.hidden)
    }
}
