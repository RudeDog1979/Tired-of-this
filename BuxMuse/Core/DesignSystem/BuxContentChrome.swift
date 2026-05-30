//
//  BuxContentChrome.swift
//  BuxMuse
//
//  Hero vs list card chrome — M3 material surfaces (visual only).
//

import SwiftUI

// MARK: - Hero plate (opaque M3 surface)

struct BuxHeroCardPlateBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    let cornerRadius: CGFloat

    var body: some View {
        BuxThemedCardPlateBackground(cornerRadius: cornerRadius)
    }
}

// MARK: - Modifiers

struct BuxHeroCardChromeModifier: ViewModifier {
    let cornerRadius: CGFloat
    var useMeshPlate: Bool = true

    func body(content: Content) -> some View {
        content.buxMaterialCardChrome(.elevated, cornerRadius: cornerRadius)
    }
}

struct BuxListCardChromeModifier: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content.buxMaterialCardChrome(.outlined, cornerRadius: cornerRadius)
    }
}

extension View {
    /// Hero card — M3 Elevated (one per screen).
    func buxHeroCardChrome(cornerRadius: CGFloat = BuxTokens.Radius.hero, useMeshPlate: Bool = true) -> some View {
        modifier(BuxHeroCardChromeModifier(cornerRadius: cornerRadius, useMeshPlate: useMeshPlate))
    }

    /// List / grid card — M3 Outlined.
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
