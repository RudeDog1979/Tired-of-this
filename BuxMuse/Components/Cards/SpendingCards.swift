//
//  SpendingCards.swift
//  BuxMuse
//  Components/Cards/
//
//  All spending/transaction card components, extracted from ContentView.
//

import SwiftUI

// MARK: - Spending Category Stack Card (Collapsed stacked view)

struct SpendingCategoryStackCard: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var appSettingsManager: AppSettingsManager
    let item: SpendingCategoryItem
    var includesDashboardChrome = true

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(item.color)
                    .frame(width: 44, height: 44)

                Image(systemName: item.icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                BuxCatalogDynamicText(key: item.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(themeManager.labelPrimary(for: colorScheme))

                Text(
                    BuxLocalizedString.format(
                        "%lld transactions",
                        locale: appSettingsManager.interfaceLocale,
                        Int64(item.transactionsCount)
                    )
                )
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(themeManager.labelSecondary(for: colorScheme))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(item.amount)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(themeManager.labelPrimary(for: colorScheme))

                Text(item.percentage)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(themeManager.labelSecondary(for: colorScheme))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .dashboardChromeIfNeeded(includesDashboardChrome, cornerRadius: 18)
    }
}

// MARK: - Spending Category Row (Flat row for expanded immersive list)

struct SpendingCategoryRow: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var appSettingsManager: AppSettingsManager
    let item: SpendingCategoryItem

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(item.color)
                    .frame(width: 44, height: 44)

                Image(systemName: item.icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                BuxCatalogDynamicText(key: item.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(themeManager.labelPrimary(for: colorScheme))

                Text(
                    BuxLocalizedString.format(
                        "%lld transactions",
                        locale: appSettingsManager.interfaceLocale,
                        Int64(item.transactionsCount)
                    )
                )
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(themeManager.labelSecondary(for: colorScheme))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(item.amount)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(themeManager.labelPrimary(for: colorScheme))

                Text(item.percentage)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(themeManager.labelSecondary(for: colorScheme))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Transaction Row Card (Generic bank transaction row)

struct TransactionRowCard: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var themeManager: ThemeManager
    let item: TransactionItem
    var includesDashboardChrome = true

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(colorScheme == .dark ? Color.white.opacity(0.06) : Color(red: 242/255, green: 244/255, blue: 247/255))
                    .frame(width: 44, height: 44)

                Image(systemName: item.icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(themeManager.labelPrimary(for: colorScheme))
            }

            VStack(alignment: .leading, spacing: 4) {
                BuxCatalogDynamicText(key: item.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                Text(item.date)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(themeManager.labelSecondary(for: colorScheme))
            }

            Spacer()

            Text(item.amount)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(item.isPositive ? Color(red: 46/255, green: 204/255, blue: 113/255) : (themeManager.labelPrimary(for: colorScheme)))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .dashboardChromeIfNeeded(includesDashboardChrome, cornerRadius: 18)
    }
}

// MARK: - Subscription Card

struct SubscriptionCardView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var themeManager: ThemeManager
    let title: String
    let cost: String
    let billingDate: String
    let accentColor: Color
    var includesDashboardChrome = true

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.12))
                    .frame(width: 44, height: 44)

                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(accentColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(cost)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.gray)
                    .lineLimit(1)

                Text(billingDate)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(themeManager.sectionHeaderColor(for: colorScheme))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: BuxLayout.dashboardSmallCardHeight, alignment: .topLeading)
        .dashboardChromeIfNeeded(includesDashboardChrome, cornerRadius: 24)
    }
}

// MARK: - Goal Card

struct GoalCardView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var appSettingsManager: AppSettingsManager
    let title: String
    let saved: String
    let target: String
    let progress: Double
    let accentColor: Color
    var includesDashboardChrome = true

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.12))
                    .frame(width: 44, height: 44)

                Image(systemName: "target")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(accentColor)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(saved)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(themeManager.labelPrimary(for: colorScheme))

                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.8) : .black.opacity(0.8))
                    .lineLimit(1)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05))
                            .frame(height: 5)

                        Capsule()
                            .fill(accentColor)
                            .frame(width: geo.size.width * CGFloat(progress), height: 5)
                    }
                }
                .frame(height: 5)

                Text(
                    BuxLocalizedString.format(
                        "Target: %@",
                        locale: appSettingsManager.interfaceLocale,
                        target
                    )
                )
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(themeManager.labelSecondary(for: colorScheme))
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dashboardChromeIfNeeded(includesDashboardChrome, cornerRadius: 24)
    }
}

// MARK: - Insight Card

struct InsightCardView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var themeManager: ThemeManager
    let title: String
    let value: String
    let description: String
    let accentColor: Color
    var includesDashboardChrome = true

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.12))
                    .frame(width: 44, height: 44)

                Image(systemName: "sparkles")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(accentColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(accentColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                BuxCatalogDynamicText(key: title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(themeManager.labelSecondary(for: colorScheme))
                    .lineLimit(1)

                BuxCatalogDynamicText(key: description)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(themeManager.sectionHeaderColor(for: colorScheme))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: BuxLayout.dashboardSmallCardHeight, alignment: .topLeading)
        .dashboardChromeIfNeeded(includesDashboardChrome, cornerRadius: 24)
    }
}

// MARK: - Crypto Card

struct CryptoCardView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var themeManager: ThemeManager
    let iconName: String
    let iconColor: Color
    let valueText: String
    let subvalueText: String
    let trendText: String
    var includesDashboardChrome = true

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ZStack {
                Circle()
                    .fill(iconColor)
                    .frame(width: 44, height: 44)

                if iconName == "btc_symbol" {
                    Text("₿")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    Path { path in
                        path.move(to: CGPoint(x: 22, y: 11))
                        path.addLine(to: CGPoint(x: 31, y: 22))
                        path.addLine(to: CGPoint(x: 22, y: 33))
                        path.addLine(to: CGPoint(x: 13, y: 22))
                        path.closeSubpath()
                        path.move(to: CGPoint(x: 22, y: 11))
                        path.addLine(to: CGPoint(x: 22, y: 33))
                    }
                    .stroke(Color.white, lineWidth: 2)
                    .frame(width: 44, height: 44)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(valueText)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(themeManager.labelPrimary(for: colorScheme))

                HStack(spacing: 4) {
                    Text(subvalueText)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(themeManager.labelSecondary(for: colorScheme))

                    Spacer(minLength: 4)

                    Text(trendText)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color(red: 46/255, green: 204/255, blue: 113/255))
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dashboardChromeIfNeeded(includesDashboardChrome, cornerRadius: 24)
    }
}

// MARK: - Subscription Summary Card
struct SubscriptionSummaryCardView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var themeManager: ThemeManager
    let title: String
    let cost: String
    let subtext: String
    let trendText: String
    let trendColor: Color
    let icon: String
    let iconColor: Color
    var includesDashboardChrome = true

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(iconColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(cost)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                HStack(spacing: 4) {
                    BuxCatalogDynamicText(key: title)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.gray)
                        .lineLimit(1)

                    Spacer(minLength: 4)

                    Text(trendText)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(trendColor)
                        .lineLimit(1)
                }

                Text(subtext)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(themeManager.sectionHeaderColor(for: colorScheme))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: BuxLayout.dashboardSmallCardHeight, alignment: .topLeading)
        .dashboardChromeIfNeeded(includesDashboardChrome, cornerRadius: 24)
    }
}

