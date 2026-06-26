//
//  AmountField.swift
//  BuxMuse
//  Features/ExpenseInput/
//
//  Intelligent decimal amount input field aligned with BuxMuse design system tokens.
//

import SwiftUI

enum AmountFieldKind {
    case expense
    case income
}

struct AmountField: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var appSettingsManager: AppSettingsManager
    @Binding var amountString: String
    var kind: AmountFieldKind = .expense

    private var accent: Color {
        switch kind {
        case .expense: return themeManager.contrastAccentColor(for: colorScheme)
        case .income: return Color.mint
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            BuxCatalogText.text(kind == .income ? "Income amount" : "Amount")
                .buxSectionLabelStyle(color: themeManager.sectionHeaderColor(for: colorScheme))

            HStack(spacing: 8) {
                if kind == .income {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(accent)
                }

                Text(appSettingsManager.selectedCurrency.symbol)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(accent)

                TextField("0.00", text: $amountString)
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                    .keyboardType(.decimalPad)
                    .tint(accent)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(themeManager.cardFill(for: colorScheme))
                    .overlay {
                        if kind == .income {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(accent.opacity(0.35), lineWidth: 1.5)
                        }
                    }
            }
            .shadow(color: colorScheme == .dark ? .clear : Color.black.opacity(0.01), radius: 4, x: 0, y: 2)
        }
    }
}
