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

    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.screenBackground(for: colorScheme)
                    .ignoresSafeArea()

                Form {
                    if let suggestion = microSuggestion {
                        Section {
                            VStack(alignment: .leading, spacing: 10) {
                                Label("Brain savings tip", systemImage: "lightbulb.fill")
                                    .font(.caption.bold())
                                    .foregroundStyle(.green)
                                Text(suggestion)
                                    .font(.subheadline.weight(.semibold))
                                Button("Redirect suggested amount") {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                        amountString = "15"
                                        notes = "Brain micro-savings redirection"
                                    }
                                }
                                .font(.subheadline.weight(.semibold))
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    Section("Amount") {
                        HStack(spacing: 8) {
                            Text(appSettingsManager.selectedCurrency.symbol)
                                .font(.title2.bold())
                                .foregroundStyle(themeManager.current.accentColor)
                            TextField("Contribution amount", text: $amountString)
                                .keyboardType(.decimalPad)
                        }
                    }

                    Section("Details") {
                        TextField("Memo / source", text: $notes, prompt: Text("e.g. Weekly savings"))
                        DatePicker("Contribution date", selection: $date, displayedComponents: .date)
                    }
                }
                .buxThemedFormStyle()
            }
            .navigationTitle("Contribute")
            .navigationBarTitleDisplayMode(.inline)
            .buxThemedSheetContent()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    BuxToolbarCancelButton { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    BuxToolbarConfirmButton(accessibilityLabel: "Confirm", isEnabled: canSave) {
                        confirmContribution()
                    }
                }
            }
            .onAppear {
                setupMicroSuggestions()
            }
        }
        .tint(themeManager.current.accentColor)
    }

    private func setupMicroSuggestions() {
        let details = goalsViewModel.selectedGoalDetail
        if let opp = details?.opportunities.first {
            microSuggestion = "Cancel or optimize: \(opp.description) benefits \(opp.benefit)."
        } else {
            microSuggestion = "Trim \(appSettingsManager.format(Decimal(15))) from active subscription overspends and redirect it to achieve \(goal.name) sooner."
        }
    }

    private var canSave: Bool {
        guard let amount = Decimal(string: amountString), amount > 0 else { return false }
        return true
    }

    private func confirmContribution() {
        guard let amount = Decimal(string: amountString), amount > 0 else { return }
        goalsViewModel.addContribution(
            toGoalId: goal.id,
            amount: amount,
            notes: notes.isEmpty ? "Direct contribution" : notes
        )
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}
