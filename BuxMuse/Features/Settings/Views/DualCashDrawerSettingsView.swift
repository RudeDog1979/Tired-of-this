//
//  DualCashDrawerSettingsView.swift
//  BuxMuse
//
//  Features/Settings/Views/
//  Beautiful console for managing the Dual-Cash Drawer (USD & Local cash ledgers).
//

import SwiftUI

struct DualCashDrawerSettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @ObservedObject private var store = SettingsStore.shared
    
    @State private var primaryInput = ""
    @State private var secondaryInput = ""
    @State private var localBalanceInput = ""
    @State private var secondaryBalanceInput = ""
    @State private var showSavedAlert = false

    private var locale: Locale { appSettingsManager.interfaceLocale }

    private func loc(_ key: String) -> String {
        BuxCatalogLabel.string(key, locale: locale)
    }
    
    var body: some View {
        BuxThemedCardForm {
            // Section 1: Dashboard Drawer Tier Banner
            cashDrawerTierBanner
            
            // Section 2: Main Activation toggle
            BuxFormSection(title: "Status & activation") {
                Toggle(isOn: $store.dualCashDrawerEnabled.animation(.spring(response: 0.3, dampingFraction: 0.75))) {
                    VStack(alignment: .leading, spacing: 2) {
                        BuxCatalogDynamicText(key: "Enable cash drawer")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                        BuxCatalogDynamicText(key: "Track physical paper money balances")
                            .font(.system(size: 11, weight: .medium))
                            .buxLabelSecondary()
                    }
                }
                .tint(themeManager.current.accentColor)
                .buxFormFieldPadding()
            }
            
            if store.dualCashDrawerEnabled {
                // Section 3: Currency Setup
                BuxFormSection(title: "Currency configuration") {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 6) {
                                BuxCatalogDynamicText(key: "Primary local currency")
                                    .font(.system(size: 12, weight: .bold))
                                    .buxLabelSecondary()
                                
                                TextField(loc("e.g. DOP, USD, EUR"), text: $primaryInput)
                                    .font(.system(size: 15, weight: .semibold))
                                    .tint(themeManager.current.accentColor)
                                    .textFieldStyle(.plain)
                                    .onChange(of: primaryInput) { _, val in
                                        store.primaryLocalCurrency = val.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
                                    }
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .leading, spacing: 6) {
                                BuxCatalogDynamicText(key: "Secondary trade currency")
                                    .font(.system(size: 12, weight: .bold))
                                    .buxLabelSecondary()
                                
                                TextField(loc("e.g. USD, DOP"), text: $secondaryInput)
                                    .font(.system(size: 15, weight: .semibold))
                                    .tint(themeManager.current.accentColor)
                                    .textFieldStyle(.plain)
                                    .onChange(of: secondaryInput) { _, val in
                                        store.secondaryTradingCurrency = val.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
                                    }
                            }
                        }
                        .buxFormFieldPadding()
                    }
                }
                
                // Section 4: Seed Drawer Balances
                BuxFormSection(title: "Seed physical cash balances") {
                    VStack(alignment: .leading, spacing: 14) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(
                                BuxLocalizedString.format(
                                    "Current %@ Cash in Wallet",
                                    locale: appSettingsManager.interfaceLocale,
                                    store.primaryLocalCurrency
                                )
                            )
                                .font(.system(size: 12, weight: .bold))
                                .buxLabelSecondary()
                            
                            HStack {
                                Text("$")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                                
                                TextField("0.00", text: $localBalanceInput)
                                    .font(.system(size: 16, weight: .bold))
                                    .keyboardType(.decimalPad)
                                    .textFieldStyle(.plain)
                                    .tint(themeManager.current.accentColor)
                                    .onChange(of: localBalanceInput) { _, val in
                                        if let d = Double(val) {
                                            store.cashLocalBalanceValue = d
                                        }
                                    }
                            }
                        }
                        .buxFormFieldPadding()
                        
                        BuxFormRowDivider()
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(
                                BuxLocalizedString.format(
                                    "Current %@ Cash in Wallet",
                                    locale: appSettingsManager.interfaceLocale,
                                    store.secondaryTradingCurrency
                                )
                            )
                                .font(.system(size: 12, weight: .bold))
                                .buxLabelSecondary()
                            
                            HStack {
                                Text("$")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                                
                                TextField("0.00", text: $secondaryBalanceInput)
                                    .font(.system(size: 16, weight: .bold))
                                    .keyboardType(.decimalPad)
                                    .textFieldStyle(.plain)
                                    .tint(themeManager.current.accentColor)
                                    .onChange(of: secondaryBalanceInput) { _, val in
                                        if let d = Double(val) {
                                            store.cashSecondaryBalanceValue = d
                                        }
                                    }
                            }
                        }
                        .buxFormFieldPadding()
                    }
                }
            }
        }
        .buxCatalogNavigationTitle("Dual-cash drawer")
        .navigationBarTitleDisplayMode(.inline)
        .environment(\.isSettingsContext, true)
        .onAppear {
            primaryInput = store.primaryLocalCurrency
            secondaryInput = store.secondaryTradingCurrency
            localBalanceInput = String(format: "%.2f", store.cashLocalBalanceValue)
            secondaryBalanceInput = String(format: "%.2f", store.cashSecondaryBalanceValue)
        }
    }
    
    private var cashDrawerTierBanner: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: "banknote.fill")
                .font(.system(size: 32))
                .foregroundColor(.green)
            
            VStack(alignment: .leading, spacing: 3) {
                BuxCatalogDynamicText(key: "Cash drawer")
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                
                BuxCatalogDynamicText(key: "Segregate dynamic physical wallets for informal, spotty internet environments.")
                    .font(.system(size: 12, weight: .medium))
                    .buxLabelSecondary()
            }
            
            Spacer()
        }
        .padding(BuxLayout.section)
        .buxFormSectionCard()
    }
}
