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

    private var locale: Locale { appSettingsManager.interfaceLocale }

    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.screenBackground(for: colorScheme)
                    .ignoresSafeArea()

                BuxThemedCardForm {
                    BuxFormSection {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                BuxCatalogText.text("Current saved")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(
                                    BuxLocalizedString.format(
                                        "%@ of %@",
                                        locale: locale,
                                        appSettingsManager.format(goal.currentAmount),
                                        appSettingsManager.format(goal.targetAmount)
                                    )
                                )
                                    .font(.subheadline.weight(.semibold))
                            }
                            Spacer()
                            Text(GoalFormCopy.priorityLabel(goal.priority, locale: locale))
                                .font(.caption.bold())
                                .foregroundStyle(themeManager.contrastAccentColor(for: colorScheme))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(themeManager.current.accentColor.opacity(0.12), in: Capsule())
                        }
                        .buxFormFieldPadding()
                    }

                    BuxFormSection(title: "Target") {
                        HStack(spacing: 8) {
                            Text(appSettingsManager.selectedCurrency.symbol)
                                .font(.title2.bold())
                                .foregroundStyle(themeManager.contrastAccentColor(for: colorScheme))
                            TextField(
                                BuxCatalogLabel.string("Target amount", locale: locale),
                                text: $targetString
                            )
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
                }
            }
            .buxCatalogNavigationTitle("Adjust Goal")
            .navigationBarTitleDisplayMode(.inline)
            .buxThemedSheetContent()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    BuxToolbarCancelButton { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    BuxToolbarConfirmButton(
                        accessibilityLabel: BuxCatalogLabel.string("Apply", locale: locale),
                        isEnabled: canSave
                    ) {
                        applyAdjustments()
                    }
                }
            }
            .onAppear { hydrate() }
        }
        .tint(themeManager.contrastAccentColor(for: colorScheme))
        .buxInterfaceLocale()
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
}
