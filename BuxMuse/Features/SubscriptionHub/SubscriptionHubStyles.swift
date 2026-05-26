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

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(colorScheme == .dark ? .white.opacity(0.4) : Color(red: 140/255, green: 145/255, blue: 160/255))
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
            .background(themeManager.cardFill(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(themeManager.subtleCardStroke(for: colorScheme), lineWidth: 1)
            )
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
