//
//  CategoryPillBar.swift
//  BuxMuse
//
//  Bux segmented category pill — always-visible track with sliding selection chip.
//

import SwiftUI

struct CategoryPillBar: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @ObservedObject private var settings = SettingsStore.shared
    @Binding var activeCategory: String
    @Binding var isExpanded: Bool
    /// Home dashboard preview — slightly stronger theme wash on the pill track and selection chip.
    var usesDashboardTint: Bool = false

    private let categories = ["Expenses", "Subscriptions", "Goals", "Insights"]
    private let pillSpring = Animation.buxCategorySpring

    @Namespace private var pillNamespace

    var body: some View {
        HStack(spacing: 0) {
            ZStack(alignment: .leading) {
                ZStack {
                    if settings.useGlassmorphism {
                        BuxGlassCapsuleBackground()
                    } else {
                        Capsule()
                            .fill(themeManager.pillTrackFill(for: colorScheme))
                    }
                    if usesDashboardTint && !settings.useGlassmorphism {
                        Capsule()
                            .fill(DashboardThemeTint.pillTrackWash(themeManager: themeManager, colorScheme: colorScheme))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                HStack(spacing: 0) {
                    ForEach(Array(categories.enumerated()), id: \.element) { index, category in
                        pillButton(category: category, index: index)
                        if index < categories.count - 1 {
                            Spacer(minLength: 0)
                        }
                    }
                }
                .padding(.horizontal, BuxLayout.pillInnerInset)
                .padding(.vertical, BuxLayout.pillInnerInset)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: BuxLayout.pillHeight)
        .compositingGroup()
        .clipShape(Capsule())
        .overlay {
            if !settings.useGlassmorphism {
                Capsule()
                    .stroke(
                        usesDashboardTint
                            ? DashboardThemeTint.themedCardStroke(themeManager: themeManager, colorScheme: colorScheme)
                            : themeManager.cardOutlineStroke(for: colorScheme, branded: false),
                        lineWidth: 1
                    )
            }
        }
    }

    @ViewBuilder
    private func pillButton(category: String, index: Int) -> some View {
        Button(action: { handleTap(category: category) }) {
            Text(category)
                .font(.system(size: 13, weight: category == activeCategory ? .semibold : .medium))
                .foregroundColor(
                    category == activeCategory
                        ? themeManager.current.accentColor
                        : themeManager.pillInactiveLabelColor(for: colorScheme)
                )
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background {
                    if category == activeCategory {
                        Capsule()
                            .fill(
                                usesDashboardTint
                                    ? DashboardThemeTint.pillActiveChipFill(themeManager: themeManager, colorScheme: colorScheme)
                                    : themeManager.pillActiveChipFill(for: colorScheme)
                            )
                            .matchedGeometryEffect(id: "activePillBg", in: pillNamespace)
                    }
                }
        }
        .buttonStyle(MorphingPillButtonStyle())
        .zIndex(category == activeCategory ? 1 : 0)
    }

    private func handleTap(category: String) {
        guard category != activeCategory else { return }
        withAnimation(pillSpring) {
            activeCategory = category
            isExpanded = true
        }
    }
}

// MARK: - Theme (pill + hero)

extension ThemeManager {
    func pillTrackFill(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 24/255, green: 26/255, blue: 32/255).opacity(0.92)
            : Color.white
    }

    func pillActiveChipFill(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? current.accentColor.opacity(0.15)
            : current.accentColor.opacity(0.08)
    }

    func pillFloatingShadow(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color.black.opacity(0.25)
            : Color.black.opacity(0.06)
    }

    func heroCardShadow(for colorScheme: ColorScheme) -> (color: Color, radius: CGFloat, y: CGFloat) {
        if colorScheme == .dark {
            return (Color.black.opacity(0.20), 12, 6)
        }
        return (Color.black.opacity(BuxTokens.Shadow.heroColorOpacityLight), BuxTokens.Shadow.heroRadius, BuxTokens.Shadow.heroY)
    }

    /// List / card tier — no shadow (stroke defines edge; avoids scroll clipping).
    func listCardShadow(for colorScheme: ColorScheme) -> (color: Color, radius: CGFloat, y: CGFloat) {
        (.clear, 0, 0)
    }
}
