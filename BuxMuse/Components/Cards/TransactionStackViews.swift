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
    @Environment(\.dashboardEnhancedTint) private var dashboardEnhancedTint
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @EnvironmentObject private var brain: BuxMuseBrain

    let transactions: [DashboardRecentTransaction]
    let onSeeMore: () -> Void

    @State private var displayedTransactions: [DashboardRecentTransaction] = []

    private var cardColor: Color {
        themeManager.cardFill(for: colorScheme)
    }

    private var cardStroke: Color {
        themeManager.subtleCardStroke(for: colorScheme)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BuxLayout.section) {
            BuxCatalogText.text("Recent transactions")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(themeManager.labelPrimary(for: colorScheme))

            if displayedTransactions.isEmpty {
                BuxCatalogText.text("No transactions yet. Add an expense to see activity here.")
                    .font(.system(size: 13, weight: .medium))
                    .buxLabelSecondary()
            } else {
                VStack(spacing: BuxLayout.tight + 2) {
                    ForEach(displayedTransactions) { tx in
                        recentRow(for: tx)
                    }
                }
            }

            Button(action: onSeeMore) {
                HStack(spacing: 6) {
                    BuxCatalogText.text("See more")
                        .font(.system(size: 14, weight: .semibold))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .buttonStyle(BuxMicroShrinkStyle())
        }
        .onAppear {
            if displayedTransactions != transactions {
                displayedTransactions = transactions
            }
        }
        .onChange(of: transactions) { _, newValue in
            guard newValue != displayedTransactions else { return }
            displayedTransactions = newValue
        }
    }

    private func recentRow(for tx: DashboardRecentTransaction) -> some View {
        HStack(spacing: 14) {
            AsyncMerchantLogoView(merchantName: dashboardLogoName(for: tx), size: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(tx.localizedMerchantLabel(locale: appSettingsManager.interfaceLocale))
                    .font(.body.weight(.medium))
                    .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                    .lineLimit(1)
                    .textCase(nil)

                Text(tx.category.localizedDisplayName(locale: appSettingsManager.interfaceLocale))
                    .font(.footnote)
                    .textCase(nil)
                    .foregroundColor(
                        EmotionalTagAppearance.accent(for: tx.emotion, colorScheme: colorScheme)
                            ?? themeManager.contrastAccentColor(for: colorScheme)
                    )
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(appSettingsManager.format(tx.amount.value))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(themeManager.labelPrimary(for: colorScheme))

                Text(tx.date, style: .date)
                    .font(.system(size: 11, weight: .medium))
                    .buxLabelSecondary()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .modifier(RecentTransactionRowChromeModifier(
            transaction: tx,
            cardColor: cardColor,
            cardStroke: cardStroke
        ))
    }

    private func dashboardLogoName(for tx: DashboardRecentTransaction) -> String {
        if let record = (try? brain.fetchExpenseRecord(id: tx.id)),
           let linked = brain.merchantLogoName(for: record) {
            return linked
        }
        return tx.merchantName
    }
}

// MARK: - Row chrome

private struct RecentTransactionRowChromeModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dashboardEnhancedTint) private var dashboardEnhancedTint
    let transaction: DashboardRecentTransaction
    let cardColor: Color
    let cardStroke: Color

    func body(content: Content) -> some View {
        if dashboardEnhancedTint,
           transaction.emotion == nil {
            content.buxMaterialCardChrome(.outlined, cornerRadius: BuxMaterialChrome.cardCornerRadius)
        } else if let emotion = transaction.emotion, let symbol = transaction.emotionSymbol {
            content.background {
                EmotionalListCardChrome(
                    cornerRadius: BuxMaterialChrome.cardCornerRadius,
                    isDark: colorScheme == .dark,
                    base: cardColor,
                    fallbackStroke: cardStroke,
                    emotionId: emotion,
                    symbol: symbol
                )
                .equatable()
            }
        } else {
            content.background {
                PlainExpenseListCardChrome(
                    cornerRadius: BuxMaterialChrome.cardCornerRadius,
                    base: cardColor,
                    stroke: cardStroke
                )
                .equatable()
            }
        }
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
