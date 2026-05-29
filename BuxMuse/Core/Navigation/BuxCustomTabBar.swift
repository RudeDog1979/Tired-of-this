//
//  BuxCustomTabBar.swift
//  BuxMuse
//
//  Floating glass pill tab bar — anchored to the 50pt tab bar band (HIG).
//

import SwiftUI

enum BuxTabBarMetrics {
    // iPhone layout guide (393×852 reference): 50pt tab bar, 34pt home indicator.
    static let tabBarBandHeight: CGFloat = 50
    static let homeIndicatorHeight: CGFloat = 34
    /// Small nudge toward the physical bottom (positive = down).
    static let tabBarDownNudge: CGFloat = 5
    static let cornerRadius: CGFloat = 32
    static let pillHorizontalPadding: CGFloat = 12
    static let tabSpacing: CGFloat = 2
    static let tabSlotWidth: CGFloat = 66
    static let innerPadding: CGFloat = 4
    static let itemVerticalPadding: CGFloat = 2
    static let scrollClearance: CGFloat = tabBarBandHeight + homeIndicatorHeight
    static let lightModeOutlineOpacity: CGFloat = 0.10

    static func pillWidth(tabCount: Int) -> CGFloat {
        let count = CGFloat(tabCount)
        let slots = count * tabSlotWidth
        let gaps = max(0, count - 1) * tabSpacing
        return (pillHorizontalPadding * 2) + slots + gaps
    }
}

extension AppTab: Identifiable {
    var id: Self { self }

    var title: String {
        switch self {
        case .home: return "Dashboard"
        case .expense: return "Expenses"
        case .studio: return "Studio"
        case .settings: return "Settings"
        }
    }

    static func visibleTabs(studioEnabled: Bool) -> [AppTab] {
        studioEnabled
            ? [.home, .expense, .studio, .settings]
            : [.home, .expense, .settings]
    }
}

/// Sits in the 50pt tab bar band directly above the home indicator — no extra lift.
struct BuxDockAnchoredTabBar: View {
    @Binding var selectedTab: AppTab
    var studioEnabled: Bool
    var accentColor: Color

    @ObservedObject private var scrollState = BuxTabBarScrollState.shared
    @ObservedObject private var settings = SettingsStore.shared

    var body: some View {
        HStack {
            Spacer(minLength: 0)
            BuxCustomTabBar(
                selectedTab: $selectedTab,
                studioEnabled: studioEnabled,
                accentColor: accentColor
            )
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .frame(height: BuxTabBarMetrics.tabBarBandHeight)
        .offset(y: BuxTabBarMetrics.tabBarDownNudge + scrollState.minimizeOffset)
        .opacity(scrollState.minimizeOpacity)
        .animation(settings.reducedMotion ? .none : .spring(response: 0.38, dampingFraction: 0.86), value: scrollState.isMinimized)
    }
}

struct BuxCustomTabBar: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @ObservedObject private var settings = SettingsStore.shared

    @Binding var selectedTab: AppTab
    var studioEnabled: Bool
    var accentColor: Color

    private var adaptiveForeground: Color {
        colorScheme == .dark ? .white : .black
    }

    private var tabs: [AppTab] {
        AppTab.visibleTabs(studioEnabled: studioEnabled)
    }

    private var pillShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: BuxTabBarMetrics.cornerRadius, style: .continuous)
    }

    var body: some View {
        pillContent
            .frame(maxHeight: .infinity, alignment: .center)
    }

    private var pillContent: some View {
        HStack(spacing: BuxTabBarMetrics.tabSpacing) {
            ForEach(tabs) { tab in
                BuxTabBarItem(
                    tab: tab,
                    isSelected: selectedTab == tab,
                    accentColor: accentColor,
                    unselectedColor: adaptiveForeground,
                    action: { selectedTab = tab }
                )
                .frame(width: BuxTabBarMetrics.tabSlotWidth)
            }
        }
        .padding(.horizontal, BuxTabBarMetrics.pillHorizontalPadding)
        .padding(.vertical, BuxTabBarMetrics.innerPadding + BuxTabBarMetrics.itemVerticalPadding)
        .frame(width: BuxTabBarMetrics.pillWidth(tabCount: tabs.count))
        .background {
            BuxGlassPillBackground(cornerRadius: BuxTabBarMetrics.cornerRadius)
        }
        .overlay {
            if !settings.useGlassmorphism || colorScheme == .light {
                pillShape
                    .stroke(
                        colorScheme == .dark
                            ? Color.clear
                            : Color.black.opacity(BuxTabBarMetrics.lightModeOutlineOpacity),
                        lineWidth: 1
                    )
            }
        }
        .clipShape(pillShape)
        .modifier(BuxTabBarPillShadow(colorScheme: colorScheme, glassEnabled: settings.useGlassmorphism))
    }
}

private struct BuxTabBarPillShadow: ViewModifier {
    let colorScheme: ColorScheme
    var glassEnabled: Bool

    func body(content: Content) -> some View {
        if glassEnabled {
            content
        } else if colorScheme == .dark {
            content.shadow(color: .black.opacity(0.35), radius: 12, y: 4)
        } else {
            content
                .shadow(color: .black.opacity(0.11), radius: 14, y: 5)
                .shadow(color: .black.opacity(0.05), radius: 3, y: 1)
        }
    }
}

private struct BuxTabBarItem: View {
    let tab: AppTab
    let isSelected: Bool
    let accentColor: Color
    let unselectedColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                BuxTabIcon(tab: tab, isSelected: isSelected)
                    .foregroundStyle(itemColor)

                Text(tab.title)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(itemColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var itemColor: Color {
        isSelected ? accentColor : unselectedColor.opacity(0.4)
    }
}

extension View {
    /// Extra bottom scroll room so content can pass under the tab bar band + home indicator.
    func buxCustomTabBarScrollClearance() -> some View {
        contentMargins(.bottom, BuxTabBarMetrics.scrollClearance, for: .scrollContent)
    }
}
