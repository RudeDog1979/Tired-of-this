//
//  BuxGlassChrome.swift
//  BuxMuse
//
//  Layer-3 Liquid Glass / material chrome (tab pill, icon circles). iOS 26 + fallback.
//

import SwiftUI

// MARK: - Glass circle (icon buttons)

struct BuxGlassCircleBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @ObservedObject private var settings = SettingsStore.shared

    var diameter: CGFloat = 44

    var body: some View {
        let shape = Circle()
        Group {
            if settings.useGlassmorphism {
                if #available(iOS 26.0, *) {
                    shape
                        .fill(.clear)
                        .frame(width: diameter, height: diameter)
                        .glassEffect(.regular, in: shape)
                } else {
                    shape
                        .fill(.ultraThinMaterial)
                        .frame(width: diameter, height: diameter)
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
            if settings.useGlassmorphism {
                if #available(iOS 26.0, *) {
                    GlassEffectContainer {
                        shape
                            .fill(.clear)
                            .glassEffect(.regular, in: shape)
                    }
                } else {
                    shape.fill(.ultraThinMaterial)
                }
            } else {
                shape.fill(themeManager.cardFill(for: colorScheme))
            }
        }
    }
}
