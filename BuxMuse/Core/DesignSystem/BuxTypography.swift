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
        Text(text.uppercased())
            .font(.system(size: 11, weight: .bold))
            .kerning(1.2)
    }

    static var buttonFont: Font {
        .system(size: 16, weight: .semibold)
    }

    static var buttonFontCompact: Font {
        .system(size: 15, weight: .semibold)
    }
}

extension View {
    func buxSectionLabelStyle(color: Color) -> some View {
        font(.system(size: 11, weight: .bold))
            .kerning(1.2)
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
