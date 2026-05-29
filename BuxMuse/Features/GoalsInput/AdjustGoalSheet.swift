//
//  AdjustGoalSheet.swift
//  BuxMuse
//  Features/GoalsInput/
//
//  Native Form sheet for adjusting goal targets and schedule.
//

import SwiftUI

struct AdjustGoalSheet: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var appSettingsManager: AppSettingsManager
    @EnvironmentObject var goalsViewModel: GoalsViewModel

    let goal: Goal

    @State private var targetString: String = ""
    @State private var selectDeadline = false
    @State private var deadline: Date = Date()
    @State private var priority: Int = 2

    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.screenBackground(for: colorScheme)
                    .ignoresSafeArea()

                Form {
                    Section {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Current saved")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("\(appSettingsManager.format(goal.currentAmount)) of \(appSettingsManager.format(goal.targetAmount))")
                                    .font(.subheadline.weight(.semibold))
                            }
                            Spacer()
                            Text(priorityLabel(goal.priority))
                                .font(.caption.bold())
                                .foregroundStyle(themeManager.current.accentColor)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(themeManager.current.accentColor.opacity(0.12), in: Capsule())
                        }
                    }

                    Section("Target") {
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
                }
                .buxThemedFormStyle()
            }
            .navigationTitle("Adjust Goal")
            .navigationBarTitleDisplayMode(.inline)
            .buxThemedSheetContent()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    BuxToolbarCancelButton { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    BuxToolbarConfirmButton(accessibilityLabel: "Apply", isEnabled: canSave) {
                        applyAdjustments()
                    }
                }
            }
            .onAppear { hydrate() }
        }
        .tint(themeManager.current.accentColor)
    }

    private var canSave: Bool {
        guard let target = Decimal(string: targetString), target > 0 else { return false }
        return true
    }

    private func hydrate() {
        targetString = String(format: "%.0f", NSDecimalNumber(decimal: goal.targetAmount).doubleValue)
        if let dl = goal.deadline {
            deadline = dl
            selectDeadline = true
        }
        priority = goal.priority
    }

    private func applyAdjustments() {
        guard let target = Decimal(string: targetString), target > 0 else { return }
        goalsViewModel.adjustGoal(
            id: goal.id,
            targetAmount: target,
            deadline: selectDeadline ? deadline : nil,
            priority: priority
        )
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }

    private func priorityLabel(_ prio: Int) -> String {
        prio == 1 ? "High" : (prio == 2 ? "Medium" : "Low")
    }
}
