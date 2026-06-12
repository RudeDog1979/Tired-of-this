//
//  CardTextEffects.swift
//  BuxMuse
//

import SwiftUI

struct CardTextEffectsModifier: ViewModifier {
    let preset: CardTextEffectPreset
    let color: Color

    func body(content: Content) -> some View {
        switch preset {
        case .none:
            content
        case .longShadow:
            content
                .shadow(color: color.opacity(0.35), radius: 0, x: 4, y: 4)
                .shadow(color: color.opacity(0.2), radius: 0, x: 8, y: 8)
        case .emboss:
            content
                .shadow(color: .white.opacity(0.85), radius: 0, x: -1, y: -1)
                .shadow(color: .black.opacity(0.35), radius: 0, x: 1, y: 1)
        case .outline:
            content.shadow(color: color, radius: 0, x: -1, y: 0)
                .shadow(color: color, radius: 0, x: 1, y: 0)
                .shadow(color: color, radius: 0, x: 0, y: -1)
                .shadow(color: color, radius: 0, x: 0, y: 1)
        case .neon:
            content
                .shadow(color: color.opacity(0.9), radius: 2, x: 0, y: 0)
                .shadow(color: color.opacity(0.6), radius: 8, x: 0, y: 0)
                .shadow(color: color.opacity(0.35), radius: 16, x: 0, y: 0)
        case .letterpress:
            content.shadow(color: .black.opacity(0.25), radius: 0, x: 0, y: 1)
        case .retro3D:
            content
                .shadow(color: color.opacity(0.5), radius: 0, x: 2, y: 2)
                .shadow(color: color.opacity(0.35), radius: 0, x: 4, y: 4)
                .shadow(color: color.opacity(0.2), radius: 0, x: 6, y: 6)
        case .glow:
            content.shadow(color: color.opacity(0.55), radius: 10, x: 0, y: 0)
        case .stack:
            content
                .shadow(color: .black.opacity(0.15), radius: 0, x: 0, y: 2)
                .shadow(color: .black.opacity(0.1), radius: 0, x: 0, y: 4)
        case .classic:
            content.shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
        }
    }
}

extension View {
    func cardTextEffect(_ preset: CardTextEffectPreset, color: Color) -> some View {
        modifier(CardTextEffectsModifier(preset: preset, color: color))
    }
}
