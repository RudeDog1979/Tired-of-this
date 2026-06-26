//
//  DualCashDrawerWidget.swift
//  BuxMuse
//
//  Features/Dashboard/Views/
//  Premium "leather wallet" style card to track physical cash drawer balances.
//

import SwiftUI

struct DualCashDrawerWidget: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @EnvironmentObject private var navigationCoordinator: NavigationCoordinator
    @EnvironmentObject private var brain: BuxMuseBrain
    @ObservedObject private var store = SettingsStore.shared
    
    @State private var showingQuickCashSheet = false
    @State private var quickCashIsIncome = true
    
    var body: some View {
        Button(action: {
            showingQuickCashSheet = true
        }) {
            VStack(alignment: .leading, spacing: 14) {
                // Header
                HStack(spacing: 8) {
                    Image(systemName: "banknote.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.green)
                    
                    BuxCatalogText.text("Cash Drawer")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                    
                    Spacer()
                    
                    Image(systemName: "arrow.up.left.and.arrow.down.right.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                }
                
                // Balances Grid
                HStack(spacing: 20) {
                    // Primary local cash
                    VStack(alignment: .leading, spacing: 4) {
                        Text(
                            BuxLocalizedString.format(
                                "%@ Cash",
                                locale: appSettingsManager.interfaceLocale,
                                store.primaryLocalCurrency
                            )
                        )
                            .font(.system(size: 11, weight: .bold))
                            .buxLabelSecondary()
                        
                        Text(formatAmount(store.cashLocalBalanceValue, code: store.primaryLocalCurrency))
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                    }
                    
                    Divider()
                        .frame(height: 30)
                        .opacity(0.12)
                    
                    // Secondary USD cash
                    VStack(alignment: .leading, spacing: 4) {
                        Text(
                            BuxLocalizedString.format(
                                "%@ Cash",
                                locale: appSettingsManager.interfaceLocale,
                                store.secondaryTradingCurrency
                            )
                        )
                            .font(.system(size: 11, weight: .bold))
                            .buxLabelSecondary()
                        
                        Text(formatAmount(store.cashSecondaryBalanceValue, code: store.secondaryTradingCurrency))
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                    }
                }
                
                // Interactive Buttons
                HStack(spacing: 12) {
                    Button(action: {
                        quickCashIsIncome = true
                        showingQuickCashSheet = true
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 12, weight: .bold))
                            BuxCatalogText.text("Add Cash")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .foregroundColor(.green)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        quickCashIsIncome = false
                        showingQuickCashSheet = true
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 12, weight: .bold))
                            BuxCatalogText.text("Spend Cash")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .foregroundColor(.red)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(18)
            .background(
                ZStack {
                    if store.solarContrastModeEnabled {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.white)
                            .stroke(Color.black, lineWidth: 2)
                    } else {
                        // High fidelity textured leather look
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(.systemBackground).opacity(0.85))
                            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
                        
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                LinearGradient(
                                    colors: [themeManager.current.accentColor.opacity(0.2), .green.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
                }
            )
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingQuickCashSheet) {
            QuickCashDrawerAdjustSheet(isIncome: $quickCashIsIncome)
                .environmentObject(themeManager)
                .environmentObject(appSettingsManager)
                .environmentObject(brain)
        }
    }
    
    private func formatAmount(_ val: Double, code: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: val)) ?? "\(code) \(val)"
    }
}

// MARK: - Quick Cash Drawer Adjustment Sheet

struct QuickCashDrawerAdjustSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @EnvironmentObject private var brain: BuxMuseBrain
    @ObservedObject private var store = SettingsStore.shared
    
    @Binding var isIncome: Bool
    @State private var selectedCurrencyIsPrimary = true
    @State private var amountText = ""
    @State private var noteText = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header Segment picker
                Picker(BuxCatalogLabel.string("Adjustment type", locale: appSettingsManager.interfaceLocale), selection: $isIncome) {
                    BuxCatalogText.text("Receive Cash (Income)").tag(true)
                    BuxCatalogText.text("Spend Cash (Expense)").tag(false)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                
                // Select Wallet drawer
                VStack(alignment: .leading, spacing: 8) {
                    BuxCatalogText.text("SELECT CASH DRAWER")
                        .font(.system(size: 11, weight: .bold))
                        .textCase(.uppercase)
                        .foregroundColor(.gray)
                        .padding(.horizontal)
                    
                    HStack(spacing: 12) {
                        Button(action: { selectedCurrencyIsPrimary = true }) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(
                                    BuxLocalizedString.format(
                                        "%@ Wallet",
                                        locale: appSettingsManager.interfaceLocale,
                                        store.primaryLocalCurrency
                                    )
                                )
                                    .font(.system(size: 14, weight: .bold))
                                Text(
                                    BuxLocalizedString.format(
                                        "Balance: %@",
                                        locale: appSettingsManager.interfaceLocale,
                                        String(format: "%.2f", store.cashLocalBalanceValue)
                                    )
                                )
                                    .font(.system(size: 11))
                                    .opacity(0.7)
                            }
                            .foregroundColor(selectedCurrencyIsPrimary ? .white : .primary)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(selectedCurrencyIsPrimary ? themeManager.current.accentColor : Color.gray.opacity(0.12))
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: { selectedCurrencyIsPrimary = false }) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(
                                    BuxLocalizedString.format(
                                        "%@ Wallet",
                                        locale: appSettingsManager.interfaceLocale,
                                        store.secondaryTradingCurrency
                                    )
                                )
                                    .font(.system(size: 14, weight: .bold))
                                Text(
                                    BuxLocalizedString.format(
                                        "Balance: %@",
                                        locale: appSettingsManager.interfaceLocale,
                                        String(format: "%.2f", store.cashSecondaryBalanceValue)
                                    )
                                )
                                    .font(.system(size: 11))
                                    .opacity(0.7)
                            }
                            .foregroundColor(!selectedCurrencyIsPrimary ? .white : .primary)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(!selectedCurrencyIsPrimary ? themeManager.current.accentColor : Color.gray.opacity(0.12))
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal)
                }
                
                // Input Cash Amount
                VStack(alignment: .leading, spacing: 8) {
                    BuxCatalogText.text("ENTER CASH AMOUNT")
                        .font(.system(size: 11, weight: .bold))
                        .textCase(.uppercase)
                        .foregroundColor(.gray)
                        .padding(.horizontal)
                    
                    HStack {
                        Text("$")
                            .font(.system(size: 24, weight: .black))
                        
                        TextField("0.00", text: $amountText)
                            .font(.system(size: 24, weight: .black))
                            .keyboardType(.decimalPad)
                            .tint(themeManager.contrastAccentColor(for: colorScheme))
                    }
                    .padding()
                    .background(Color.gray.opacity(0.08))
                    .cornerRadius(16)
                    .padding(.horizontal)
                }
                
                // Optional Note
                VStack(alignment: .leading, spacing: 8) {
                    BuxCatalogText.text("TRANSACTION NOTES")
                        .font(.system(size: 11, weight: .bold))
                        .textCase(.uppercase)
                        .foregroundColor(.gray)
                        .padding(.horizontal)
                    
                    TextField(BuxCatalogLabel.string("e.g. Street vendor, taxi fare, project deposit", locale: appSettingsManager.interfaceLocale), text: $noteText)
                        .padding()
                        .background(Color.gray.opacity(0.08))
                        .cornerRadius(12)
                        .padding(.horizontal)
                }
                
                Spacer()
                
                // Submit Button
                Button(action: logCashTransaction) {
                    HStack {
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                        BuxCatalogText.text("Log Cash Transaction")
                            .font(.system(size: 16, weight: .black))
                        Spacer()
                    }
                    .foregroundColor(.white)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(amountText.isEmpty ? Color.gray.opacity(0.4) : themeManager.current.accentColor)
                    )
                    .padding(.horizontal)
                }
                .disabled(amountText.isEmpty)
                .buttonStyle(.plain)
            }
            .padding(.vertical)
            .buxCatalogNavigationTitle("Log Physical Cash")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(BuxCatalogLabel.string("Cancel", locale: appSettingsManager.interfaceLocale)) { dismiss() }
                }
            }
        }
    }
    
    private func logCashTransaction() {
        guard let amount = Decimal(string: amountText) else { return }
        let amountVal = isIncome ? amount : -amount
        let currencyCode = selectedCurrencyIsPrimary ? store.primaryLocalCurrency : store.secondaryTradingCurrency
        
        // Log transaction inside standard brain
        let t = Transaction(
            id: UUID(),
            date: Date(),
            amount: MoneyAmount(value: amountVal, currencyCode: currencyCode),
            merchantName: isIncome ? "Cash Deposit" : (noteText.isEmpty ? "Cash Spend" : noteText),
            category: isIncome ? .income : .other,
            notes: noteText,
            hustleId: HustleManager.shared.selectedHustleId,
            paymentMethod: selectedCurrencyIsPrimary ? "Cash (\(store.primaryLocalCurrency))" : "Cash (\(store.secondaryTradingCurrency))"
        )
        
        // Update local settings physical balance totals in hand
        if selectedCurrencyIsPrimary {
            store.cashLocalBalanceValue += NSDecimalNumber(decimal: amountVal).doubleValue
        } else {
            store.cashSecondaryBalanceValue += NSDecimalNumber(decimal: amountVal).doubleValue
        }
        
        Task { @MainActor in
            _ = try? brain.saveExpense(t)
            NotificationCenter.default.post(name: .buxMuseFinancialDataDidChange, object: nil)
            dismiss()
        }
    }
}
