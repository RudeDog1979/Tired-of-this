//
//  ExpenseUndoToastView.swift
//  BuxMuse
//
//  Center-screen undo banner after deleting an expense.
//

import SwiftUI

struct ExpenseUndoToastView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var brain: BuxMuseBrain

    var body: some View {
        Color.clear
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .overlay(alignment: .center) {
                if brain.expenseUndoOffer != nil {
                    toastCard
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.86), value: brain.expenseUndoOffer?.id)
    }

    private var toastCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "trash.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(themeManager.labelSecondary(for: colorScheme))

            BuxCatalogDynamicText(key: "Expense deleted")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(themeManager.labelPrimary(for: colorScheme))

            Button {
                try? brain.performExpenseUndo()
            } label: {
                BuxCatalogDynamicText(key: "Undo")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(themeManager.current.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(BuxMicroShrinkStyle())
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 28)
        .frame(maxWidth: 320)
        .background(themeManager.cardFill(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.4 : 0.16), radius: 24, y: 8)
        .padding(.horizontal, BuxLayout.marginHorizontal)
    }
}
