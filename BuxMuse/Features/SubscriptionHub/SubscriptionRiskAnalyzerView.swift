//
//  SubscriptionRiskAnalyzerView.swift
//  BuxMuse
//  Features/SubscriptionHub/
//
//  Displaying price hikes, zombies, and other risk detections in BuxMuse design language.
//

import SwiftUI

struct SubscriptionRiskAnalyzerView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    let subscriptions: [SubscriptionInfo]
    let onSelect: (String) -> Void

    @State private var cachedRisks: [SubscriptionHubSectionCache.RiskRow] = []

    var body: some View {
        VStack(alignment: .leading, spacing: BuxLayout.tight + 6) {
            SubscriptionHubSectionHeader(title: "Subscription risk analyzer")

            if cachedRisks.isEmpty {
                HStack(spacing: BuxLayout.section) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.green)

                    BuxCatalogText.text("No pricing or billing risks detected.")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.8) : .black.opacity(0.7))

                    Spacer(minLength: 0)
                }
                .padding(SubscriptionHubStyle.cardPadding)
                .subscriptionHubCard(cornerRadius: SubscriptionHubStyle.rowCardRadius)
            } else {
                VStack(spacing: BuxLayout.section) {
                    ForEach(Array(cachedRisks.enumerated()), id: \.offset) { _, item in
                        Button(action: {
                            if item.subName != "Video Bundles" {
                                onSelect(item.subName)
                            }
                        }) {
                            HStack(alignment: .top, spacing: BuxLayout.section) {
                                ZStack {
                                    Circle()
                                        .fill(severityColor(item.risk.severity).opacity(0.12))
                                        .frame(width: 40, height: 40)

                                    Image(systemName: severityIcon(item.risk.type))
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(severityColor(item.risk.severity))
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(item.subName)
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                                            .lineLimit(1)

                                        Spacer(minLength: 4)

                                        Text(item.risk.type.localizedDisplayName(locale: appSettingsManager.interfaceLocale))
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(severityColor(item.risk.severity))
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .background(severityColor(item.risk.severity).opacity(0.12))
                                            .clipShape(Capsule())
                                    }

                                    Text(item.risk.description)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(themeManager.labelSecondary(for: colorScheme))
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                }
                            }
                            .padding(SubscriptionHubStyle.cardPadding)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .subscriptionHubCard(cornerRadius: SubscriptionHubStyle.rowCardRadius)
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
        cachedRisks = SubscriptionHubSectionCache.detectedRisks(
            from: subscriptions,
            locale: appSettingsManager.interfaceLocale
        )
    }

    private func severityColor(_ severity: String) -> Color {
        switch severity {
        case "high": return .red
        case "medium": return .orange
        default: return .blue
        }
    }

    private func severityIcon(_ type: SubscriptionRiskType) -> String {
        switch type {
        case .priceHike: return "chart.line.uptrend.xyaxis"
        case .doubleCharge: return "exclamationmark.2"
        case .zombieSubscription: return "eye.slash.fill"
        case .overlappingFeatures: return "square.on.square.dashed"
        case .currencyChange: return "dollarsign.arrow.circlepath"
        default: return "exclamationmark.triangle.fill"
        }
    }
}

extension SubscriptionRisk {
    var riskTypeDisplay: String {
        type.displayName
    }
}
