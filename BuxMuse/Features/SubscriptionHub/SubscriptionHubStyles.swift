//
//  SubscriptionHubStyles.swift
//  BuxMuse
//
//  Shared layout + surfaces for detail hubs (Subscription Hub, Insight Deep Dive).
//

import SwiftUI

// MARK: - Shared detail tokens (HIG / BuxLayout)

enum BuxDetailStyle {
    static let cardPadding: CGFloat = BuxLayout.loose - 4 // 20
    static let cardRadius: CGFloat = BuxLayout.cornerCard + 8 // 24
    static let rowCardRadius: CGFloat = 18
    static let pairedCardMinHeight: CGFloat = BuxLayout.dashboardSmallCardHeight
}

enum SubscriptionHubStyle {
    static let cardPadding = BuxDetailStyle.cardPadding
    static let cardRadius = BuxDetailStyle.cardRadius
    static let rowCardRadius = BuxDetailStyle.rowCardRadius
    static let timelineCardWidth: CGFloat = 220
    static let timelineCardMinHeight = BuxDetailStyle.pairedCardMinHeight
}

typealias BuxDetailSectionHeader = SubscriptionHubSectionHeader

// MARK: - Section header

struct SubscriptionHubSectionHeader: View {
    let title: String
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(themeManager.sectionHeaderColor(for: colorScheme))
            .kerning(1.2)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Card chrome

struct SubscriptionHubCardSurface: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    var cornerRadius: CGFloat = SubscriptionHubStyle.cardRadius

    func body(content: Content) -> some View {
        content
            .buxThemedCardChrome(cornerRadius: cornerRadius)
    }
}

extension View {
    func buxDetailCard(cornerRadius: CGFloat = BuxDetailStyle.cardRadius) -> some View {
        modifier(SubscriptionHubCardSurface(cornerRadius: cornerRadius))
    }

    func subscriptionHubCard(cornerRadius: CGFloat = SubscriptionHubStyle.cardRadius) -> some View {
        buxDetailCard(cornerRadius: cornerRadius)
    }
}
