//
//  DashboardDebtSummaryCard.swift
//  BuxMuse
//  Features/Debt/Views/
//
//  Home dashboard summary when active debts exist.
//

import SwiftUI

struct DashboardDebtSummaryCard: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @EnvironmentObject private var debtEngine: DebtEngine
    @EnvironmentObject private var navigationCoordinator: NavigationCoordinator
    @ObservedObject private var store = SettingsStore.shared

    var body: some View {
        if store.consumerDebtEnabled, !debtEngine.activeDebts.isEmpty {
            Button {
                navigationCoordinator.openDebtHub()
            } label: {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .center, spacing: 12) {
                        if debtEngine.balanceBreakdown.count > 1 {
                            DebtBreakdownDonutChart(
                                breakdown: debtEngine.balanceBreakdown.map { ($0.name, $0.amount) }
                            )
                            .frame(width: 44, height: 44)
                        } else if let leadDebt = debtEngine.activeDebts.first {
                            DebtLogoView(debt: leadDebt, size: 40)
                        }

                        HStack(spacing: 6) {
                            Image(systemName: "creditcard.fill")
                                .font(.system(size: 10))
                                .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))

                            BuxCatalogText.text("Consumer debt")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(themeManager.labelSecondary(for: colorScheme))
                        }

                        Spacer(minLength: 0)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        BuxCatalogText.text("Total owed")
                            .font(.system(size: 12, weight: .semibold))
                            .buxLabelSecondary()

                        Text(appSettingsManager.format(debtEngine.totalOwed))
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.45)
                            .allowsTightening(true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    HStack(spacing: 12) {
                        metricChip(
                            titleKey: "Paid this month",
                            value: appSettingsManager.format(debtEngine.paidThisMonth)
                        )

                        if let nextDue = debtEngine.nextDueDate {
                            metricChip(
                                titleKey: "Next due",
                                value: BuxDisplayDate.monthDayYear(from: nextDue, locale: appSettingsManager.interfaceLocale)
                            )
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(BuxTokens.section)
                .dashboardMaterialCardChrome(.outlined)
            }
            .buttonStyle(BuxDashboardCardButtonStyle())
        }
    }

    private func metricChip(titleKey: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            BuxCatalogText.text(titleKey)
                .font(.system(size: 10, weight: .semibold))
                .buxLabelSecondary()
            Text(value)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
