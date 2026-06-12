//
//  InvoicePaymentSettingsView.swift
//  BuxMuse
//
//  Invoice bank account type preferences (Settings → Studio invoices).
//

import SwiftUI

struct InvoicePaymentSettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @ObservedObject private var store = SettingsStore.shared

    private var locale: Locale { appSettingsManager.interfaceLocale }

    private func loc(_ key: String) -> String {
        BuxCatalogLabel.string(key, locale: locale)
    }

    var body: some View {
        BuxThemedCardForm {
            BuxFormSection {
                Toggle(loc("Auto-detect bank account type"), isOn: $store.autoDetectInvoiceBankAccountType)
                    .tint(themeManager.contrastAccentColor(for: colorScheme))
                    .buxFormFieldPadding()
                BuxCatalogDynamicText(key: "Uses your region to pick IBAN, UK sort code, US routing, and other fields on invoices.")
                    .font(.system(size: 12))
                    .buxLabelSecondary()
                    .buxFormFieldPadding()
            }

            if !store.autoDetectInvoiceBankAccountType {
                BuxFormSection(title: "Manual account type") {
                    Picker(loc("Type"), selection: bankTypeBinding) {
                        ForEach(BankAccountType.allCases) { type in
                            Text(loc(type.displayName)).tag(type)
                        }
                    }
                    .tint(themeManager.contrastAccentColor(for: colorScheme))
                    .buxFormFieldPadding()
                }
            }
        }
        .buxCatalogNavigationTitle("Invoice payment")
        .navigationBarTitleDisplayMode(.inline)
        .environment(\.isSettingsContext, true)
        .onChange(of: store.autoDetectInvoiceBankAccountType) { _, _ in store.save() }
        .onChange(of: store.invoiceBankAccountTypeOverride) { _, _ in store.save() }
    }

    private var bankTypeBinding: Binding<BankAccountType> {
        Binding(
            get: { store.invoiceBankAccountTypeOverride ?? .iban },
            set: { store.invoiceBankAccountTypeOverride = $0 }
        )
    }
}
