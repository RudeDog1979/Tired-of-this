//
//  BuxRootTheme.swift
//  BuxMuse
//
//  Root semantic brand theme — accent/tint for system UI, shared surfaces for custom UI.
//  Backgrounds stay on screenBackground + mesh; no feature/logic changes.
//

import SwiftUI

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
        BuxSemanticTheme(
            accent: themeManager.current.accentColor,
            labelPrimary: themeManager.labelPrimary(for: colorScheme),
            labelSecondary: themeManager.labelSecondary(for: colorScheme),
            labelTertiary: themeManager.labelTertiary(for: colorScheme),
            chevronMuted: themeManager.chevronMuted(for: colorScheme),
            cardFill: themeManager.cardFill(for: colorScheme),
            accentWash: themeManager.accentWash(for: colorScheme),
            chipMutedFill: themeManager.chipMutedFill(for: colorScheme)
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
    /// When true, `BuxCard` uses mesh-tinted chrome (app-wide; tab flags still apply for direct modifiers).
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
        content
            .tint(semantic.accent)
            .accentColor(semantic.accent)
            .environment(\.buxSemanticTheme, semantic)
            .environment(\.buxBrandSurfaces, settings.brandThemesEnabled)
    }
}

extension View {
    /// Apple-native tint + semantic labels + branded surfaces for custom components.
    func buxRootBrandTheme() -> some View {
        modifier(BuxRootBrandThemeModifier())
    }

    /// Sheets / covers: inherit brand tint + semantics (background unchanged).
    func buxThemedPresentation() -> some View {
        buxRootBrandTheme()
    }

    /// Full themed modal stack: tint + mesh backdrop behind content.
    func buxThemedSheetContent() -> some View {
        modifier(BuxThemedSheetContentModifier())
    }
}

// MARK: - Sheet mesh backdrop

private struct BuxThemedSheetContentModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager

    func body(content: Content) -> some View {
        content
            .buxThemedPresentation()
            .background {
                ZStack {
                    themeManager.screenBackground(for: colorScheme)
                    BuxHeroMeshBackground()
                }
                .ignoresSafeArea()
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
    /// Hides default Form/List chrome so screen + mesh background reads through native sheet material.
    func buxNativeFormAppearance() -> some View {
        scrollContentBackground(.hidden)
    }
}
