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
        default: return themeManager.current.accentColor
        }
    }

    var body: some View {
        ZStack {
            themeManager.screenBackground(for: colorScheme)
                .ignoresSafeArea()

            BuxHeroMeshBackground()

            Color.black.opacity(colorScheme == .dark ? 0.55 : 0.35)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.buxBounce) { isPresented = false }
                }

            VStack(spacing: 0) {
                BuxOverlayHeader(title: "Insight Deep Dive") {
                    withAnimation(.buxBounce) { isPresented = false }
                }

                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: BuxLayout.section) {
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
                    .padding(.vertical, BuxLayout.section)
                    .padding(.bottom, BuxOverlayMetrics.scrollBottomInset)
                    .buxScreenContentMargins()
                }
                .buxReportsContainerWidth()
            }
        }
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
                Text(insight.title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                Text(insight.description)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(themeManager.labelSecondary(for: colorScheme))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }

            Divider().opacity(0.08)

            VStack(alignment: .leading, spacing: BuxLayout.tight + 4) {
                BuxDetailSectionHeader(title: "Explanation")

                Text(insight.fullExplanation)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.8) : Color(red: 70/255, green: 80/255, blue: 95/255))
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(BuxDetailStyle.cardPadding)
        .frame(maxWidth: .infinity)
        .buxDetailCard()
    }

    // MARK: - Data metrics

    private var dataMetricsSection: some View {
        VStack(alignment: .leading, spacing: BuxLayout.tight + 4) {
            BuxDetailSectionHeader(title: "Data metrics")

            HStack(alignment: .top, spacing: BuxLayout.section) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Metric Details")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))

                    Text(insight.dataBehind)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(themeManager.labelSecondary(for: colorScheme))
                        .lineLimit(3)
                }

                Spacer(minLength: 8)

                Text(insight.value)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(accentColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(BuxDetailStyle.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .buxDetailCard(cornerRadius: BuxDetailStyle.rowCardRadius)
        }
    }

    // MARK: - Impact

    private var impactSection: some View {
        VStack(alignment: .leading, spacing: BuxLayout.tight + 4) {
            BuxDetailSectionHeader(title: "Projected financial impact")

            HStack(alignment: .top, spacing: BuxLayout.section) {
                impactCard(label: "Monthly", value: appSettingsManager.format(insight.impactMonthly))
                impactCard(label: "Yearly", value: appSettingsManager.format(insight.impactMonthly * 12))
            }
        }
    }

    private func impactCard(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.gray)

            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(accentColor)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer(minLength: 0)
        }
        .padding(BuxDetailStyle.cardPadding)
        .frame(maxWidth: .infinity, minHeight: BuxDetailStyle.pairedCardMinHeight, alignment: .topLeading)
        .buxDetailCard(cornerRadius: BuxDetailStyle.rowCardRadius)
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
                        Text("Impact on '\(goalName)'")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                            .lineLimit(2)

                        Text("Applying this insight accelerates this target timeline significantly.")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(themeManager.labelSecondary(for: colorScheme))
                            .lineLimit(3)
                    }

                    Spacer(minLength: 0)
                }
                .padding(BuxDetailStyle.cardPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .buxDetailCard(cornerRadius: BuxDetailStyle.rowCardRadius)
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

                        Text(action)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer(minLength: 0)
                    }
                    .padding(BuxDetailStyle.cardPadding)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .buxDetailCard(cornerRadius: BuxDetailStyle.rowCardRadius)
                }
            }
        }
    }
}
