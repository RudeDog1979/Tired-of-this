//
//  SubscriptionRenewalTimelineView.swift
//  BuxMuse
//  Features/SubscriptionHub/
//
//  Horizontal scrolling renewals timeline component matching BuxMuse style.
//

import SwiftUI

struct SubscriptionRenewalTimelineView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    let renewals: [SubscriptionInfo]
    let onSelect: (String) -> Void

    private static let renewalDateFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d, yyyy"
        return fmt
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: BuxLayout.tight + 6) {
            SubscriptionHubSectionHeader(title: "UPCOMING RENEWALS")

            if renewals.isEmpty {
                emptyState
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: BuxLayout.section) {
                        ForEach(renewals) { sub in
                            Button(action: { onSelect(sub.merchantName) }) {
                                renewalCard(for: sub)
                            }
                            .buttonStyle(BuxMicroShrinkStyle())
                        }
                    }
                    .padding(.vertical, BuxLayout.tight)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: BuxLayout.section) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 24))
                .foregroundColor(.gray)
            Text("No upcoming renewals scheduled")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: SubscriptionHubStyle.timelineCardMinHeight)
        .padding(SubscriptionHubStyle.cardPadding)
        .subscriptionHubCard(cornerRadius: SubscriptionHubStyle.rowCardRadius)
    }

    private func renewalCard(for sub: SubscriptionInfo) -> some View {
        VStack(alignment: .leading, spacing: BuxLayout.section) {
            HStack(spacing: BuxLayout.section) {
                AsyncMerchantLogoView(merchantName: sub.merchantName, size: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(sub.merchantName)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(colorScheme == .dark ? .white : Color(red: 26/255, green: 28/255, blue: 32/255))
                        .lineLimit(1)

                    Text(sub.category.displayName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Text(appSettingsManager.format(sub.cost.value))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(colorScheme == .dark ? .white : .black)
            }

            HStack {
                Image(systemName: "clock.fill")
                    .font(.system(size: 12))
                    .foregroundColor(themeManager.current.accentColor)

                Text(Self.renewalDateFormatter.string(from: sub.nextRenewalDate))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : Color(red: 100/255, green: 110/255, blue: 130/255))
                    .lineLimit(1)

                Spacer(minLength: 0)

                Text(sub.billingCycle.displayName)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(themeManager.current.accentColor)
                    .padding(.horizontal, BuxLayout.tight)
                    .padding(.vertical, 4)
                    .background(themeManager.current.accentColor.opacity(0.12))
                    .clipShape(Capsule())
            }
        }
        .padding(SubscriptionHubStyle.cardPadding)
        .frame(width: SubscriptionHubStyle.timelineCardWidth)
        .frame(minHeight: SubscriptionHubStyle.timelineCardMinHeight, alignment: .top)
        .subscriptionHubCard(cornerRadius: SubscriptionHubStyle.rowCardRadius)
    }
}
