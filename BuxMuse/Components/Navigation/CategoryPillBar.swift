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
                    Capsule()
                        .fill(themeManager.pillTrackFill(for: colorScheme))
                    if usesDashboardTint {
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
            Capsule()
                .stroke(
                    usesDashboardTint
                        ? DashboardThemeTint.themedCardStroke(themeManager: themeManager, colorScheme: colorScheme)
                        : (colorScheme == .dark ? Color.clear : Color.black.opacity(0.10)),
                    lineWidth: 1
                )
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
            return (Color.black.opacity(0.2), 12, 6)
        }
        return (Color.black.opacity(0.06), 14, 6)
    }

    /// Expense list rows — lighter than hero; keeps cards off the mesh background.
    func listCardShadow(for colorScheme: ColorScheme) -> (color: Color, radius: CGFloat, y: CGFloat) {
        if colorScheme == .dark {
            return (Color.black.opacity(0.28), 10, 5)
        }
        return (Color.black.opacity(0.07), 8, 4)
    }
}
