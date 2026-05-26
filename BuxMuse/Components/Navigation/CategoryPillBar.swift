//
//  CategoryPillBar.swift
//  BuxMuse
//
//  Elastic category pill — collapsed chip, expanded track, selection blob via
//  matchedGeometryEffect on the active tab (aligned to label bounds).
//

import SwiftUI

struct CategoryPillBar: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @Binding var activeCategory: String
    @Binding var isExpanded: Bool

    private let categories = ["Expenses", "Subscriptions", "Goals", "Insights"]
    private let pillSpring = Animation.buxLiquidSpring

    @Namespace private var pillNamespace

    var body: some View {
        HStack(spacing: 0) {
            ZStack(alignment: .leading) {
                // Shell — single capsule; grows with expanded width (no fade-in tray)
                Capsule()
                    .fill(themeManager.pillTrackFill(for: colorScheme))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                HStack(spacing: 0) {
                    ForEach(Array(categories.enumerated()), id: \.element) { index, category in
                        if isExpanded || category == activeCategory {
                            pillButton(category: category, index: index)
                            if isExpanded && index < categories.count - 1 {
                                Spacer(minLength: 0)
                            }
                        }
                    }
                }
                .padding(.horizontal, isExpanded ? BuxLayout.pillInnerInset : 0)
                .padding(.vertical, BuxLayout.pillInnerInset)
            }
            .frame(maxWidth: isExpanded ? .infinity : nil, alignment: .leading)

            if !isExpanded {
                Spacer(minLength: 0)
            }
        }
        .frame(height: BuxLayout.pillHeight)
        .fixedSize(horizontal: !isExpanded, vertical: true)
        .compositingGroup()
        .clipShape(Capsule())
        .shadow(
            color: isExpanded ? .clear : themeManager.pillFloatingShadow(for: colorScheme),
            radius: isExpanded ? 0 : 10,
            x: 0,
            y: isExpanded ? 0 : 4
        )
    }

    @ViewBuilder
    private func pillButton(category: String, index: Int) -> some View {
        Button(action: { handleTap(category: category) }) {
            HStack(spacing: 6) {
                Text(category)
                    .font(.system(size: 14, weight: category == activeCategory ? .semibold : .medium))
                    .foregroundColor(
                        category == activeCategory
                            ? themeManager.current.accentColor
                            : themeManager.pillInactiveLabelColor(for: colorScheme)
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                if !isExpanded && category == activeCategory {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(themeManager.pillInactiveLabelColor(for: colorScheme))
                        .opacity(0.85)
                }
            }
            .padding(.horizontal, isExpanded ? 12 : 16)
            .padding(.vertical, 8)
            .background {
                if category == activeCategory {
                    Capsule()
                        .fill(
                            isExpanded
                                ? themeManager.pillActiveChipFill(for: colorScheme)
                                : Color.clear
                        )
                        .matchedGeometryEffect(id: "activePillBg", in: pillNamespace)
                }
            }
        }
        .buttonStyle(MorphingPillButtonStyle())
        .zIndex(category == activeCategory ? 1 : 0)
    }

    private func handleTap(category: String) {
        let spring: Animation = {
            if isExpanded && category != activeCategory { return .buxCategorySpring }
            return pillSpring
        }()
        withAnimation(spring) {
            if isExpanded {
                if category == activeCategory {
                    isExpanded = false
                } else {
                    activeCategory = category
                }
            } else {
                isExpanded = true
            }
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
}
