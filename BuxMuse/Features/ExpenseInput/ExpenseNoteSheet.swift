//
//  ExpenseNoteSheet.swift
//  BuxMuse
//
//  Quick note editor from swipe action.
//

import SwiftUI

struct ExpenseNoteSheet: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    let merchantName: String
    @Binding var notes: String
    let onSave: () throws -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.screenBackground(for: colorScheme)
                    .ignoresSafeArea()

                BuxThemedCardForm {
                    BuxFormSection {
                        Text(ExpenseDisplayL10n.label(merchantName, locale: appSettingsManager.interfaceLocale))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .buxFormFieldPadding()
                    }

                    BuxFormSection(title: "Note") {
                        NotesField(notes: $notes)
                            .buxFormFieldPadding()
                    }
                }
            }
            .buxCatalogNavigationTitle("Add note")
            .navigationBarTitleDisplayMode(.inline)
            .buxThemedSheetContent()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    BuxToolbarCancelButton { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    BuxToolbarConfirmButton(accessibilityLabel: "Save") {
                        try? onSave()
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .tint(themeManager.contrastAccentColor(for: colorScheme))
    }
}
