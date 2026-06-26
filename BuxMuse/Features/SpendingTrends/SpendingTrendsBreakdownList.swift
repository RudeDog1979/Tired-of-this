//
//  SpendingTrendsBreakdownList.swift
//  BuxMuse
//

import SwiftUI

struct SpendingTrendsBreakdownList: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    let mode: SpendingTrendsBreakdownMode
    let rows: [SpendingTrendBreakdownRow]
    let customCategories: [ExpenseCategoryRecord]
    let formatAmount: (Decimal) -> String
    let onSelectRow: (SpendingTrendBreakdownRow) -> Void

    private var locale: Locale { appSettingsManager.interfaceLocale }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                if index > 0 {
                    BuxFormRowDivider()
                }
                Button {
                    onSelectRow(row)
                } label: {
                    rowContent(row, index: index)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
        .expensesThemedCardChrome(cornerRadius: 20)
    }

    @ViewBuilder
    private func rowContent(_ row: SpendingTrendBreakdownRow, index: Int) -> some View {
        switch mode {
        case .category:
            categoryRow(row, index: index)
        case .merchant:
            merchantRow(row)
        }
    }

    private func categoryRow(_ row: SpendingTrendBreakdownRow, index: Int) -> some View {
        let catalogColor = ExpenseCategoryCatalog.catalogColorName(
            forDisplayName: row.name,
            customCategories: customCategories,
            locale: locale
        )
        let tint = ExpenseCategoryStyle.foreground(for: catalogColor)
        let background = ExpenseCategoryStyle.background(for: catalogColor)
        let icon = ExpenseCategoryCatalog.icon(
            forDisplayName: row.name,
            customCategories: customCategories,
            locale: locale
        )

        return HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(tint)
                .frame(width: 3)
                .padding(.vertical, 10)

            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(background)
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(tint)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(row.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(themeManager.labelPrimary(for: colorScheme))
                        .lineLimit(1)
                    Text(transactionCountLabel(row.transactionCount))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(formatAmount(Decimal(row.amount)))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(themeManager.labelPrimary(for: colorScheme))
                    deltaLabel(row.changeAmount)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(themeManager.chevronMuted(for: colorScheme))
            }
            .padding(.leading, 12)
            .padding(.trailing, 14)
            .padding(.vertical, 10)
        }
    }

    private func merchantRow(_ row: SpendingTrendBreakdownRow) -> some View {
        HStack(spacing: 12) {
            AsyncMerchantLogoView(merchantName: row.name, size: 40)
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(row.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(themeManager.labelPrimary(for: colorScheme))
                    .lineLimit(1)
                Text(transactionCountLabel(row.transactionCount))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text(formatAmount(Decimal(row.amount)))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(themeManager.labelPrimary(for: colorScheme))
                deltaLabel(row.changeAmount)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(themeManager.chevronMuted(for: colorScheme))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private func transactionCountLabel(_ count: Int) -> String {
        BuxLocalizedString.format(
            "%lld transactions",
            locale: locale,
            Int64(count)
        )
    }

    @ViewBuilder
    private func deltaLabel(_ change: Double) -> some View {
        if abs(change) < 0.005 {
            BuxCatalogDynamicText(key: "No change")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
        } else {
            HStack(spacing: 2) {
                Image(systemName: change > 0 ? "arrow.up" : "arrow.down")
                    .font(.system(size: 9, weight: .bold))
                Text(formatAmount(Decimal(abs(change))))
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(change > 0 ? BuxChartColors.comparisonUp : BuxChartColors.comparisonDown)
        }
    }
}
