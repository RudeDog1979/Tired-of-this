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
    @EnvironmentObject private var brain: BuxMuseBrain

    let transaction: Transaction
    let onSelect: (TransactionCategory, UUID?) -> Void

    @State private var selected: TransactionCategory
    @State private var selectedCategoryId: UUID?

    init(transaction: Transaction, onSelect: @escaping (TransactionCategory, UUID?) -> Void) {
        self.transaction = transaction
        self.onSelect = onSelect
        _selected = State(initialValue: transaction.category)
        _selectedCategoryId = State(initialValue: nil)
    }

    var body: some View {
        ZStack {
            themeManager.screenBackground(for: colorScheme)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Text("Change category")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                    .padding(.top, 24)

                Text(transaction.merchantName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gray)

                ExpenseCategoryPickerView(
                    selectedCategoryId: $selectedCategoryId,
                    selectedCategory: $selected
                )
                .environmentObject(brain)

                Button(action: {
                    withAnimation(.buxSnap) {
                        onSelect(selected, selectedCategoryId)
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
        .onAppear {
            if let record = try? brain.fetchExpenseRecord(id: transaction.id) {
                selected = record.transactionCategory
                selectedCategoryId = record.categoryId
            }
        }
    }
}
