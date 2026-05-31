//
//  BuxMaterialChrome.swift
//  BuxMuse Design System
//
//  Material Design 3 shapes + card chrome — app-wide.
//

import SwiftUI

// MARK: - M3 shape scale (m3.material.io)

enum BuxMaterialShape {
    static let none: CGFloat = 0
    static let extraSmall: CGFloat = 4
    static let small: CGFloat = 8
    static let medium: CGFloat = 12
    static let large: CGFloat = 16
    static let extraLarge: CGFloat = 28
    static let full: CGFloat = 9999
}

// MARK: - Card variants

enum BuxMaterialCardVariant {
    /// M3 Outlined — surface fill on canvas, outline-variant border.
    case outlined
    /// M3 Elevated — surface-container-lowest + level-1 shadow.
    case elevated
    /// M3 Filled — surface-container-highest, no border.
    case filled
}

enum BuxMaterialChrome {
    static let cardCornerRadius = BuxMaterialShape.medium
    static let fieldCornerRadius = BuxMaterialShape.small
    static let chipCornerRadius = BuxMaterialShape.extraSmall
    static let heroCornerRadius = BuxMaterialShape.medium

    static let elevatedShadowRadius: CGFloat = 6
    static let elevatedShadowY: CGFloat = 3

    static func elevatedShadowColor(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.black.opacity(0.40) : Color.black.opacity(0.06)
    }
}

// MARK: - Modifier

struct BuxMaterialCardChromeModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @ObservedObject private var settings = SettingsStore.shared

    let variant: BuxMaterialCardVariant
    let cornerRadius: CGFloat
    var castsShadow: Bool = true

    private var scheme: BuxMaterialScheme {
        themeManager.materialScheme(for: colorScheme, branded: settings.brandThemesEnabled)
    }

    private var fillColor: Color {
        switch variant {
        case .outlined:
            return scheme.surface
        case .elevated:
            return scheme.surfaceContainerLowest
        case .filled:
            return scheme.surfaceContainerHighest
        }
    }

    private var showsBorder: Bool {
        variant != .filled
    }

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        content
            .background {
                shape.fill(fillColor)
            }
            .modifier(BuxMaterialClipGroupModifier(useGroup: variant == .elevated))
            .clipShape(shape)
            .overlay {
                if showsBorder {
                    shape.stroke(scheme.outlineVariant, lineWidth: 0.5)
                }
            }
            .shadow(
                color: variant == .elevated && castsShadow
                    ? BuxMaterialChrome.elevatedShadowColor(for: colorScheme)
                    : .clear,
                radius: variant == .elevated && castsShadow ? BuxMaterialChrome.elevatedShadowRadius : 0,
                x: 0,
                y: variant == .elevated && castsShadow ? BuxMaterialChrome.elevatedShadowY : 0
            )
    }
}

/// Offscreen group only where elevation shadow needs it — keeps list scroll cheap.
private struct BuxMaterialClipGroupModifier: ViewModifier {
    let useGroup: Bool

    func body(content: Content) -> some View {
        if useGroup {
            content.compositingGroup()
        } else {
            content
        }
    }
}

// MARK: - View API

extension View {
    func buxMaterialCardChrome(
        _ variant: BuxMaterialCardVariant = .outlined,
        cornerRadius: CGFloat = BuxMaterialChrome.cardCornerRadius,
        castsShadow: Bool = true
    ) -> some View {
        modifier(BuxMaterialCardChromeModifier(variant: variant, cornerRadius: cornerRadius, castsShadow: castsShadow))
    }

    func buxMaterialPillCardLabel(
        cornerRadius: CGFloat = BuxMaterialChrome.cardCornerRadius
    ) -> some View {
        frame(maxWidth: .infinity, minHeight: BuxLayout.dashboardSmallCardHeight, alignment: .top)
            .buxMaterialCardChrome(.outlined, cornerRadius: cornerRadius)
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    func buxMaterialPillAuxCardLabel(
        cornerRadius: CGFloat = BuxMaterialChrome.cardCornerRadius
    ) -> some View {
        frame(maxWidth: .infinity, alignment: .leading)
            .buxMaterialCardChrome(.outlined, cornerRadius: cornerRadius)
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    func buxMaterialCanvasBackground(themeManager: ThemeManager, colorScheme: ColorScheme) -> some View {
        themeManager.screenBackground(for: colorScheme)
            .ignoresSafeArea()
    }
}
