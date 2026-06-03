//
//  ContributeToGoalSheet.swift
//  BuxMuse
//  Features/GoalsInput/
//
//  Native Form sheet for logging goal contributions.
//

import SwiftUI

struct ContributeToGoalSheet: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var appSettingsManager: AppSettingsManager
    @EnvironmentObject var goalsViewModel: GoalsViewModel

    let goal: Goal

    @State private var amountString: String = ""
    @State private var notes: String = ""
    @State private var date: Date = Date()
    @State private var microSuggestion: String?

    private var locale: Locale { appSettingsManager.interfaceLocale }

    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.screenBackground(for: colorScheme)
                    .ignoresSafeArea()

                BuxThemedCardForm {
                    if let suggestion = microSuggestion {
                        BuxFormSection {
                            VStack(alignment: .leading, spacing: 10) {
                                Label {
                                    BuxCatalogText.text("Brain savings tip")
                                } icon: {
                                    Image(systemName: "lightbulb.fill")
                                }
                                    .font(.caption.bold())
                                    .foregroundStyle(.green)
                                Text(suggestion)
                                    .font(.subheadline.weight(.semibold))
                                Button {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                        amountString = "15"
                                        notes = BuxLocalizedString.string(
                                            "Brain micro-savings redirection",
                                            locale: locale
                                        )
                                    }
                                } label: {
                                    BuxCatalogText.text("Redirect suggested amount")
                                }
                                .font(.subheadline.weight(.semibold))
                            }
                            .buxFormFieldPadding()
                        }
                    }

                    BuxFormSection(title: "Amount") {
                        HStack(spacing: 8) {
                            Text(appSettingsManager.selectedCurrency.symbol)
                                .font(.title2.bold())
                                .foregroundStyle(themeManager.current.accentColor)
                            TextField(
                                BuxCatalogLabel.string("Contribution amount", locale: locale),
                                text: $amountString
                            )
                                .keyboardType(.decimalPad)
                        }
                        .buxFormFieldPadding()
                    }

                    BuxFormSection(title: "Details") {
                        TextField(
                            BuxCatalogLabel.string("Memo / source", locale: locale),
                            text: $notes,
                            prompt: Text(BuxCatalogLabel.string("e.g. Weekly savings", locale: locale))
                        )
                            .buxFormFieldPadding()
                        BuxFormRowDivider()
                        DatePicker(selection: $date, displayedComponents: .date) {
                            BuxCatalogText.text("Contribution date")
                        }
                            .tint(themeManager.current.accentColor)
                            .buxFormFieldPadding()
                    }
                }
            }
            .buxCatalogNavigationTitle("Contribute")
            .navigationBarTitleDisplayMode(.inline)
            .buxThemedSheetContent()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    BuxToolbarCancelButton { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    BuxToolbarConfirmButton(
                        accessibilityLabel: BuxCatalogLabel.string("Confirm", locale: locale),
                        isEnabled: canSave
                    ) {
                        confirmContribution()
                    }
                }
            }
            .onAppear {
                setupMicroSuggestions()
            }
        }
        .tint(themeManager.current.accentColor)
        .buxInterfaceLocale()
    }

    private func setupMicroSuggestions() {
        let details = goalsViewModel.selectedGoalDetail
        if let opp = details?.opportunities.first {
            microSuggestion = BuxLocalizedString.format(
                "Cancel or optimize: %@ benefits %@.",
                locale: locale,
                opp.localizedDescription(locale: locale),
                opp.localizedBenefit(locale: locale)
            )
        } else {
            microSuggestion = BuxLocalizedString.format(
                "Trim %@ from active subscription overspends and redirect it to achieve %@ sooner.",
                locale: locale,
                appSettingsManager.format(Decimal(15)),
                goal.name
            )
        }
    }

    private var canSave: Bool {
        guard let amount = Decimal(string: amountString), amount > 0 else { return false }
        return true
    }

    private func confirmContribution() {
        guard let amount = Decimal(string: amountString), amount > 0 else { return }
        let defaultNote = BuxLocalizedString.string("Direct contribution", locale: locale)
        goalsViewModel.addContribution(
            toGoalId: goal.id,
            amount: amount,
            notes: notes.isEmpty ? defaultNote : notes
        )
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}
