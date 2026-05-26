//
//  SubscriptionCategoryDetailView.swift
//  BuxMuse
//  Features/SubscriptionHub/
//
//  Categorical proportional breakdown of subscription expenses with visual trends.
//

import SwiftUI

struct SubscriptionCategoryDetailView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    let subscriptions: [SubscriptionInfo]

    @State private var cachedBreakdown: [CategorySubscriptionGroup] = []

    var body: some View {
        VStack(alignment: .leading, spacing: BuxLayout.tight + 6) {
            SubscriptionHubSectionHeader(title: "CATEGORY BREAKDOWN")

            VStack(spacing: BuxLayout.section) {
                if cachedBreakdown.isEmpty {
                    Text("No category subscription metrics available.")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, BuxLayout.section)
                } else {
                    HStack(spacing: 4) {
                        ForEach(cachedBreakdown) { group in
                            RoundedRectangle(cornerRadius: 3)
                                .fill(categoryColor(group.category))
                                .frame(height: 8)
                                .frame(maxWidth: .infinity)
                        }
                    }

                    VStack(spacing: BuxLayout.section) {
                        ForEach(cachedBreakdown) { group in
                            HStack(spacing: BuxLayout.section) {
                                ZStack {
                                    Circle()
                                        .fill(categoryColor(group.category).opacity(0.12))
                                        .frame(width: 36, height: 36)

                                    Image(systemName: categoryIcon(group.category))
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(categoryColor(group.category))
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(group.category.displayName)
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(colorScheme == .dark ? .white : Color(red: 26/255, green: 28/255, blue: 32/255))
                                        .lineLimit(1)

                                    Text("\(group.subscriptionsCount) Active • \(Int(round(group.proportion)))% of total")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(.gray)
                                        .lineLimit(1)
                                }

                                Spacer(minLength: 0)

                                Text(appSettingsManager.format(group.totalCost.value))
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(colorScheme == .dark ? .white : .black)
                            }
                        }
                    }
                }
            }
            .padding(SubscriptionHubStyle.cardPadding)
            .subscriptionHubCard()
        }
        .onAppear { refreshCache() }
        .onChange(of: subscriptions.count) { _, _ in refreshCache() }
    }

    private func refreshCache() {
        cachedBreakdown = SubscriptionHubSectionCache.categoryBreakdown(
            from: subscriptions,
            currencyCode: appSettingsManager.selectedCurrency.id
        )
    }

    private func categoryColor(_ category: TransactionCategory) -> Color {
        switch category {
        case .groceries: return .green
        case .restaurants: return .orange
        case .transport: return .blue
        case .subscriptions: return themeManager.current.accentColor
        case .housing: return .red
        case .income: return .mint
        case .other: return .purple
        }
    }

    private func categoryIcon(_ category: TransactionCategory) -> String {
        switch category {
        case .groceries: return "cart.fill"
        case .restaurants: return "fork.knife"
        case .transport: return "car.fill"
        case .subscriptions: return "arrow.triangle.2.circlepath"
        case .housing: return "house.fill"
        case .income: return "briefcase.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }
}

struct CategorySubscriptionGroup: Identifiable {
    var id: String { category.rawValue }
    let category: TransactionCategory
    let totalCost: MoneyAmount
    let proportion: Double
    let subscriptionsCount: Int
}
