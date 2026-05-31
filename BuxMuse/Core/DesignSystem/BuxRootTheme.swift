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
        var current: UIView? = self
        while let view = current {
            if let superview = view.superview {
                for child in superview.subviews where child !== view {
                    if let segmented = Self.findSegmentedControl(in: child) {
                        segmented.selectedSegmentTintColor = accent
                        return
                    }
                }
            }
            if let segmented = Self.findSegmentedControl(in: view) {
                segmented.selectedSegmentTintColor = accent
                return
            }
            current = view.superview
        }
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
        let scheme = themeManager.materialScheme(for: colorScheme)
        return BuxSemanticTheme(
            accent: scheme.primary,
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
    @Environment(\.themeManager) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var settings = SettingsStore.shared

    func body(content: Content) -> some View {
        let semantic = BuxSemanticTheme.resolve(themeManager: themeManager, colorScheme: colorScheme)
        let material = themeManager.materialScheme(for: colorScheme, branded: settings.brandThemesEnabled)
        content
            .tint(semantic.accent)
            .accentColor(semantic.accent)
            .environment(\.buxSemanticTheme, semantic)
            .environment(\.buxMaterialScheme, material)
            .environment(\.buxBrandSurfaces, settings.brandThemesEnabled)
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
