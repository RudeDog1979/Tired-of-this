//
//  CategoryPillBar.swift
//  BuxMuse
//
//  Home category selector — Studio glass floating bar + scrollable chips.
//

import SwiftUI

private enum DashboardCategory: String, CaseIterable, Identifiable {
    case expenses = "Expenses"
    case subscriptions = "Subscriptions"
    case goals = "Goals"
    case insights = "Insights"

    var id: String { rawValue }
}

struct CategoryPillBar: View {
    @Binding var activeCategory: String
    @Binding var isExpanded: Bool
    /// Kept for call-site compatibility; Studio bar always uses brand / dashboard wash when enabled.
    var usesDashboardTint: Bool = false

    private var categorySelection: Binding<DashboardCategory> {
        Binding(
            get: {
                DashboardCategory(rawValue: activeCategory) ?? .expenses
            },
            set: { newCategory in
                guard newCategory.rawValue != activeCategory else { return }
                withAnimation(.buxCategorySpring) {
                    activeCategory = newCategory.rawValue
                    isExpanded = true
                }
            }
        )
    }

    var body: some View {
        StudioGlassHorizontalSectionMenu(
            selection: categorySelection,
            tabs: DashboardCategory.allCases,
            label: \.rawValue
        )
    }
}

// MARK: - Theme (pill + hero)

extension ThemeManager {
    func pillTrackFill(for colorScheme: ColorScheme) -> Color {
        materialScheme(for: colorScheme).surfaceContainer
    }

    func pillActiveChipFill(for colorScheme: ColorScheme) -> Color {
        materialScheme(for: colorScheme).primaryContainer
    }

    func pillFloatingShadow(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color.black.opacity(0.25)
            : Color.black.opacity(0.06)
    }

    func heroCardShadow(for colorScheme: ColorScheme) -> (color: Color, radius: CGFloat, y: CGFloat) {
        (
            BuxMaterialChrome.elevatedShadowColor(for: colorScheme),
            BuxMaterialChrome.elevatedShadowRadius,
            BuxMaterialChrome.elevatedShadowY
        )
    }

    /// List / card tier — no shadow (stroke defines edge; avoids scroll clipping).
    func listCardShadow(for colorScheme: ColorScheme) -> (color: Color, radius: CGFloat, y: CGFloat) {
        (.clear, 0, 0)
    }
}
