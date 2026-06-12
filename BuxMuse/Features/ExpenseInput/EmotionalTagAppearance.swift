//
//  EmotionalTagAppearance.swift
//  BuxMuse
//
//  Visual palette for emotional tags — gradients and chip styling.
//

import SwiftUI

enum EmotionalTagAppearance {
    struct Palette {
        let accent: Color
        let gradientTop: Color
        let gradientMid: Color
        let gradientBottom: Color
        let glow: Color
    }

    static func palette(for tagId: String, colorScheme: ColorScheme) -> Palette? {
        guard !tagId.isEmpty else { return nil }
        let dark = colorScheme == .dark
        switch tagId {
        case "joy":
            return Palette(
                accent: Color(red: 52/255, green: 199/255, blue: 89/255),
                gradientTop: dark ? Color(red: 34/255, green: 120/255, blue: 58/255) : Color(red: 168/255, green: 230/255, blue: 190/255),
                gradientMid: dark ? Color(red: 22/255, green: 78/255, blue: 44/255) : Color(red: 212/255, green: 245/255, blue: 228/255),
                gradientBottom: .clear,
                glow: Color(red: 52/255, green: 199/255, blue: 89/255)
            )
        case "excited":
            return Palette(
                accent: Color(red: 255/255, green: 159/255, blue: 10/255),
                gradientTop: dark ? Color(red: 180/255, green: 100/255, blue: 20/255) : Color(red: 255/255, green: 216/255, blue: 155/255),
                gradientMid: dark ? Color(red: 120/255, green: 70/255, blue: 10/255) : Color(red: 255/255, green: 234/255, blue: 167/255),
                gradientBottom: .clear,
                glow: Color(red: 255/255, green: 179/255, blue: 64/255)
            )
        case "calm":
            return Palette(
                accent: Color(red: 90/255, green: 200/255, blue: 250/255),
                gradientTop: dark ? Color(red: 30/255, green: 100/255, blue: 130/255) : Color(red: 168/255, green: 216/255, blue: 234/255),
                gradientMid: dark ? Color(red: 20/255, green: 65/255, blue: 90/255) : Color(red: 201/255, green: 228/255, blue: 246/255),
                gradientBottom: .clear,
                glow: Color(red: 90/255, green: 200/255, blue: 250/255)
            )
        case "neutral":
            return Palette(
                accent: Color(red: 142/255, green: 142/255, blue: 147/255),
                gradientTop: dark ? Color(red: 55/255, green: 58/255, blue: 64/255) : Color(red: 232/255, green: 236/255, blue: 240/255),
                gradientMid: dark ? Color(red: 35/255, green: 38/255, blue: 42/255) : Color(red: 245/255, green: 247/255, blue: 250/255),
                gradientBottom: .clear,
                glow: Color(red: 142/255, green: 142/255, blue: 147/255)
            )
        case "stress":
            return Palette(
                accent: Color(red: 255/255, green: 149/255, blue: 0/255),
                gradientTop: dark ? Color(red: 160/255, green: 80/255, blue: 20/255) : Color(red: 255/255, green: 171/255, blue: 145/255),
                gradientMid: dark ? Color(red: 100/255, green: 50/255, blue: 10/255) : Color(red: 255/255, green: 204/255, blue: 188/255),
                gradientBottom: .clear,
                glow: Color(red: 255/255, green: 149/255, blue: 0/255)
            )
        case "regret":
            return Palette(
                accent: Color(red: 255/255, green: 69/255, blue: 58/255),
                gradientTop: dark ? Color(red: 140/255, green: 35/255, blue: 35/255) : Color(red: 255/255, green: 138/255, blue: 128/255),
                gradientMid: dark ? Color(red: 90/255, green: 22/255, blue: 22/255) : Color(red: 255/255, green: 205/255, blue: 210/255),
                gradientBottom: .clear,
                glow: Color(red: 255/255, green: 69/255, blue: 58/255)
            )
        case "guilty":
            return Palette(
                accent: Color(red: 175/255, green: 82/255, blue: 222/255),
                gradientTop: dark ? Color(red: 90/255, green: 45/255, blue: 120/255) : Color(red: 206/255, green: 147/255, blue: 216/255),
                gradientMid: dark ? Color(red: 55/255, green: 28/255, blue: 75/255) : Color(red: 225/255, green: 190/255, blue: 231/255),
                gradientBottom: .clear,
                glow: Color(red: 175/255, green: 82/255, blue: 222/255)
            )
        default:
            return nil
        }
    }

    @ViewBuilder
    static func background(for tagId: String, colorScheme: ColorScheme) -> some View {
        if let palette = palette(for: tagId, colorScheme: colorScheme) {
            gradientLayers(palette: palette, colorScheme: colorScheme, intensity: .sheet)
        }
    }

