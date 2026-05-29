//
//  BuxFormScaffold.swift
//  BuxMuse
//
//  Themed Form/List chrome — mesh backdrop + row plates (visual only).
//

import SwiftUI

// MARK: - Form row plate (listRowBackground)

struct BuxFormRowPlate: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @ObservedObject private var settings = SettingsStore.shared

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: BuxTokens.Radius.field, style: .continuous)
        Group {
            if settings.brandThemesEnabled {
                shape
                    .fill(themeManager.cardFill(for: colorScheme))
                    .overlay(
                        shape.stroke(
                            DashboardThemeTint.themedCardStroke(
                                themeManager: themeManager,
                                colorScheme: colorScheme
                            ),
                            lineWidth: 1
                        )
                    )
            } else {
                shape
                    .fill(themeManager.cardFill(for: colorScheme))
                    .overlay(
                        shape.stroke(
                            themeManager.subtleCardStroke(for: colorScheme),
                            lineWidth: 1
                        )
                    )
            }
        }
    }
}

// MARK: - Form scaffold backdrop

struct BuxFormScaffold<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            themeManager.screenBackground(for: colorScheme)
                .ignoresSafeArea()

            BuxHeroMeshBackground()

            content()
        }
        .buxThemedPresentation()
    }
}

extension View {
    /// Themed row background for Form / List sections.
    func buxFormRowPlate() -> some View {
        listRowBackground(BuxFormRowPlate())
    }

    /// Standard Form styling: hidden system background + themed rows + inset grouped spacing.
    func buxThemedFormStyle() -> some View {
        self
            .scrollContentBackground(.hidden)
            .listRowSeparator(.hidden)
            .listRowSpacing(BuxTokens.tight)
            .listSectionSpacing(BuxTokens.section)
            .buxFormRowPlate()
    }
}
