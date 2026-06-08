//
//  ExpandableExpenseCard.swift
//  BuxMuse
//

import SwiftUI

struct ExpandableExpenseCard: View {
    let expense: ExpenseRowDisplay
    let record: ExpenseRecord

    @Binding var expandedId: UUID?
    var onOpenDetail: (() -> Void)? = nil
    var onEdit: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.expensesEnhancedTint) private var expensesEnhancedTint
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var brain: BuxMuseBrain
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    private var isExpanded: Bool {
        expandedId == expense.id
    }

    private var cardCornerRadius: CGFloat {
        isExpanded ? 20 : 16
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 14) {
                Button {
                    if let onOpenDetail {
                        onOpenDetail()
                    } else {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                            expandedId = isExpanded ? nil : expense.id
                        }
                    }
                } label: {
                    HStack(spacing: 14) {
                        ExpenseLedgerAvatarView(record: record, size: 44)
                            .environmentObject(brain)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(expense.name)
                                .font(.body.weight(.medium))
                                .foregroundStyle(themeManager.labelPrimary(for: colorScheme))
                                .textCase(nil)

                            if let category = expense.category {
                                Text(category)
                                    .font(.footnote)
                                    .foregroundStyle(themeManager.labelSecondary(for: colorScheme))
                                    .textCase(nil)
                            }

                            HStack(spacing: 6) {
                                if let workspace = expense.workspaceLabel {
                                    Text(workspace)
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(themeManager.current.accentColor.opacity(0.12))
                                        .clipShape(Capsule())
                                } else if expense.isUnassignedWorkspace {
                                    BuxCatalogText.text("Unassigned")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.orange)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.orange.opacity(0.12))
                                        .clipShape(Capsule())
                                }

                                if let bridge = expense.bridgeBadge {
                                    Text(bridge)
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.purple)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.purple.opacity(0.12))
                                        .clipShape(Capsule())
                                }
                            }
                        }

                        Spacer()

                        Text(expense.amountFormatted)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(themeManager.labelPrimary(for: colorScheme))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(BuxMicroShrinkStyle())

                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                        expandedId = isExpanded ? nil : expense.id
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.gray)
                        .frame(width: 28, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(BuxMicroShrinkStyle())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)

            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    Divider()

                    if let heatZone = expense.heatZone {
                        insightRow(icon: "flame.fill", title: "Heat zone", value: formatEnum(heatZone), color: .red)
                    }
                    if let habit = expense.habitSignature {
                        insightRow(icon: "arrow.triangle.2.circlepath", title: "Habit", value: formatEnum(habit), color: .blue)
                    }
                    if let emotion = expense.emotion, let tag = EmotionalTaggingEngine.tag(for: emotion) {
                        let accent = EmotionalTagAppearance.accent(for: emotion, colorScheme: colorScheme) ?? .pink
                        insightRow(
                            icon: tag.symbol,
                            title: "Emotion",
                            value: tag.localizedLabel(locale: appSettingsManager.interfaceLocale),
                            color: accent
                        )
                    }
                    if let context = expense.context {
                        insightRow(icon: "tag.fill", title: "Context", value: formatEnum(context), color: .purple)
                    }
                    
                    Button {
                        onEdit()
                    } label: {
                        HStack {
                            Spacer()
                            Label {
                                BuxCatalogText.text("Edit transaction")
                            } icon: {
                                Image(systemName: "pencil.line")
                            }
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                            Spacer()
                        }
                        .padding(.vertical, 10)
                        .background(themeManager.current.accentColor.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(BuxMicroShrinkStyle())
                    .padding(.top, 4)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .modifier(
            ExpenseListCardChromeModifier(
                cornerRadius: cardCornerRadius,
                emotionId: expense.emotion,
                emotionSymbol: expense.emotionSymbol
            )
        )
        .environment(\.textCase, nil)
    }

    private func insightRow(icon: String, title: String, value: String, color: Color) -> some View {
        let locale = appSettingsManager.interfaceLocale
        return HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(color)
            BuxCatalogText.text(title)
                .font(.caption.weight(.medium))
                .foregroundColor(.gray)
                .textCase(nil)
            Spacer()
            Text(BuxCatalogLabel.string(value, locale: locale))
                .font(.caption.weight(.medium))
                .textCase(nil)
        }
    }

    private func formatEnum(_ text: String) -> String {
        let key = text.replacingOccurrences(of: "_", with: " ")
        return BuxCatalogLabel.string(key, locale: appSettingsManager.interfaceLocale)
    }
}