    enum GradientIntensity {
        case sheet
        case card

        func topOpacity(dark: Bool) -> Double {
            switch self {
            case .sheet: return dark ? 0.72 : 0.55
            case .card: return dark ? 0.58 : 0.44
            }
        }

        func midOpacity(dark: Bool) -> Double {
            switch self {
            case .sheet: return dark ? 0.38 : 0.28
            case .card: return dark ? 0.32 : 0.22
            }
        }

        func glowOpacity(dark: Bool) -> Double {
            switch self {
            case .sheet: return dark ? 0.35 : 0.22
            case .card: return dark ? 0.28 : 0.18
            }
        }

        var radialEndRadius: CGFloat {
            switch self {
            case .sheet: return 420
            case .card: return 220
            }
        }
    }

    @ViewBuilder
    private static func gradientLayers(
        palette: Palette,
        colorScheme: ColorScheme,
        intensity: GradientIntensity
    ) -> some View {
        let dark = colorScheme == .dark
        ZStack {
            LinearGradient(
                colors: [
                    palette.gradientTop.opacity(intensity.topOpacity(dark: dark)),
                    palette.gradientMid.opacity(intensity.midOpacity(dark: dark)),
                    palette.gradientBottom
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    palette.glow.opacity(intensity.glowOpacity(dark: dark)),
                    palette.glow.opacity(0.08),
                    .clear
                ],
                center: .topLeading,
                startRadius: 20,
                endRadius: intensity.radialEndRadius
            )
        }
    }

    static func resolvedTagId(_ tagId: String?) -> String {
        tagId?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
    }

    static func accent(for tagId: String?, colorScheme: ColorScheme) -> Color? {
        palette(for: resolvedTagId(tagId), colorScheme: colorScheme)?.accent
    }

    static func cardStroke(for tagId: String?, colorScheme: ColorScheme, fallback: Color) -> Color {
        guard let accent = accent(for: tagId, colorScheme: colorScheme) else { return fallback }
        return accent.opacity(colorScheme == .dark ? 0.42 : 0.32)
    }

    @ViewBuilder
    static func cardBackground(
        tagId: String?,
        colorScheme: ColorScheme,
        base: Color,
        cornerRadius: CGFloat,
        tintOpacity: Double = 1
    ) -> some View {
        let resolved = resolvedTagId(tagId)
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        shape
            .fill(base)
            .overlay {
                if let palette = palette(for: resolved, colorScheme: colorScheme) {
                    ZStack {
                        gradientLayers(palette: palette, colorScheme: colorScheme, intensity: .card)
                        shape.fill(base.opacity(colorScheme == .dark ? 0.42 : 0.55))
                    }
                    .opacity(tintOpacity)
                    .clipShape(shape)
                }
            }
    }

    enum WatermarkScale {
        case listCard
        case detailCard

        var iconSize: CGFloat {
            switch self {
            case .listCard: return 52
            case .detailCard: return 88
            }
        }

        var labelSize: CGFloat {
            switch self {
            case .listCard: return 20
            case .detailCard: return 34
            }
        }

        func iconOpacity(dark: Bool) -> Double {
            switch self {
            case .listCard: return dark ? 0.14 : 0.10
            case .detailCard: return dark ? 0.16 : 0.11
            }
        }

        func labelOpacity(dark: Bool) -> Double {
            switch self {
            case .listCard: return dark ? 0.09 : 0.06
            case .detailCard: return dark ? 0.10 : 0.07
            }
        }
    }

    @ViewBuilder
    static func watermark(
        tag: EmotionalTag,
        colorScheme: ColorScheme,
        locale: Locale = BuxInterfaceLocale.currentInterfaceLocale,
        scale: WatermarkScale = .listCard,
        opacity: Double = 1,
        includeLabel: Bool = false
    ) -> some View {
        let accent = palette(for: tag.id, colorScheme: colorScheme)?.accent ?? .gray
        let dark = colorScheme == .dark

        Group {
            if includeLabel {
                ZStack(alignment: .bottomTrailing) {
                    Text(tag.localizedLabel(locale: locale))
                        .font(.system(size: scale.labelSize, weight: .semibold, design: .rounded))
                        .foregroundColor(accent.opacity(scale.labelOpacity(dark: dark)))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .padding(.trailing, 12)
                        .padding(.bottom, 6)

                    Image(systemName: tag.symbol)
                        .font(.system(size: scale.iconSize, weight: .semibold))
                        .foregroundColor(accent.opacity(scale.iconOpacity(dark: dark)))
                        .offset(x: 6, y: 10)
                }
            } else {
                Image(systemName: tag.symbol)
                    .font(.system(size: scale.iconSize, weight: .semibold))
                    .foregroundColor(accent.opacity(scale.iconOpacity(dark: dark)))
                    .padding(8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        .opacity(opacity)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
