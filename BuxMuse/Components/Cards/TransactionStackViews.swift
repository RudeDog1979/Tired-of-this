//
//  TransactionStackViews.swift
//  BuxMuse
//  Components/Cards/
//
//  Recent transactions list (last 5) and legacy stack types.
//

import SwiftUI

// MARK: - Recent Transactions (Dashboard)

struct RecentTransactionsSectionView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    let transactions: [Transaction]
    let onSeeMore: () -> Void

    private var cardColor: Color {
        themeManager.cardFill(for: colorScheme)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BuxLayout.section) {
            Text("Recent transactions")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(colorScheme == .dark ? .white : Color(red: 26/255, green: 28/255, blue: 32/255))

            if transactions.isEmpty {
                Text("No transactions yet. Add an expense to see activity here.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.gray)
            } else {
                LazyVStack(spacing: BuxLayout.tight + 2) {
                    ForEach(transactions) { tx in
                        recentRow(for: tx)
                    }
                }
            }

            Button(action: onSeeMore) {
                HStack(spacing: 6) {
                    Text("See more")
                        .font(.system(size: 14, weight: .semibold))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundColor(themeManager.current.accentColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .buttonStyle(BuxMicroShrinkStyle())
        }
    }

    private func recentRow(for tx: Transaction) -> some View {
        HStack(spacing: 14) {
            AsyncMerchantLogoView(merchantName: tx.merchantName, size: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(tx.merchantName)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(colorScheme == .dark ? .white : Color(red: 26/255, green: 28/255, blue: 32/255))
                    .lineLimit(1)

                Text(tx.category.displayName)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(themeManager.current.accentColor)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(appSettingsManager.format(tx.amount.value))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(colorScheme == .dark ? .white : Color(red: 26/255, green: 28/255, blue: 32/255))

                Text(tx.date, style: .date)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .buxCardOutline(themeManager: themeManager, colorScheme: colorScheme, cornerRadius: 18)
    }
}

// MARK: - Legacy stack (retained for reference; unused on dashboard)

struct RecentTransactionsStackView: View {
    @Environment(\.colorScheme) var colorScheme
    @Binding var isTransactionsExpanded: Bool
    var transactionNamespace: Namespace.ID

    let spendingCategories = [
        SpendingCategoryItem(title: "Transfer to card", amount: "$4 321,88", percentage: "34,52%", transactionsCount: 24, icon: "creditcard.fill", color: Color(red: 90/255, green: 85/255, blue: 245/255)),
        SpendingCategoryItem(title: "Products", amount: "$2 553,31", percentage: "20,39%", transactionsCount: 12, icon: "cart.fill", color: .orange),
        SpendingCategoryItem(title: "Beauty and health", amount: "$1 403,29", percentage: "11,21%", transactionsCount: 9, icon: "heart.fill", color: .pink)
    ]

    var body: some View {
        EmptyView()
    }
}

struct ExpandedTransactionStackView: View {
    @Binding var isTransactionsExpanded: Bool
    var transactionNamespace: Namespace.ID

    var body: some View {
        EmptyView()
    }
}
