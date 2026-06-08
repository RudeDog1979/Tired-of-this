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

    private var locale: Locale { appSettingsManager.interfaceLocale }

    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.screenBackground(for: colorScheme)
                    .ignoresSafeArea()

                BuxThemedCardForm {
                    if let suggestions = brainSuggestions {
                        BuxFormSection {
                            brainRecommendationRow(suggestions)
                                .buxFormFieldPadding()
                        }
                    }

                    BuxFormSection(title: "Goal") {
                        TextField(
                            BuxCatalogLabel.string("Goal name", locale: locale),
                            text: $name,
                            prompt: Text(BuxCatalogLabel.string("e.g. New Car, Emergency Fund", locale: locale))
                        )
                            .buxFormFieldPadding()
                        BuxFormRowDivider()
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

                    BuxFormSection(title: "Notes") {
                        TextField(
                            BuxCatalogLabel.string("Notes", locale: locale),
                            text: $notes,
                            axis: .vertical
                        )
                            .lineLimit(3...6)
                            .buxFormFieldPadding()
                    }
                }
            }
            .buxCatalogNavigationTitle("Add Goal")
            .navigationBarTitleDisplayMode(.inline)
            .buxThemedSheetContent()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    BuxToolbarCancelButton { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    BuxToolbarConfirmButton(
                        accessibilityLabel: BuxCatalogLabel.string("Save", locale: locale),
                        isEnabled: canSave
                    ) {
                        saveGoal()
                    }
                }
            }
            .onAppear {
                brainSuggestions = goalsViewModel.getBrainSuggestions()
            }
        }
        .tint(themeManager.contrastAccentColor(for: colorScheme))
        .buxInterfaceLocale()
    }

    @ViewBuilder
    private func brainRecommendationRow(_ suggestions: GoalSuggestions) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label {
                BuxCatalogText.text("Brain recommendation")
            } icon: {
                Image(systemName: "sparkles")
            }
                .font(.caption.bold())
                .foregroundStyle(themeManager.contrastAccentColor(for: colorScheme))

            Text(
                BuxLocalizedString.format(
                    "6-Month Emergency target: %@",
                    locale: locale,
                    appSettingsManager.format(suggestions.suggestedTargetAmount)
                )
            )
                .font(.subheadline.weight(.semibold))

            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    targetString = String(format: "%.0f", NSDecimalNumber(decimal: suggestions.suggestedTargetAmount).doubleValue)
                    deadline = suggestions.suggestedDeadline
                    selectDeadline = true
                    priority = suggestions.suggestedPriority
                }
            } label: {
                BuxCatalogText.text("Apply suggestion")
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
