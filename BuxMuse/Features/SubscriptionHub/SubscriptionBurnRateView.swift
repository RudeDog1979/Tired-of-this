//
//  SubscriptionBurnRateView.swift
//  BuxMuse
//  Features/SubscriptionHub/
//
//  Component representing the subscription burn rates and cancellation projections.
//

import SwiftUI

struct SubscriptionBurnRateView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    let daily: MoneyAmount
    let weekly: MoneyAmount
    let monthly: MoneyAmount
    let yearly: MoneyAmount
    let projectionText: String
    let quarterlyIncrease: Double

    var body: some View {
        VStack(alignment: .leading, spacing: BuxLayout.tight + 6) {
            SubscriptionHubSectionHeader(title: "SUBSCRIPTION BURN RATE")

            VStack(spacing: BuxLayout.section) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Monthly Burn Rate")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : Color(red: 100/255, green: 110/255, blue: 130/255))

                        Text(appSettingsManager.format(monthly.value))
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }

                    Spacer(minLength: 8)

                    if quarterlyIncrease > 0 {
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("+\(String(format: "%.1f", quarterlyIncrease))%")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(.red)

                            Text("This Quarter")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.gray)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.red.opacity(0.12))
                        .clipShape(Capsule())
                    }
                }

                Divider().opacity(0.08)

                HStack(spacing: 0) {
                    BurnRateGridItem(label: "Daily", value: appSettingsManager.format(daily.value))
                    Spacer()
                    BurnRateGridItem(label: "Weekly", value: appSettingsManager.format(weekly.value))
                    Spacer()
                    BurnRateGridItem(label: "Yearly", value: appSettingsManager.format(yearly.value))
                }

                if !projectionText.isEmpty {
                    Divider().opacity(0.08)

                    HStack(spacing: BuxLayout.tight) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(themeManager.current.accentColor)

                        Text(projectionText)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(themeManager.current.accentColor)
                            .lineLimit(2)

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(themeManager.current.accentColor.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
            .padding(SubscriptionHubStyle.cardPadding)
            .subscriptionHubCard()
        }
    }
}

struct BurnRateGridItem: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.gray)
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
    }
}
