//
//  DebtBreakdownChart.swift
//  BuxMuse
//  Features/Debt/Views/
//
//  Donut + legend for active debt balances.
//

import SwiftUI

struct DebtBreakdownChartView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    let breakdown: [(name: String, amount: Double)]

    private var total: Double {
        max(breakdown.reduce(0) { $0 + $1.amount }, 0.01)
    }

    private var displayItems: [(name: String, amount: Double)] {
        Array(breakdown.prefix(6))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 20) {
                ZStack {
                    DebtBreakdownDonutChart(breakdown: breakdown.map { ($0.name, $0.amount) })
                        .frame(width: 132, height: 132)

                    VStack(spacing: 2) {
                        BuxCatalogText.text("Total owed")
                            .font(.system(size: 9, weight: .semibold))
                            .buxLabelSecondary()
                        Text(appSettingsManager.format(Decimal(total)))
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                            .minimumScaleFactor(0.75)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: 72)
                }

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(displayItems.enumerated()), id: \.offset) { index, item in
                        legendRow(
                            name: item.name,
                            amount: item.amount,
                            index: index
                        )
                    }

                    if breakdown.count > displayItems.count {
                        Text(
                            BuxLocalizedString.format(
                                "+%lld more",
                                locale: appSettingsManager.interfaceLocale,
                                Int64(breakdown.count - displayItems.count)
                            )
                        )
                        .font(.system(size: 10, weight: .semibold))
                        .buxLabelSecondary()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Debt balance breakdown")
    }

    private func legendRow(name: String, amount: Double, index: Int) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(BuxChartColors.color(forCategoryName: name, fallbackIndex: index))
                .frame(width: 8, height: 8)

            Text(name)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                .lineLimit(1)

            Spacer(minLength: 4)

            Text(appSettingsManager.format(Decimal(amount)))
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                .lineLimit(1)

            Text("\(Int((amount / total) * 100))%")
                .font(.system(size: 10, weight: .semibold))
                .buxLabelSecondary()
                .frame(width: 32, alignment: .trailing)
        }
    }
}

struct DebtBreakdownDonutChart: View {
    let breakdown: [(String, Double)]

    var body: some View {
        MiniCategoryDonutChart(
            breakdown: breakdown,
            useGPUReveal: false,
            rasterizesChart: true
        )
    }
}
