//
//  SpendingTrendsDrillDownView.swift
//  BuxMuse
//
//  Category / bar-bucket drill-down list.
//

import SwiftUI

struct SpendingTrendsDrillDownView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @EnvironmentObject private var brain: BuxMuseBrain

    let context: SpendingTrendsDrillContext

    @State private var records: [ExpenseRecord] = []
    @State private var rows: [ExpenseRowDisplay] = []
    @State private var selectedRecord: ExpenseRecord?

    private var locale: Locale { appSettingsManager.interfaceLocale }

    private var loadToken: String {
        "\(context.id)-\(brain.expenseDataRevision)"
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 8) {
                if rows.isEmpty {
                    ContentUnavailableView {
                        Label {
                            BuxCatalogDynamicText(key: "No transactions")
                        } icon: {
                            Image(systemName: "tray")
                        }
                    } description: {
                        BuxCatalogDynamicText(key: "Nothing matched this period and filter.")
                    }
                    .padding(.top, 40)
                } else {
                    ForEach(rows) { row in
                        if let record = records.first(where: { $0.id == row.id }) {
                            Button {
                                selectedRecord = record
                            } label: {
                                drillRow(row: row, record: record)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.top, BuxTokens.tight)
            .padding(.bottom, BuxOverlayMetrics.scrollBottomInset)
            .buxPadExpenseDetailScrollLayout()
        }
        .buxDetailScrollChrome()
        .buxPadExpenseDetailScrollSurface()
        .background {
            BuxLandingTintBackground()
                .ignoresSafeArea()
        }
        .buxCatalogNavigationTitle(context.title)
        .navigationBarTitleDisplayMode(.inline)
        .buxDetailNavigationChrome()
        .buxInterfaceLocale()
        .task(id: loadToken) {
            let loaded = await SpendingTrendsDrillLoader.loadRecords(
                context: context,
                brain: brain,
                locale: locale
            )
            records = loaded
            rows = brain.makeExpenseRowDisplays(from: loaded)
        }
        .fullScreenCover(item: $selectedRecord) { record in
            ExpenseDetailView(record: record, brain: brain, settingsManager: appSettingsManager) {}
                .environmentObject(themeManager)
                .environmentObject(appSettingsManager)
                .environment(\.expensesEnhancedTint, true)
                .buxThemedSheetContent()
        }
    }

    private func drillRow(row: ExpenseRowDisplay, record: ExpenseRecord) -> some View {
        HStack(spacing: 12) {
            ExpenseLedgerAvatarView(record: record, size: 40)
                .environmentObject(brain)

            VStack(alignment: .leading, spacing: 2) {
                Text(row.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(themeManager.labelPrimary(for: colorScheme))
                    .lineLimit(1)
                Text(row.category ?? row.merchant ?? "")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Text(row.amountFormatted)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(themeManager.labelPrimary(for: colorScheme))

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(themeManager.chevronMuted(for: colorScheme))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .expensesThemedCardChrome(cornerRadius: 16)
    }
}
