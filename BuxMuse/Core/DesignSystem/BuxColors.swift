//
//  BuxColors.swift
//  BuxMuse Design System — semantic surfaces & labels.
//

import SwiftUI

enum BuxColors {
    static func labelPrimary(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? .white : Color(red: 26/255, green: 28/255, blue: 32/255)
    }

    static func labelSecondary(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.white.opacity(0.6) : Color(red: 100/255, green: 110/255, blue: 130/255)
    }

    static func labelTertiary(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.white.opacity(0.4) : Color(red: 140/255, green: 145/255, blue: 160/255)
    }

    static func accentWash(_ accent: Color, colorScheme: ColorScheme) -> Color {
        accent.opacity(colorScheme == .dark ? 0.24 : 0.14)
    }
}

extension ThemeManager {
    func labelPrimary(for colorScheme: ColorScheme) -> Color {
        BuxColors.labelPrimary(colorScheme)
    }

    func labelSecondary(for colorScheme: ColorScheme) -> Color {
        BuxColors.labelSecondary(colorScheme)
    }

    func accentWash(for colorScheme: ColorScheme) -> Color {
        BuxColors.accentWash(current.accentColor, colorScheme: colorScheme)
    }
}

extension View {
    /// Apple Music pop: card = hairline only; hero = soft shadow. Never animates shadow in lists.
    func buxSurface(
        elevation: BuxElevation,
        themeManager: ThemeManager,
        colorScheme: ColorScheme,
        cornerRadius: CGFloat = BuxTokens.Radius.card
    ) -> some View {
        modifier(BuxSurfaceModifier(
            elevation: elevation,
            themeManager: themeManager,
            colorScheme: colorScheme,
            cornerRadius: cornerRadius
        ))
    }
}

private struct BuxSurfaceModifier: ViewModifier {
    let elevation: BuxElevation
    let themeManager: ThemeManager
    let colorScheme: ColorScheme
    let cornerRadius: CGFloat
    @Environment(\.buxBrandSurfaces) private var buxBrandSurfaces

    private var chrome: BuxCardChromeMetrics {
        themeManager.cardChrome(for: elevation, colorScheme: colorScheme, branded: buxBrandSurfaces)
    }

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(themeManager.cardFill(for: colorScheme))
            )
            .overlay {
                if chrome.strokeWidth > 0 {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(chrome.stroke, lineWidth: chrome.strokeWidth)
                }
            }
            .shadow(
                color: chrome.shadowColor,
                radius: chrome.shadowRadius,
                x: 0,
                y: chrome.shadowY
            )
    }
}
