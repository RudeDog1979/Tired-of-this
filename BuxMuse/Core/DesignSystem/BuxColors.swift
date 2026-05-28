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

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(themeManager.cardFill(for: colorScheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(strokeColor, lineWidth: strokeWidth)
            )
            .shadow(
                color: shadowColor,
                radius: shadowRadius,
                x: 0,
                y: shadowY
            )
    }

    private var strokeColor: Color {
        switch elevation {
        case .flat:
            return .clear
        case .card, .hero:
            return themeManager.subtleCardStroke(for: colorScheme)
        }
    }

    private var strokeWidth: CGFloat {
        elevation == .flat ? 0 : 1
    }

    private var shadowColor: Color {
        guard elevation == .hero else { return .clear }
        let opacity = colorScheme == .dark
            ? BuxTokens.Shadow.heroColorOpacityDark
            : BuxTokens.Shadow.heroColorOpacityLight
        return Color.black.opacity(opacity)
    }

    private var shadowRadius: CGFloat {
        elevation == .hero ? BuxTokens.Shadow.heroRadius : 0
    }

    private var shadowY: CGFloat {
        elevation == .hero ? BuxTokens.Shadow.heroY : 0
    }
}
