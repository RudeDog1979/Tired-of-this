//
//  BuxPadExpenseDeleteConfirmation.swift
//  BuxMuse — Native delete confirmation before undo toast (all platforms).
//

import SwiftUI

private struct BuxPadExpenseDeleteConfirmationModifier: ViewModifier {
    @Binding var isPresented: Bool
    let locale: Locale
    let onConfirm: () -> Void

    func body(content: Content) -> some View {
        content.confirmationDialog(
            BuxCatalogLabel.string("Are you sure?", locale: locale),
            isPresented: $isPresented,
            titleVisibility: .visible
        ) {
            Button(BuxCatalogLabel.string("Yes", locale: locale), role: .destructive) {
                isPresented = false
                onConfirm()
            }
            Button(BuxCatalogLabel.string("No", locale: locale), role: .cancel) {
                isPresented = false
            }
        } message: {
            BuxCatalogDynamicText(key: "You can undo for a few seconds after deleting.")
        }
    }
}

private struct BuxPadExpenseDeleteRecordConfirmationModifier: ViewModifier {
    @Binding var pendingRecord: ExpenseRecord?
    let locale: Locale
    let onConfirm: (ExpenseRecord) -> Void

    func body(content: Content) -> some View {
        content.confirmationDialog(
            BuxCatalogLabel.string("Are you sure?", locale: locale),
            isPresented: Binding(
                get: { pendingRecord != nil },
                set: { if !$0 { pendingRecord = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(BuxCatalogLabel.string("Yes", locale: locale), role: .destructive) {
                guard let record = pendingRecord else { return }
                pendingRecord = nil
                onConfirm(record)
            }
            Button(BuxCatalogLabel.string("No", locale: locale), role: .cancel) {
                pendingRecord = nil
            }
        } message: {
            BuxCatalogDynamicText(key: "You can undo for a few seconds after deleting.")
        }
    }
}

extension View {
    /// Confirm before deleting a known expense (detail pane, edit sheet).
    func buxPadExpenseDeleteConfirmation(
        isPresented: Binding<Bool>,
        locale: Locale,
        onConfirm: @escaping () -> Void
    ) -> some View {
        modifier(BuxPadExpenseDeleteConfirmationModifier(
            isPresented: isPresented,
            locale: locale,
            onConfirm: onConfirm
        ))
    }

    /// Confirm before deleting from list context menu.
    func buxPadExpenseDeleteConfirmation(
        pendingRecord: Binding<ExpenseRecord?>,
        locale: Locale,
        onConfirm: @escaping (ExpenseRecord) -> Void
    ) -> some View {
        modifier(BuxPadExpenseDeleteRecordConfirmationModifier(
            pendingRecord: pendingRecord,
            locale: locale,
            onConfirm: onConfirm
        ))
    }
}
