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
            SubscriptionHubSectionHeader(title: "Upcoming renewals")

            if renewals.isEmpty {
                emptyState
            } else if renewals.count == 1 {
                Button(action: { onSelect(renewals[0].merchantName) }) {
                    renewalCard(for: renewals[0])
                }
                .buttonStyle(BuxMicroShrinkStyle())
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(renewals) { sub in
                            Button(action: { onSelect(sub.merchantName) }) {
                                renewalCard(for: sub)
                                    .containerRelativeFrame(.horizontal) { width, _ in
                                        width - 40
                                    }
                            }
                            .buttonStyle(BuxMicroShrinkStyle())
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollClipDisabled()
                .scrollTargetBehavior(.viewAligned)
                .safeAreaPadding(.horizontal, 20)
                .safeAreaPadding(.vertical, 8)
                .padding(.horizontal, -BuxLayout.marginHorizontal)
                .buxSoftHorizontalScrollChrome()
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
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(SubscriptionHubStyle.cardPadding)
        .subscriptionHubCard(cornerRadius: SubscriptionHubStyle.rowCardRadius)
    }

    private func renewalCard(for sub: SubscriptionInfo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                AsyncMerchantLogoView(merchantName: sub.merchantName, size: 36)

                VStack(alignment: .leading, spacing: 4) {
                    Text(sub.merchantName)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                        .multilineTextAlignment(.leading)

                    Text(sub.category.displayName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Text(appSettingsManager.format(abs(sub.cost.value)))
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(themeManager.labelPrimary(for: colorScheme))

            HStack(spacing: 6) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 12))
                    .foregroundColor(themeManager.current.accentColor)

                Text(Self.renewalDateFormatter.string(from: sub.nextRenewalDate))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : Color(red: 100/255, green: 110/255, blue: 130/255))
                    .multilineTextAlignment(.leading)
            }

            Text(sub.billingCycle.displayName)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(themeManager.current.accentColor)
                .padding(.horizontal, BuxLayout.tight)
                .padding(.vertical, 4)
                .background(themeManager.current.accentColor.opacity(0.12))
                .clipShape(Capsule())
        }
        .padding(SubscriptionHubStyle.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .subscriptionHubCard(cornerRadius: SubscriptionHubStyle.rowCardRadius)
    }
}
