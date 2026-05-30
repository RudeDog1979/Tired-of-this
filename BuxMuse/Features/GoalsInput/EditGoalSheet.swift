//
//  EditGoalSheet.swift
//  BuxMuse
//  Features/GoalsInput/
//
//  Native Form sheet for editing savings goals.
//

import SwiftUI

struct EditGoalSheet: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var appSettingsManager: AppSettingsManager
    @EnvironmentObject var goalsViewModel: GoalsViewModel

    let goal: Goal

    @State private var name: String = ""
    @State private var targetString: String = ""
    @State private var selectDeadline = false
    @State private var deadline: Date = Date()
    @State private var priority: Int = 2
    @State private var notes: String = ""

    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.screenBackground(for: colorScheme)
                    .ignoresSafeArea()

                BuxThemedCardForm {
                    BuxFormSection(title: "Goal") {
                        TextField("Goal name", text: $name)
                            .buxFormFieldPadding()
                        BuxFormRowDivider()
                        HStack(spacing: 8) {
                            Text(appSettingsManager.selectedCurrency.symbol)
                                .font(.title2.bold())
                                .foregroundStyle(themeManager.current.accentColor)
                            TextField("Target amount", text: $targetString)
                                .keyboardType(.decimalPad)
                        }
                        .buxFormFieldPadding()
                    }

                    BuxFormSection {
                        GoalOptionalDeadlineSection(isEnabled: $selectDeadline, date: $deadline)
                            .buxFormFieldPadding()
                    }

                    BuxFormSection(title: "Priority") {
                        GoalPriorityPicker(priority: $priority)
                            .buxFormFieldPadding()
                    }

                    BuxFormSection(title: "Notes") {
                        TextField("Notes", text: $notes, axis: .vertical)
                            .lineLimit(3...6)
                            .buxFormFieldPadding()
                    }
                }
            }
            .navigationTitle("Edit Goal")
            .navigationBarTitleDisplayMode(.inline)
            .buxThemedSheetContent()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    BuxToolbarCancelButton { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    BuxToolbarConfirmButton(accessibilityLabel: "Save", isEnabled: canSave) {
                        saveChanges()
                    }
                }
            }
            .onAppear { hydrate() }
        }
        .tint(themeManager.current.accentColor)
    }

    private var canSave: Bool {
        guard let target = Decimal(string: targetString), target > 0 else { return false }
        return !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func hydrate() {
        name = goal.name
        targetString = String(format: "%.0f", NSDecimalNumber(decimal: goal.targetAmount).doubleValue)
        if let dl = goal.deadline {
            deadline = dl
            selectDeadline = true
        }
        priority = goal.priority
        notes = goal.notes ?? ""
    }

    private func saveChanges() {
        guard let target = Decimal(string: targetString), target > 0,
              !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        goalsViewModel.updateGoal(
            id: goal.id,
            name: name,
            targetAmount: target,
            deadline: selectDeadline ? deadline : nil,
            priority: priority,
            notes: notes.isEmpty ? nil : notes
        )
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}
