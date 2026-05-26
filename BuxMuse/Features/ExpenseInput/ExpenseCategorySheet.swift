//
//  ExpenseCategorySheet.swift
//  BuxMuse
//
//  Quick category change from expense list swipe / context menu.
//

import SwiftUI

struct ExpenseCategorySheet: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager

    let transaction: Transaction
    let onSelect: (TransactionCategory) -> Void

    @State private var selected: TransactionCategory

    init(transaction: Transaction, onSelect: @escaping (TransactionCategory) -> Void) {
        self.transaction = transaction
        self.onSelect = onSelect
        _selected = State(initialValue: transaction.category)
    }

    var body: some View {
        ZStack {
            themeManager.screenBackground(for: colorScheme)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Text("Change category")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(colorScheme == .dark ? .white : Color(red: 26/255, green: 28/255, blue: 32/255))
                    .padding(.top, 24)

                Text(transaction.merchantName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gray)

                CategoryPicker(selectedCategory: $selected)

                Button(action: {
                    withAnimation(.buxSnap) {
                        onSelect(selected)
                    }
                    dismiss()
                }) {
                    Text("Apply")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(themeManager.current.accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(BuxMicroShrinkStyle())
                .padding(.horizontal, BuxLayout.marginHorizontal)

                Spacer()
            }
        }
        .presentationDetents([.medium])
    }
}
