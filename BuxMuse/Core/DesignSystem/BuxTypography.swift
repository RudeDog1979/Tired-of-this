//
//  BuxTypography.swift
//  BuxMuse Design System
//

import SwiftUI

enum BuxTypography {
    static func moneyHero(_ text: String) -> Text {
        Text(text).font(.system(size: 34, weight: .semibold, design: .rounded).monospacedDigit())
    }

    static func moneyTitle(_ text: String) -> Text {
        Text(text).font(.system(size: 22, weight: .semibold, design: .rounded).monospacedDigit())
    }

    static func titleLarge(_ text: String) -> Text {
        Text(text).font(.system(size: 28, weight: .bold))
    }

    static func title(_ text: String) -> Text {
        Text(text).font(.system(size: 17, weight: .bold))
    }

    static func headline(_ text: String) -> Text {
        Text(text).font(.system(size: 15, weight: .semibold))
    }

    static func body(_ text: String) -> Text {
        Text(text).font(.system(size: 15, weight: .regular))
    }

    static func callout(_ text: String) -> Text {
        Text(text).font(.system(size: 14, weight: .regular))
    }

    static func caption(_ text: String) -> Text {
        Text(text).font(.system(size: 13, weight: .medium))
    }

    static func sectionLabel(_ text: String) -> Text {
        Text(text).font(.footnote.weight(.semibold))
    }

    static var buttonFont: Font {
        .system(size: 16, weight: .semibold)
    }

    static var buttonFontCompact: Font {
        .system(size: 15, weight: .semibold)
    }
}

extension View {
    /// M3 Body Medium — supporting card text (semantic secondary).
    func buxMaterialBodyMedium() -> some View {
        modifier(BuxMaterialTextStyle(role: .secondary, font: .system(size: 14, weight: .regular)))
    }

    /// M3 Label Medium — captions under controls (semantic tertiary).
    func buxMaterialLabelMedium() -> some View {
        modifier(BuxMaterialTextStyle(role: .tertiary, font: .system(size: 12, weight: .medium)))
    }

    /// M3 Title Medium — card titles (semantic primary).
    func buxMaterialTitleMedium() -> some View {
        modifier(BuxMaterialTextStyle(role: .primary, font: .system(size: 16, weight: .medium)))
    }

    /// M3 Title Large — section headers (semantic primary).
    func buxMaterialTitleLarge() -> some View {
        modifier(BuxMaterialTextStyle(role: .primary, font: .system(size: 22, weight: .regular)))
    }

    /// M3 Display Small — hero numerics (keeps Bux rounded money feel).
    func buxMaterialDisplaySmall() -> some View {
        font(.system(size: 36, weight: .semibold, design: .rounded))
    }

    func buxSectionLabelStyle(color: Color) -> some View {
        buxMaterialLabelMedium()
            .foregroundStyle(color)
    }

    func buxTitleStyle(color: Color) -> some View {
        font(.system(size: 17, weight: .bold))
            .foregroundStyle(color)
    }

    func buxHeadlineStyle(color: Color) -> some View {
        font(.system(size: 15, weight: .semibold))
            .foregroundStyle(color)
    }

    func buxBodyStyle(color: Color) -> some View {
        font(.system(size: 15, weight: .regular))
            .foregroundStyle(color)
    }

    func buxCaptionStyle(color: Color) -> some View {
        font(.system(size: 13, weight: .medium))
            .foregroundStyle(color)
    }
}

private enum BuxMaterialTextRole {
    case primary, secondary, tertiary
}

private struct BuxMaterialTextStyle: ViewModifier {
    let role: BuxMaterialTextRole
    let font: Font
    @Environment(\.buxSemanticTheme) private var theme

    func body(content: Content) -> some View {
        content
            .font(font)
            .foregroundStyle(color)
    }

    private var color: Color {
        switch role {
        case .primary: return theme.labelPrimary
        case .secondary: return theme.labelSecondary
        case .tertiary: return theme.labelTertiary
        }
    }
}
