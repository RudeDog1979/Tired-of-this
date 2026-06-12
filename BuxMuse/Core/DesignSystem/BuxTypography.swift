//
//  BuxTypography.swift
//  BuxMuse Design System
//

import SwiftUI

enum BuxTypography {
    static func moneyHero(_ text: String) -> Text {
        return Text(text).font(.system(size: 34, weight: .bold, design: .rounded).monospacedDigit())
    }

    static func moneyTitle(_ text: String) -> Text {
        return Text(text).font(.system(size: 22, weight: .bold, design: .rounded).monospacedDigit())
    }

    static func titleLarge(_ text: String) -> Text {
        Text(text).font(.system(size: 28, weight: .bold))
    }

    static func title(_ text: String) -> Text {
        Text(text).font(.system(size: 17, weight: .bold))
    }

    static func headline(_ text: String) -> Text {
        Text(text).font(.system(size: 15, weight: .bold))
    }

    static func body(_ text: String) -> Text {
        let isSolar = SettingsStore.shared.solarContrastModeEnabled
        return Text(text).font(.system(size: 15, weight: isSolar ? .bold : .regular))
    }

    static func callout(_ text: String) -> Text {
        let isSolar = SettingsStore.shared.solarContrastModeEnabled
        return Text(text).font(.system(size: 14, weight: isSolar ? .bold : .regular))
    }

    static func caption(_ text: String) -> Text {
        let isSolar = SettingsStore.shared.solarContrastModeEnabled
        return Text(text).font(.system(size: 13, weight: isSolar ? .bold : .medium))
    }

    static func sectionLabel(_ text: String) -> Text {
        let isSolar = SettingsStore.shared.solarContrastModeEnabled
        return Text(text).font(.footnote.weight(isSolar ? .bold : .semibold))
    }

    static var buttonFont: Font {
        let isSolar = SettingsStore.shared.solarContrastModeEnabled
        return .system(size: 16, weight: isSolar ? .bold : .semibold)
    }

    static var buttonFontCompact: Font {
        let isSolar = SettingsStore.shared.solarContrastModeEnabled
        return .system(size: 15, weight: isSolar ? .bold : .semibold)
    }
}

extension View {
    /// M3 Body Medium — supporting card text (semantic secondary).
    func buxMaterialBodyMedium() -> some View {
        let isSolar = SettingsStore.shared.solarContrastModeEnabled
        return modifier(BuxMaterialTextStyle(role: .secondary, font: .system(size: 14, weight: isSolar ? .bold : .regular)))
    }

    /// M3 Label Medium — captions under controls (semantic tertiary).
    func buxMaterialLabelMedium() -> some View {
        let isSolar = SettingsStore.shared.solarContrastModeEnabled
        return modifier(BuxMaterialTextStyle(role: .tertiary, font: .system(size: 12, weight: isSolar ? .semibold : .medium)))
    }

    /// M3 Title Medium — card titles (semantic primary).
    func buxMaterialTitleMedium() -> some View {
        let isSolar = SettingsStore.shared.solarContrastModeEnabled
        return modifier(BuxMaterialTextStyle(role: .primary, font: .system(size: 16, weight: isSolar ? .bold : .medium)))
    }

    /// M3 Title Large — section headers (semantic primary).
    func buxMaterialTitleLarge() -> some View {
        let isSolar = SettingsStore.shared.solarContrastModeEnabled
        return modifier(BuxMaterialTextStyle(role: .primary, font: .system(size: 22, weight: isSolar ? .bold : .regular)))
    }

    /// M3 Display Small — hero numerics (keeps Bux rounded money feel).
    func buxMaterialDisplaySmall() -> some View {
        let isSolar = SettingsStore.shared.solarContrastModeEnabled
        return font(.system(size: 36, weight: isSolar ? .bold : .semibold, design: .rounded))
    }

    func buxSectionLabelStyle(color: Color) -> some View {
        let isSolar = SettingsStore.shared.solarContrastModeEnabled
        return buxMaterialLabelMedium()
            .foregroundStyle(isSolar ? .black : color)
    }

    func buxTitleStyle(color: Color) -> some View {
        let isSolar = SettingsStore.shared.solarContrastModeEnabled
        return font(.system(size: 17, weight: .bold))
            .foregroundStyle(isSolar ? .black : color)
    }

    func buxHeadlineStyle(color: Color) -> some View {
        let isSolar = SettingsStore.shared.solarContrastModeEnabled
        return font(.system(size: 15, weight: .bold))
            .foregroundStyle(isSolar ? .black : color)
    }

    func buxBodyStyle(color: Color) -> some View {
        let isSolar = SettingsStore.shared.solarContrastModeEnabled
        return font(.system(size: 15, weight: isSolar ? .bold : .regular))
            .foregroundStyle(isSolar ? .black : color)
    }

    func buxCaptionStyle(color: Color) -> some View {
        let isSolar = SettingsStore.shared.solarContrastModeEnabled
        return font(.system(size: 13, weight: isSolar ? .bold : .medium))
            .foregroundStyle(isSolar ? .black : color)
    }
}

private enum BuxMaterialTextRole {
    case primary, secondary, tertiary
}

private struct BuxMaterialTextStyle: ViewModifier {
    let role: BuxMaterialTextRole
    let font: Font
    @Environment(\.buxSemanticTheme) private var theme
    @ObservedObject private var settings = SettingsStore.shared

    func body(content: Content) -> some View {
        content
            .font(font)
            .foregroundStyle(color)
    }

    private var color: Color {
        if settings.solarContrastModeEnabled {
            return .black
        }
        switch role {
        case .primary: return theme.labelPrimary
        case .secondary: return theme.labelSecondary
        case .tertiary: return theme.labelTertiary
        }
    }
}
