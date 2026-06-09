//
//  BuxPadExpensePickerPresentation.swift
//  BuxMuse — Category/note as popover on iPad regular split; sheet elsewhere.
//

import SwiftUI

struct BuxPadExpensePickerPresentation: ViewModifier {
    @Binding var categoryTransaction: Transaction?
    @Binding var noteRecord: ExpenseRecord?
    @Binding var noteDraft: String

    let onCategoryChange: (Transaction, TransactionCategory, UUID?) -> Void
    let onNoteSave: () -> Void

    @Environment(\.buxLayoutMode) private var layoutMode
    @Environment(\.buxPadExpenseUsesSplitLayout) private var usesPadSplitLayout
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var brain: BuxMuseBrain

    private var usesPopover: Bool {
        BuxPadIdiom.isPad && usesPadSplitLayout && layoutMode == .regular
    }

    func body(content: Content) -> some View {
        content
            .modifier(CategoryPresentationModifier(
                transaction: $categoryTransaction,
                usesPopover: usesPopover,
                themeManager: themeManager,
                brain: brain,
                onCategoryChange: onCategoryChange
            ))
            .modifier(NotePresentationModifier(
                record: $noteRecord,
                noteDraft: $noteDraft,
                usesPopover: usesPopover,
                themeManager: themeManager,
                onNoteSave: onNoteSave
            ))
    }
}

private struct CategoryPresentationModifier: ViewModifier {
    @Binding var transaction: Transaction?
    let usesPopover: Bool
    let themeManager: ThemeManager
    let brain: BuxMuseBrain
    let onCategoryChange: (Transaction, TransactionCategory, UUID?) -> Void

    func body(content: Content) -> some View {
        if usesPopover {
            content
                .popover(item: $transaction) { tx in
                    ExpenseCategorySheet(transaction: tx) { category, categoryId in
                        onCategoryChange(tx, category, categoryId)
                        transaction = nil
                    }
                    .environmentObject(themeManager)
                    .environmentObject(brain)
                    .environment(\.expensesEnhancedTint, true)
                    .frame(minWidth: 360, minHeight: 420)
                }
        } else {
            content
                .sheet(item: $transaction) { tx in
                    ExpenseCategorySheet(transaction: tx) { category, categoryId in
                        onCategoryChange(tx, category, categoryId)
                    }
                    .environmentObject(themeManager)
                    .environmentObject(brain)
                    .environment(\.expensesEnhancedTint, true)
                    .buxThemedSheetContent()
                }
        }
    }
}

private struct NotePresentationModifier: ViewModifier {
    @Binding var record: ExpenseRecord?
    @Binding var noteDraft: String
    let usesPopover: Bool
    let themeManager: ThemeManager
    let onNoteSave: () -> Void

    func body(content: Content) -> some View {
        if usesPopover {
            content
                .popover(item: $record) { item in
                    ExpenseNoteSheet(
                        merchantName: item.name,
                        notes: $noteDraft,
                        onSave: {
                            onNoteSave()
                            record = nil
                        }
                    )
                    .environmentObject(themeManager)
                    .environment(\.expensesEnhancedTint, true)
                    .frame(minWidth: 340, minHeight: 280)
                    .onAppear {
                        noteDraft = item.notes ?? ""
                    }
                }
        } else {
            content
                .sheet(item: $record) { item in
                    ExpenseNoteSheet(
                        merchantName: item.name,
                        notes: $noteDraft,
                        onSave: onNoteSave
                    )
                    .environmentObject(themeManager)
                    .environment(\.expensesEnhancedTint, true)
                    .buxThemedSheetContent()
                    .onAppear {
                        noteDraft = item.notes ?? ""
                    }
                }
        }
    }
}

extension View {
    func buxPadExpensePickerPresentation(
        categoryTransaction: Binding<Transaction?>,
        noteRecord: Binding<ExpenseRecord?>,
        noteDraft: Binding<String>,
        onCategoryChange: @escaping (Transaction, TransactionCategory, UUID?) -> Void,
        onNoteSave: @escaping () -> Void
    ) -> some View {
        modifier(
            BuxPadExpensePickerPresentation(
                categoryTransaction: categoryTransaction,
                noteRecord: noteRecord,
                noteDraft: noteDraft,
                onCategoryChange: onCategoryChange,
                onNoteSave: onNoteSave
            )
        )
    }
}
