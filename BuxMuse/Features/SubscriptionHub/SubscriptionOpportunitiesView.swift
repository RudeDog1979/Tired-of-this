//
//  SubscriptionOpportunitiesView.swift
//  BuxMuse
//  Features/SubscriptionHub/
//
//  Displaying smart cancellation suggestions and savings opportunities.
//

import SwiftUI

struct SubscriptionOpportunitiesView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    let subscriptions: [SubscriptionInfo]
    let onSelect: (String) -> Void

    @State private var cachedOpportunities: [SavingsOpportunityItem] = []

    var body: some View {
        VStack(alignment: .leading, spacing: BuxLayout.tight + 6) {
            SubscriptionHubSectionHeader(title: "Smart cancellation opportunities")

            if cachedOpportunities.isEmpty {
                HStack(spacing: BuxLayout.section) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 20))
                        .foregroundColor(themeManager.current.accentColor)

                    BuxCatalogText.text("Your subscriptions are fully optimized.")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.8) : .black.opacity(0.7))

                    Spacer(minLength: 0)
                }
                .padding(SubscriptionHubStyle.cardPadding)
                .subscriptionHubCard(cornerRadius: SubscriptionHubStyle.rowCardRadius)
            } else {
                VStack(spacing: BuxLayout.section) {
                    ForEach(cachedOpportunities) { item in
                        Button(action: {
                            if item.merchantName != "Consolidated Bundles" {
                                onSelect(item.merchantName)
                            }
                        }) {
                            opportunityRow(item)
                        }
                        .buttonStyle(BuxMicroShrinkStyle())
                    }
                }
            }
        }
        .onAppear { refreshCache() }
        .onChange(of: subscriptions.count) { _, _ in refreshCache() }
    }

    private func refreshCache() {
        cachedOpportunities = SubscriptionHubSectionCache.opportunities(
            from: subscriptions,
            settingsManager: appSettingsManager
        )
    }

    private func opportunityRow(_ item: SavingsOpportunityItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(themeManager.current.accentColor.opacity(0.12))
                        .frame(width: 38, height: 38)

                    Image(systemName: "sparkles")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(themeManager.current.accentColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.merchantName)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                        .fixedSize(horizontal: false, vertical: true)

                    Text(item.description)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.gray)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(
                    BuxLocalizedString.format(
                        "Save %@/mo",
                        locale: appSettingsManager.interfaceLocale,
                        appSettingsManager.format(item.monthlySavings)
                    )
                )
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.green)
                    .lineLimit(2)
                    .multilineTextAlignment(.trailing)
                    .minimumScaleFactor(0.85)
            }

            HStack(alignment: .center, spacing: 8) {
                Text(item.savingsPhrase)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(themeManager.current.accentColor)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.3) : .black.opacity(0.3))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(themeManager.current.accentColor.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(SubscriptionHubStyle.cardPadding)
        .fixedSize(horizontal: false, vertical: true)
        .subscriptionHubCard(cornerRadius: SubscriptionHubStyle.rowCardRadius)
    }
}

struct SavingsOpportunityItem: Identifiable {
    let id = UUID()
    let merchantName: String
    let description: String
    let savingsPhrase: String
    let monthlySavings: Decimal
    let yearlySavings: Decimal
}
