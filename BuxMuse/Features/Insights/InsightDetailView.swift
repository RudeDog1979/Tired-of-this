//
//  InsightDetailView.swift
//  BuxMuse
//  Features/Insights/
//
//  Premium deep-dive detail sheet for Financial Insights matching BuxMuse aesthetics.
//

import SwiftUI

struct InsightDetailView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    let insight: FinancialInsight
    @Binding var isPresented: Bool

    private var accentColor: Color {
        switch insight.accentColorName {
        case "red": return .red
        case "green": return .green
        case "orange": return .orange
        case "blue": return .blue
        case "purple": return .purple
        default: return themeManager.contrastAccentColor(for: colorScheme)
        }
    }

    var body: some View {
        BuxDetailOverlayScaffold(title: "Insight Deep Dive") {
            withAnimation(.buxBounce) { isPresented = false }
        } content: {
            mainInsightCard
            dataMetricsSection

            if insight.impactMonthly > 0 || insight.impactYearly > 0 {
                impactSection
            }

            if insight.affectedGoalName != nil {
                goalAccelerationSection
            }

            suggestedActionsSection
        }
        .environment(\.dashboardEnhancedTint, true)
        .buxInterfaceLocale()
        .buxThemedPresentation()
    }

    // MARK: - Main card

    private var mainInsightCard: some View {
        VStack(spacing: BuxLayout.section) {
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.12))
                    .frame(width: 44, height: 44)

                Image(systemName: insight.systemIcon)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(accentColor)
            }

            VStack(spacing: 6) {
                Text(insight.localizedTitle(locale: appSettingsManager.interfaceLocale))
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                Text(insight.localizedDescription(locale: appSettingsManager.interfaceLocale))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(themeManager.labelSecondary(for: colorScheme))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }

            Divider().opacity(0.08)

            VStack(alignment: .leading, spacing: BuxLayout.tight + 4) {
                BuxDetailSectionHeader(title: "Explanation")

                Text(insight.localizedFullExplanation(locale: appSettingsManager.interfaceLocale))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.8) : Color(red: 70/255, green: 80/255, blue: 95/255))
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
        .buxDetailSectionCard()
    }

    // MARK: - Data metrics

    private var dataMetricsSection: some View {
        VStack(alignment: .leading, spacing: BuxLayout.tight + 4) {
            BuxDetailSectionHeader(title: "Data metrics")

            VStack(alignment: .leading, spacing: BuxLayout.tight + 2) {
                BuxCatalogText.text("Metric Details")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(themeManager.labelPrimary(for: colorScheme))

                Text(insight.localizedDataBehind(locale: appSettingsManager.interfaceLocale))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(themeManager.labelSecondary(for: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)

                Text(insight.localizedValue(locale: appSettingsManager.interfaceLocale))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(accentColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(3)
                    .minimumScaleFactor(0.85)
            }
            .buxDetailRowCard()
        }
    }

    // MARK: - Impact

    private var impactSection: some View {
        VStack(alignment: .leading, spacing: BuxLayout.tight + 4) {
            BuxDetailSectionHeader(title: "Projected financial impact")

            HStack(alignment: .top, spacing: BuxLayout.section) {
                impactCard(label: "Monthly", value: appSettingsManager.format(insight.impactMonthly))
                impactCard(label: "Yearly", value: appSettingsManager.format(insight.impactYearly > 0 ? insight.impactYearly : insight.impactMonthly * 12))
            }
        }
    }

    private func impactCard(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            BuxCatalogText.text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.gray)

            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(accentColor)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .buxDetailRowCard(minHeight: BuxDetailStyle.pairedCardMinHeight)
    }

    // MARK: - Goal acceleration

    @ViewBuilder
    private var goalAccelerationSection: some View {
        if let goalName = insight.affectedGoalName {
            VStack(alignment: .leading, spacing: BuxLayout.tight + 4) {
                BuxDetailSectionHeader(title: "Goal acceleration effect")

                HStack(alignment: .top, spacing: BuxLayout.section) {
                    ZStack {
                        Circle()
                            .fill(Color.green.opacity(0.12))
                            .frame(width: 40, height: 40)
                        Image(systemName: "sparkles")
                            .foregroundColor(.green)
                            .font(.system(size: 16, weight: .bold))
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(
                            BuxLocalizedString.format(
                                "Impact on '%@'",
                                locale: appSettingsManager.interfaceLocale,
                                goalName
                            )
                        )
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                            .lineLimit(2)

                        BuxCatalogText.text("Applying this insight accelerates this target timeline significantly.")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(themeManager.labelSecondary(for: colorScheme))
                            .lineLimit(3)
                    }

                    Spacer(minLength: 0)
                }
                .buxDetailRowCard()
            }
        }
    }

    // MARK: - Actions

    private var suggestedActionsSection: some View {
        VStack(alignment: .leading, spacing: BuxLayout.tight + 4) {
            BuxDetailSectionHeader(title: "BuxMuse suggested actions")

            VStack(spacing: BuxLayout.section) {
                ForEach(insight.suggestedActions, id: \.self) { action in
                    HStack(alignment: .top, spacing: BuxLayout.section) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(accentColor)
                            .font(.system(size: 15))
                            .padding(.top, 2)

                        Text(insight.localizedSuggestedAction(action, locale: appSettingsManager.interfaceLocale))
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer(minLength: 0)
                    }
                    .buxDetailRowCard()
                }
            }
        }
    }
}
