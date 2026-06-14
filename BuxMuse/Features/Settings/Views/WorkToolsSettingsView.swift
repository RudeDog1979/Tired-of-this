//
//  WorkToolsSettingsView.swift
//  BuxMuse
//
//  Studio work utilities — cash, barter, mileage, invoices.
//

import SwiftUI

struct WorkToolsSettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @ObservedObject private var store = SettingsStore.shared

    var body: some View {
        BuxThemedCardForm {
            BuxFormSection(title: "Cash & trade") {
                NavigationLink {
                    StudioCashBarterSettingsView()
                        .environmentObject(themeManager)
                } label: {
                    settingsLinkRow(
                        title: "Cash & barter",
                        subtitle: cashBarterSubtitle,
                        icon: "banknote.fill"
                    )
                }
            }

            BuxFormSection(title: "Invoices & travel") {
                NavigationLink {
                    InvoicePaymentSettingsView()
                } label: {
                    settingsLinkRow(
                        title: "Invoice payment",
                        subtitle: invoicePaymentSubtitle,
                        icon: "building.columns.fill"
                    )
                }

                BuxFormRowDivider()

                NavigationLink {
                    MileageSettingsView()
                } label: {
                    settingsLinkRow(
                        title: "Mileage log",
                        subtitle: store.autoLocationForMileage
                            ? BuxCatalogLabel.string("On", locale: appSettingsManager.interfaceLocale)
                            : BuxCatalogLabel.string("Off", locale: appSettingsManager.interfaceLocale),
                        icon: "car.fill"
                    )
                }
            }
        }
        .buxCatalogNavigationTitle("Work tools")
        .navigationBarTitleDisplayMode(.inline)
        .environment(\.isSettingsContext, true)
    }

    private func settingsLinkRow(title: String, subtitle: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                BuxCatalogText.text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .buxLabelSecondary()
            }
            Spacer()
            BuxChevron()
        }
        .buxFormFieldPadding()
    }

    private var cashBarterSubtitle: String {
        let parts = [
            store.dualCashDrawerEnabled ? BuxCatalogLabel.string("Cash on", locale: appSettingsManager.interfaceLocale) : nil,
            store.barterLoggerEnabled ? BuxCatalogLabel.string("Barter on", locale: appSettingsManager.interfaceLocale) : nil
        ].compactMap { $0 }
        if parts.isEmpty {
            return BuxCatalogLabel.string("Off", locale: appSettingsManager.interfaceLocale)
        }
        return parts.joined(separator: " · ")
    }

    private var invoicePaymentSubtitle: String {
        store.autoDetectInvoiceBankAccountType
            ? BuxCatalogLabel.string("Auto", locale: appSettingsManager.interfaceLocale)
            : (store.invoiceBankAccountTypeOverride?.displayName ?? BuxCatalogLabel.string("Manual", locale: appSettingsManager.interfaceLocale))
    }
}
