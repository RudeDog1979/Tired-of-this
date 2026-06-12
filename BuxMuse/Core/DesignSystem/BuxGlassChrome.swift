//
//  BuxGlassChrome.swift
//  BuxMuse
//
//  Layer-3 Liquid Glass / material chrome (tab pill, icon circles). iOS 26 + fallback.
//

import SwiftUI

// MARK: - Shared rim shimmer (Safari-style, light + dark)

enum BuxGlassRimMetrics {
    static func rimStrokeOpacity(for colorScheme: ColorScheme) -> Double {
        colorScheme == .dark ? 0.14 : 0.38
    }

    static func shadowColor(for colorScheme: ColorScheme) -> Color {
        .black.opacity(colorScheme == .dark ? 0.22 : 0.07)
    }

    static let shadowRadius: CGFloat = 10
    static let shadowY: CGFloat = 4
}

extension View {
    /// Top-leading rim highlight + soft drop shadow for material glass shapes.
    func buxGlassRimShimmer<S: InsettableShape>(shape: S, colorScheme: ColorScheme, enabled: Bool) -> some View {
        modifier(BuxGlassRimShimmerModifier(shape: shape, colorScheme: colorScheme, enabled: enabled))
    }

    /// Forces dynamic materials to appear dark when the environment colorScheme is dark,
    /// by overlaying a semi-translucent dark color. This compensates for UIKit trait collection
    /// propagation issues in nested iPad split/sidebar controllers.
    @ViewBuilder
    func buxMaterialColorSchemeAdaptive<S: Shape>(shape: S, colorScheme: ColorScheme) -> some View {
        self
    }
}

private struct BuxGlassRimShimmerModifier<S: InsettableShape>: ViewModifier {
    @Environment(\.buxPadFlatDashboardChrome) private var padFlatChrome

    let shape: S
    let colorScheme: ColorScheme
    let enabled: Bool

    func body(content: Content) -> some View {
        let shadowOn = enabled && !padFlatChrome
        content
            .overlay {
                if enabled {
                    shape.strokeBorder(
                        Color.white.opacity(BuxGlassRimMetrics.rimStrokeOpacity(for: colorScheme)),
                        lineWidth: 0.5
                    )
                }
            }
            .shadow(
                color: shadowOn ? BuxGlassRimMetrics.shadowColor(for: colorScheme) : .clear,
                radius: shadowOn ? BuxGlassRimMetrics.shadowRadius : 0,
                y: shadowOn ? BuxGlassRimMetrics.shadowY : 0
            )
    }
}

// MARK: - Glass circle (icon buttons)

struct BuxGlassCircleBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @ObservedObject private var settings = SettingsStore.shared

    var diameter: CGFloat = 44

    var body: some View {
        let shape = Circle()
        Group {
            if settings.solarContrastModeEnabled {
                shape
                    .fill(Color.white)
                    .frame(width: diameter, height: diameter)
                    .overlay(shape.stroke(Color.black, lineWidth: 2.0))
            } else if settings.useGlassmorphism {
                if #available(iOS 26.0, *) {
                    GlassEffectContainer {
                        shape
                            .fill(.clear)
                            .frame(width: diameter, height: diameter)
                            .glassEffect(.regular, in: shape)
                    }
                } else {
                    shape
                        .fill(.ultraThinMaterial)
                        .frame(width: diameter, height: diameter)
                        .buxMaterialColorSchemeAdaptive(shape: shape, colorScheme: colorScheme)
                }
            } else {
                shape
                    .fill(themeManager.cardFill(for: colorScheme))
                    .frame(width: diameter, height: diameter)
                    .overlay(
                        shape.stroke(
                            themeManager.subtleCardStroke(for: colorScheme),
                            lineWidth: 1
                        )
                    )
            }
        }
        .buxGlassRimShimmer(
            shape: shape,
            colorScheme: colorScheme,
            enabled: settings.useGlassmorphism && !settings.solarContrastModeEnabled
        )
    }
}

// MARK: - Glass capsule (section menus, category pill track)

struct BuxGlassCapsuleBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @ObservedObject private var settings = SettingsStore.shared
    var castsShadow: Bool = true

    var body: some View {
        let shape = Capsule(style: .continuous)
        let accent = themeManager.current.accentColor
        let isDark = colorScheme == .dark

        return Group {
            if settings.solarContrastModeEnabled {
                shape
                    .fill(Color.white)
                    .overlay(shape.stroke(Color.black, lineWidth: 2.0))
            } else if settings.useGlassmorphism {
                if #available(iOS 26.0, *) {
                    GlassEffectContainer {
                        shape
                            .fill(.clear)
                            .glassEffect(.regular, in: shape)
                    }
                } else {
                    shape.fill(.ultraThinMaterial)
                        .buxMaterialColorSchemeAdaptive(shape: shape, colorScheme: colorScheme)
                }
            } else {
                shape.fill(themeManager.pillTrackFill(for: colorScheme))
            }
        }
        .buxGlassRimShimmer(
            shape: shape,
            colorScheme: colorScheme,
            enabled: settings.useGlassmorphism && castsShadow && !settings.solarContrastModeEnabled
        )
        .overlay {
            if settings.useGlassmorphism && settings.showsLandingCardShine && !settings.solarContrastModeEnabled {
                shape.strokeBorder(
                    LinearGradient(
                        colors: [
                            accent.opacity(isDark ? 0.22 : 0.14),
                            accent.opacity(isDark ? 0.09 : 0.06),
                            accent.opacity(isDark ? 0.03 : 0.02),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.75
                )
            }
        }
    }
}

// MARK: - Glass pill (tab bar)

struct BuxGlassPillBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @ObservedObject private var settings = SettingsStore.shared

    var cornerRadius: CGFloat

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        Group {
            if settings.solarContrastModeEnabled {
                shape
                    .fill(Color.white)
                    .overlay(shape.stroke(Color.black, lineWidth: 2.0))
            } else if settings.useGlassmorphism {
                if #available(iOS 26.0, *) {
                    GlassEffectContainer {
                        shape
                            .fill(.clear)
                            .glassEffect(.regular, in: shape)
                    }
                } else {
                    shape.fill(.ultraThinMaterial)
                        .buxMaterialColorSchemeAdaptive(shape: shape, colorScheme: colorScheme)
                }
            } else {
                shape.fill(themeManager.cardFill(for: colorScheme))
            }
        }
    }
}
