//
//  AmountField.swift
//  BuxMuse
//  Features/ExpenseInput/
//
//  Intelligent decimal amount input field aligned with BuxMuse design system tokens.
//

import SwiftUI

struct AmountField: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var appSettingsManager: AppSettingsManager
    @Binding var amountString: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Amount")
                .buxSectionLabelStyle(color: themeManager.sectionHeaderColor(for: colorScheme))
            
            HStack(spacing: 8) {
                Text(appSettingsManager.selectedCurrency.symbol)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(themeManager.current.accentColor)
                
                TextField("0.00", text: $amountString)
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                    .keyboardType(.decimalPad)
                    .tint(themeManager.current.accentColor)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .expensesThemedCardChrome(cornerRadius: 16)
            .shadow(color: colorScheme == .dark ? .clear : Color.black.opacity(0.01), radius: 4, x: 0, y: 2)
        }
    }
}
