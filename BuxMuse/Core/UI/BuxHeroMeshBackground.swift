//
//  BuxHeroMeshBackground.swift
//  BuxMuse
//
//  A high-performance, static MeshGradient background for Hero Cards.
//  Uses the current theme's 9-color mesh palette to create a lush, painted look.
//  Static grid points ensure 0 CPU overhead when idle.
//

import SwiftUI

/// Hero mesh backdrop — hidden when brand themes are off in Settings.
struct BuxThemedBackdrop: View {
    var opacity: Double = 1

    var body: some View {
        BuxHeroMeshBackground()
            .opacity(opacity)
    }
}

struct BuxHeroMeshBackground: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject private var settings = SettingsStore.shared

    // Static 3x3 grid points for zero-overhead rendering
    private let meshPoints: [SIMD2<Float>] = [
        [0.0, 0.0], [0.5, 0.0], [1.0, 0.0],
        [0.0, 0.5], [0.5, 0.5], [1.0, 0.5],
        [0.0, 1.0], [0.5, 1.0], [1.0, 1.0]
    ]

    var body: some View {
        if settings.brandThemesEnabled {
            meshGradient
        }
    }

    @ViewBuilder
    private var meshGradient: some View {
        let palette = colorScheme == .dark
            ? themeManager.current.meshDarkPalette
            : themeManager.current.meshLightPalette

        Group {
            if #available(iOS 18.0, *) {
                MeshGradient(
                    width: 3,
                    height: 3,
                    points: meshPoints,
                    colors: palette
                )
            } else {
                LinearGradient(
                    colors: [palette[0], palette[4], palette[8]],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        .mask {
            LinearGradient(
                colors: [.black, .black.opacity(0.8), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea(edges: .top)
    }
}
