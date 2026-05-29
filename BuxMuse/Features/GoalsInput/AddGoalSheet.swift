//
//  AddGoalSheet.swift
//  BuxMuse
//  Features/GoalsInput/
//
//  Native Form sheet for entering savings goals.
//

import SwiftUI

struct AddGoalSheet: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var appSettingsManager: AppSettingsManager
    @EnvironmentObject var goalsViewModel: GoalsViewModel

    @State private var name: String = ""
    @State private var targetString: String = ""
    @State private var selectDeadline = false
    @State private var deadline: Date = Date().addingTimeInterval(180 * 86400)
    @State private var priority: Int = 2
    @State private var notes: String = ""
    @State private var brainSuggestions: GoalSuggestions?

    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.screenBackground(for: colorScheme)
                    .ignoresSafeArea()

                Form {
                    if let suggestions = brainSuggestions {
                        Section {
                            brainRecommendationRow(suggestions)
                        }
                    }

                    Section("Goal") {
                        TextField("Goal name", text: $name, prompt: Text("e.g. New Car, Emergency Fund"))
                        HStack(spacing: 8) {
                            Text(appSettingsManager.selectedCurrency.symbol)
                                .font(.title2.bold())
                                .foregroundStyle(themeManager.current.accentColor)
                            TextField("Target amount", text: $targetString)
                                .keyboardType(.decimalPad)
                        }
                    }

                    Section {
                        GoalOptionalDeadlineSection(isEnabled: $selectDeadline, date: $deadline)
                    }

                    Section("Priority") {
                        GoalPriorityPicker(priority: $priority)
                    }

                    Section("Notes") {
                        TextField("Notes", text: $notes, axis: .vertical)
                            .lineLimit(3...6)
                    }
                }
                .buxThemedFormStyle()
            }
            .navigationTitle("Add Goal")
            .navigationBarTitleDisplayMode(.inline)
            .buxThemedSheetContent()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    BuxToolbarCancelButton { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    BuxToolbarConfirmButton(accessibilityLabel: "Save", isEnabled: canSave) {
                        saveGoal()
                    }
                }
            }
            .onAppear {
                brainSuggestions = goalsViewModel.getBrainSuggestions()
            }
        }
        .tint(themeManager.current.accentColor)
    }

    @ViewBuilder
    private func brainRecommendationRow(_ suggestions: GoalSuggestions) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Brain recommendation", systemImage: "sparkles")
                .font(.caption.bold())
                .foregroundStyle(themeManager.current.accentColor)

            Text("6-Month Emergency target: \(appSettingsManager.format(suggestions.suggestedTargetAmount))")
                .font(.subheadline.weight(.semibold))

            Button("Apply suggestion") {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    targetString = String(format: "%.0f", NSDecimalNumber(decimal: suggestions.suggestedTargetAmount).doubleValue)
                    deadline = suggestions.suggestedDeadline
                    selectDeadline = true
                    priority = suggestions.suggestedPriority
                }
            }
            .font(.subheadline.weight(.semibold))
        }
        .padding(.vertical, 4)
    }

    private var canSave: Bool {
        guard let target = Decimal(string: targetString), target > 0 else { return false }
        return !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func saveGoal() {
        guard let target = Decimal(string: targetString), target > 0,
              !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        goalsViewModel.createGoal(
            name: name,
            targetAmount: target,
            currentAmount: 0,
            deadline: selectDeadline ? deadline : nil,
            priority: priority,
            notes: notes.isEmpty ? nil : notes
        )
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}
