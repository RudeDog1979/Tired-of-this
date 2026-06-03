//
//  SimpleStudioInsightsViews.swift
//  BuxMuse
//

import SwiftUI

struct SimpleStudioInsightsHubSection: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager

    let snapshot: SimpleStudioInsightsSnapshot

    private var accent: Color { themeManager.current.accentColor }

    var body: some View {
        VStack(alignment: .leading, spacing: BuxTokens.tight) {
            Text("YOUR NUMBERS")
                .font(.system(size: 11, weight: .bold))
                .buxLabelSecondary()

            VStack(alignment: .leading, spacing: 12) {
                Text(snapshot.headline)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(themeManager.labelPrimary(for: colorScheme))

                HStack(spacing: 10) {
                    if let profit = snapshot.profitPerJobFormatted {
                        metricPill(title: "Avg kept / job", value: profit, icon: "chart.bar.fill")
                    }
                    if let waiting = snapshot.waitingTotalFormatted {
                        metricPill(title: "Still owed", value: waiting, icon: "clock.fill")
                    }
                }

                HStack(spacing: 16) {
                    Text("\(snapshot.paidJobCount) paid")
                        .font(.system(size: 11, weight: .semibold))
                        .buxLabelSecondary()
                    Text("\(snapshot.openJobCount) open")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(snapshot.openJobCount > 0 ? .orange : .secondary)
                }

                if let tip = snapshot.rateTip {
                    Text(tip)
                        .font(.system(size: 11, weight: .medium))
                        .buxLabelSecondary()
                }
            }
            .padding(BuxLayout.section)
            .studioThemedCardChrome(cornerRadius: 20)
        }
    }

    private func metricPill(title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(accent)
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
            Text(title)
                .font(.system(size: 9, weight: .bold))
                .buxLabelSecondary()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
