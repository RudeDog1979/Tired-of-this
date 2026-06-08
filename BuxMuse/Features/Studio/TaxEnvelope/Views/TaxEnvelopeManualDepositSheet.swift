//
//  TaxEnvelopeManualDepositSheet.swift
//  BuxMuse
//

import SwiftUI

struct TaxEnvelopeManualDepositSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @EnvironmentObject private var studioStore: StudioStore

    @State private var amountText = ""
    @State private var note = ""

    private var locale: Locale { appSettingsManager.interfaceLocale }

    private var canSave: Bool {
        guard let amount = Decimal(string: amountText) else { return false }
        return amount > 0
    }

    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.screenBackground(for: colorScheme).ignoresSafeArea()

                BuxThemedCardForm {
                    BuxFormSection(title: "Amount") {
                        TextField("0.00", text: $amountText)
                            .keyboardType(.decimalPad)
                            .buxFormFieldPadding()
                    }

                    BuxFormSection(title: "Note") {
                        TextField(BuxCatalogLabel.string("Optional", locale: locale), text: $note)
                            .buxFormFieldPadding()
                    }

                    BuxFormSection {
                        Text(BuxCatalogLabel.string(
                            "Adds to your set-aside total. BuxMuse does not move money for you.",
                            locale: locale
                        ))
                        .font(.system(size: 12, weight: .medium))
                        .buxLabelSecondary()
                        .buxFormFieldPadding()
                    }
                }
            }
            .buxCatalogNavigationTitle("I set money aside")
            .buxInterfaceLocale()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    BuxToolbarCancelButton { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    BuxToolbarSaveButton(isDirty: canSave) { save() }
                }
            }
            .buxRootNavigationChrome()
            .buxMeshSheetPresentation()
        }
    }

    private func save() {
        guard let amount = Decimal(string: amountText) else { return }
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        studioStore.addTaxEnvelopeDeposit(
            amount: amount,
            linkedEntryId: nil,
            note: trimmed.isEmpty ? nil : trimmed
        )
        BuxSaveFeedback.success()
        dismiss()
    }
}
