//
//  BuxContentChrome.swift
//  BuxMuse
//
//  Hero vs list card chrome — Apple Music hierarchy (visual only).
//

import SwiftUI

// MARK: - Hero plate (mesh + optional glass)

struct BuxHeroCardPlateBackground: View {
    @ObservedObject private var settings = SettingsStore.shared

    let cornerRadius: CGFloat

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        ZStack {
            BuxThemedCardPlateBackground(cornerRadius: cornerRadius)

            if settings.useGlassmorphism {
                if #available(iOS 26.0, *) {
                    shape
                        .fill(.clear)
                        .glassEffect(.regular, in: shape)
                }
            }
        }
    }
}

// MARK: - Modifiers

struct BuxHeroCardChromeModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @ObservedObject private var settings = SettingsStore.shared

    let cornerRadius: CGFloat
    var useMeshPlate: Bool = true

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let branded = settings.brandThemesEnabled
        let chrome = themeManager.cardChrome(
            for: .hero,
            colorScheme: colorScheme,
            branded: branded
        )

        content
            .background {
                if useMeshPlate && branded {
                    BuxHeroCardPlateBackground(cornerRadius: cornerRadius)
                } else {
                    shape.fill(themeManager.cardFill(for: colorScheme))
                }
            }
            .compositingGroup()
            .clipShape(shape)
            .overlay {
                if chrome.strokeWidth > 0 {
                    shape.stroke(chrome.stroke, lineWidth: chrome.strokeWidth)
                }
            }
            .shadow(color: chrome.shadowColor, radius: chrome.shadowRadius, x: 0, y: chrome.shadowY)
    }
}

struct BuxListCardChromeModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @ObservedObject private var settings = SettingsStore.shared

    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let branded = settings.brandThemesEnabled
        let chrome = themeManager.cardChrome(
            for: .card,
            colorScheme: colorScheme,
            branded: branded
        )

        content
            .background {
                if branded {
                    BuxThemedCardPlateBackground(cornerRadius: cornerRadius)
                } else {
                    shape.fill(themeManager.cardFill(for: colorScheme))
                }
            }
            .compositingGroup()
            .clipShape(shape)
            .overlay {
                if chrome.strokeWidth > 0 {
                    shape.stroke(chrome.stroke, lineWidth: chrome.strokeWidth)
                }
            }
    }
}

extension View {
    /// Hero card — soft lift shadow, optional glass when useGlassmorphism (one per screen).
    func buxHeroCardChrome(cornerRadius: CGFloat = BuxTokens.Radius.hero, useMeshPlate: Bool = true) -> some View {
        modifier(BuxHeroCardChromeModifier(cornerRadius: cornerRadius, useMeshPlate: useMeshPlate))
    }

    /// List / grid card — clean, stroke only, no shadow, never glass.
    func buxListCardChrome(cornerRadius: CGFloat = BuxTokens.Radius.card) -> some View {
        modifier(BuxListCardChromeModifier(cornerRadius: cornerRadius))
    }

    @ViewBuilder
    func buxCardChrome(tier: BuxCardChromeTier, cornerRadius: CGFloat) -> some View {
        switch tier {
        case .hero:
            buxHeroCardChrome(cornerRadius: cornerRadius)
        case .list:
            buxListCardChrome(cornerRadius: cornerRadius)
        }
    }
}
