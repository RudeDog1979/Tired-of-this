//
//  SpendingTrendsMerchantDetailView.swift
//  BuxMuse
//

import SwiftUI

struct SpendingTrendsMerchantDetailView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @EnvironmentObject private var brain: BuxMuseBrain

    let context: SpendingTrendsDrillContext

    @State private var records: [ExpenseRecord] = []
    @State private var selectedRecord: ExpenseRecord?

    private var locale: Locale { appSettingsManager.interfaceLocale }

    private var merchantName: String {
        context.merchantName ?? context.title
    }

    private var latestRecord: ExpenseRecord? {
        records.first
    }

    private var historyRecords: [ExpenseRecord] {
        guard records.count > 1 else { return [] }
        return Array(records.dropFirst())
    }

    private var periodTotal: Double {
        records.reduce(0) { $0 + $1.spendingAmountDouble }
    }

    private var loadToken: String {
        "\(context.id)-\(brain.expenseDataRevision)"
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: BuxLayout.section) {
                merchantHeaderCard

                if !records.isEmpty {
                    periodTotalCard
                }

                if let latestRecord {
                    featuredTransactionCard(latestRecord)
                }

                if !historyRecords.isEmpty {
                    transactionHistorySection
                }

                if records.isEmpty {
                    ContentUnavailableView {
                        Label {
                            BuxCatalogDynamicText(key: "No transactions")
                        } icon: {
                            Image(systemName: "tray")
                        }
                    } description: {
                        BuxCatalogDynamicText(key: "Nothing matched this merchant in this period.")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, BuxLayout.loose)
                }
            }
            .padding(.vertical, BuxLayout.section)
            .padding(.bottom, BuxOverlayMetrics.scrollBottomInset)
            .buxPadExpenseDetailScrollLayout()
        }
        .buxDetailScrollChrome()
        .buxPadExpenseDetailScrollSurface()
        .background {
            BuxLandingTintBackground()
                .ignoresSafeArea()
        }
        .navigationBarTitleDisplayMode(.inline)
        .buxDetailNavigationChrome()
        .buxInterfaceLocale()
        .task(id: loadToken) {
            records = await SpendingTrendsDrillLoader.loadRecords(
                context: context,
                brain: brain,
                locale: locale
            )
        }
        .fullScreenCover(item: $selectedRecord) { record in
            ExpenseDetailView(record: record, brain: brain, settingsManager: appSettingsManager) {}
                .environmentObject(themeManager)
                .environmentObject(appSettingsManager)
                .environment(\.expensesEnhancedTint, true)
                .buxThemedSheetContent()
        }
    }

    // MARK: - Header

    private var merchantHeaderCard: some View {
        VStack(spacing: 16) {
            AsyncMerchantLogoView(merchantName: merchantName, size: 56)

            VStack(spacing: 4) {
                Text(merchantName)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(themeManager.labelPrimary(for: colorScheme))
                    .multilineTextAlignment(.center)

                if let category = SpendingTrendsDrillLoader.dominantCategory(
                    for: records,
                    brain: brain,
                    locale: locale
                ) {
                    Text(category)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(themeManager.labelSecondary(for: colorScheme))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .buxDetailSectionCard()
    }

    // MARK: - Total

    private var periodTotalCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            BuxCatalogDynamicText(key: periodTotalLabelKey)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(themeManager.labelSecondary(for: colorScheme))

            Text(appSettingsManager.format(Decimal(periodTotal)))
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(themeManager.labelPrimary(for: colorScheme))
        }
        .buxDetailSectionCard()
    }

    private var periodTotalLabelKey: String {
        switch context.period {
        case .week:
            return "Total This Week"
        case .year:
            return "Total This Year"
        case .month, .none:
            return "Total This Month"
        }
    }

    // MARK: - Featured

    private func featuredTransactionCard(_ record: ExpenseRecord) -> some View {
        Button {
            selectedRecord = record
        } label: {
            transactionRowContent(for: record)
        }
        .buttonStyle(.plain)
        .buxDetailRowCard()
    }

    // MARK: - History

    private var transactionHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            BuxDetailSectionHeader(title: "Transaction History")

            VStack(spacing: 0) {
                ForEach(Array(historyRecords.enumerated()), id: \.element.id) { index, record in
                    if index > 0 {
                        BuxFormRowDivider()
                            .padding(.leading, BuxDetailStyle.cardPadding)
                    }
                    Button {
                        selectedRecord = record
                    } label: {
                        transactionRowContent(for: record)
                            .padding(.horizontal, BuxDetailStyle.cardPadding)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.plain)
                }
            }
            .buxDetailCard(cornerRadius: BuxDetailStyle.rowCardRadius)
        }
    }

    // MARK: - Row

    private func transactionRowContent(for record: ExpenseRecord) -> some View {
        let rowCurrency = AppSettingsManager.currencySetting(for: record.currencyCode)
        let amountText = ExpenseDisplayL10n.signedOutflow(
            amount: record.spendingAmountDouble,
            currency: rowCurrency
        )
        let label = ExpenseDisplayL10n.label(record.name, locale: locale)

        return HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(formattedDrillDate(record.date))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(themeManager.labelPrimary(for: colorScheme))

                Text(label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(themeManager.labelSecondary(for: colorScheme))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }

            Spacer(minLength: 8)

            HStack(spacing: 6) {
                Text(amountText)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(themeManager.labelPrimary(for: colorScheme))

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(themeManager.chevronMuted(for: colorScheme))
            }
        }
    }

    private func formattedDrillDate(_ date: Date) -> String {
        BuxDisplayDate.transactionDay(from: date, locale: locale)
    }
}
