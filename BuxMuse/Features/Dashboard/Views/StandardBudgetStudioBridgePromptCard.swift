//
//  StandardBudgetStudioBridgePromptCard.swift
//  BuxMuse
//
//  Surfaces the optional Studio → Standard budget bridge.
//

import SwiftUI

enum StandardBudgetStudioBridgePrompt {
    static func shouldShow(settings: SettingsStore) -> Bool {
        guard settings.studioEnabled,
              settings.budgetingMode == .simple,
              !settings.standardBudgetStudioBridgePromptDismissed else {
            return false
        }
        switch settings.studioMode {
        case .simple:
            return !settings.includeSimpleStudioIncomeInBudget
        case .pro:
            return !settings.includeProStudioIncomeInBudget
        }
    }

    static func pendingIncomeThisPeriod(
        period: DateInterval,
        entries: [SimpleStudioEntry],
        invoices: [StudioInvoice],
        incomeRecords: [ExpenseRecord],
        fundingSource: IncomeFundingSource,
        studioMode: StudioMode
    ) -> Decimal {
        switch studioMode {
        case .simple:
            return StandardBudgetStudioBridge.supplementalIncome(
                period: period,
                entries: entries,
                incomeRecords: incomeRecords,
                fundingSource: fundingSource,
                studioEnabled: true,
                studioMode: .simple,
                includeInBudget: true
            ).counted
        case .pro:
            return StandardBudgetStudioBridge.proSupplementalIncome(
                period: period,
                invoices: invoices,
                incomeRecords: incomeRecords,
                fundingSource: fundingSource,
                studioEnabled: true,
                studioMode: .pro,
                includeInBudget: true
            ).counted
        }
    }
}

struct StandardBudgetStudioBridgePromptCard: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @ObservedObject private var settings = SettingsStore.shared

    let pendingAmount: Decimal
    var onEnabled: (() -> Void)?

    private var locale: Locale { appSettingsManager.interfaceLocale }

    private var isProStudio: Bool { settings.studioMode == .pro }

    private var titleKey: String {
        isProStudio ? "Connect Pro Studio to Home" : "Connect Simple Studio to Home"
    }

    private var bodyCopyKey: String {
        if isProStudio {
            return pendingAmount > 0
                ? "You logged %@ in paid Pro Studio invoices this period. Turn on Include Pro Studio income to update your home budget."
                : "Mark invoices paid in Pro Studio? Turn on Include Pro Studio income so it counts toward your home budget."
        }
        return pendingAmount > 0
            ? "You logged %@ in Simple Studio this period. Turn on Include Simple Studio income to update your home budget."
            : "Log work income in Simple Studio? Turn on Include Simple Studio income so it counts toward your home budget."
    }

    private var toggleTitleKey: String {
        isProStudio ? "Include Pro Studio income" : "Include Simple Studio income"
    }

    private var bodyText: String {
        if pendingAmount > 0 {
            return BuxLocalizedString.format(
                bodyCopyKey,
                locale: locale,
                appSettingsManager.format(pendingAmount)
            )
        }
        return BuxLocalizedString.string(bodyCopyKey, locale: locale)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "link.circle.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(themeManager.contrastAccentColor(for: colorScheme))

                VStack(alignment: .leading, spacing: 6) {
                    BuxCatalogText.text(titleKey)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))

                    Text(bodyText)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 10) {
                Button {
                    if isProStudio {
                        settings.includeProStudioIncomeInBudget = true
                    } else {
                        settings.includeSimpleStudioIncomeInBudget = true
                    }
                    settings.save()
                    onEnabled?()
                } label: {
                    BuxCatalogText.text("Turn on")
                        .font(.system(size: 13, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .tint(themeManager.contrastAccentColor(for: colorScheme))
                .accessibilityLabel(BuxLocalizedString.string(toggleTitleKey, locale: locale))

                Button {
                    settings.dismissStandardBudgetStudioBridgePrompt()
                } label: {
                    BuxCatalogText.text("Not now")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(BuxLayout.section)
        .buxListCardChrome(cornerRadius: BuxLayout.cornerCard)
    }
}
