//
//  ExpandableExpenseCard.swift
//  BuxMuse
//

import SwiftUI

struct ExpandableExpenseCard: View {
    let expense: ExpenseRowDisplay

    @Binding var expandedId: UUID?

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.expensesEnhancedTint) private var expensesEnhancedTint
    @EnvironmentObject private var themeManager: ThemeManager

    private var isExpanded: Bool {
        expandedId == expense.id
    }

    private var cardCornerRadius: CGFloat {
        isExpanded ? 20 : 16
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(expense.name)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(themeManager.labelPrimary(for: colorScheme))

                    if let category = expense.category {
                        Text(category)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(themeManager.labelSecondary(for: colorScheme))
                    }
                }

                Spacer()

                Text(expense.amountFormatted)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(themeManager.labelPrimary(for: colorScheme))

                Button {
                    withAnimation(.buxLiquidSpring) {
                        expandedId = isExpanded ? nil : expense.id
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(themeManager.current.accentColor.opacity(0.8))
                }
                .buttonStyle(.plain)
            }
            .padding()

            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    Divider()

                    if let heatZone = expense.heatZone {
                        insightRow(icon: "flame.fill", title: "Heat Zone", value: formatEnum(heatZone), color: .red)
                    }
                    if let habit = expense.habitSignature {
                        insightRow(icon: "arrow.triangle.2.circlepath", title: "Habit", value: formatEnum(habit), color: .blue)
                    }
                    if let emotion = expense.emotion, let tag = EmotionalTaggingEngine.tag(for: emotion) {
                        let accent = EmotionalTagAppearance.accent(for: emotion, colorScheme: colorScheme) ?? .pink
                        insightRow(icon: tag.symbol, title: "Emotion", value: tag.label, color: accent)
                    }
                    if let context = expense.context {
                        insightRow(icon: "tag.fill", title: "Context", value: formatEnum(context), color: .purple)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
        }
        .modifier(
            ExpenseListCardChromeModifier(
                cornerRadius: cardCornerRadius,
                emotionId: expense.emotion,
                emotionSymbol: expense.emotionSymbol
            )
        )
    }

    private func insightRow(icon: String, title: String, value: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(color)
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .medium))
        }
    }

    private func formatEnum(_ text: String) -> String {
        text.replacingOccurrences(of: "_", with: " ").capitalized
    }
}
