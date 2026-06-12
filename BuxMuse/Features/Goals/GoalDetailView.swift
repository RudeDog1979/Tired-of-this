//
//  GoalDetailView.swift
//  BuxMuse
//  Features/Goals/
//
//  Premium detailed savings goal overlay view matching the standard BuxMuse modal sheet styling.
//  Optimized: Runs 100% on flat pre-computed Brain values at a solid 120 FPS.
//

import SwiftUI

struct GoalDetailView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var appSettingsManager: AppSettingsManager
    @EnvironmentObject var goalsViewModel: GoalsViewModel

    let detail: GoalsViewModel.GoalDetailState
    let onAddContribution: (UUID, Decimal, String?) -> Void
    let onDeleteGoal: (UUID) -> Void
    @Binding var isPresented: Bool

    @State private var showEditGoal = false
    @State private var showContributeGoal = false
    @State private var showAdjustGoal = false

    private var secondary: Color { themeManager.labelSecondary(for: colorScheme) }

    var body: some View {
        BuxDetailOverlayScaffold(title: "Goal Details") {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                isPresented = false
            }
        } content: {
            mainOverviewCard
            operationsRow
            scenariosSection
            risksSection
            opportunitiesSection
            momentumSection
            contributionsSection
            deleteButton
        }
        .buxThemedPresentation()
        .sheet(isPresented: $showEditGoal) {
            EditGoalSheet(goal: detail.goal)
                .environmentObject(themeManager)
                .environmentObject(appSettingsManager)
                .environmentObject(goalsViewModel)
                .buxThemedSheetContent()
                .buxInterfaceLocale()
        }
        .sheet(isPresented: $showContributeGoal) {
            ContributeToGoalSheet(goal: detail.goal)
                .environmentObject(themeManager)
                .environmentObject(appSettingsManager)
                .environmentObject(goalsViewModel)
                .buxThemedSheetContent()
                .buxInterfaceLocale()
        }
        .sheet(isPresented: $showAdjustGoal) {
            AdjustGoalSheet(goal: detail.goal)
                .environmentObject(themeManager)
                .environmentObject(appSettingsManager)
                .environmentObject(goalsViewModel)
                .buxThemedSheetContent()
                .buxInterfaceLocale()
        }
    }

    // MARK: - Main overview

    private var mainOverviewCard: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(themeManager.current.accentColor.opacity(0.12))
                    .frame(width: 56, height: 56)

                Image(systemName: "target")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
            }

            VStack(spacing: 6) {
                Text(detail.goal.name)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(themeManager.labelPrimary(for: colorScheme))

                if let notes = detail.goal.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }
            }

            VStack(spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(appSettingsManager.format(detail.goal.currentAmount))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))

                    BuxCatalogText.text("saved")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(secondary)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05))
                            .frame(height: 8)

                        Capsule()
                            .fill(themeManager.current.accentColor)
                            .frame(width: geo.size.width * CGFloat(detail.progress), height: 8)
                    }
                }
                .frame(height: 8)
                .padding(.horizontal, 12)

                HStack {
                    Text(
                        BuxLocalizedString.format(
                            "Target: %@",
                            locale: appSettingsManager.interfaceLocale,
                            appSettingsManager.format(detail.goal.targetAmount)
                        )
                    )
                    Spacer()
                    Text(
                        BuxLocalizedString.format(
                            "%lld%%",
                            locale: appSettingsManager.interfaceLocale,
                            Int(detail.progress * 100)
                        )
                    )
                }
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(secondary)
                .padding(.horizontal, 12)
            }

            Divider().opacity(0.08)

            HStack {
                Label(
                    BuxLocalizedString.format(
                        "Health Score: %lld%%",
                        locale: appSettingsManager.interfaceLocale,
                        detail.health.score
                    ),
                    systemImage: "heart.text.square.fill"
                )
                    .foregroundColor(detail.health.score >= 75 ? .green : (detail.health.score >= 45 ? .orange : .red))

                Spacer()

                Label(
                    BuxLocalizedString.format(
                        "Forecast: %@ Risk",
                        locale: appSettingsManager.interfaceLocale,
                        BuxGoalCopy.line(detail.timelineAI.delayRisk, locale: appSettingsManager.interfaceLocale)
                    ),
                    systemImage: "chart.line.uptrend.xyaxis"
                )
                    .foregroundColor(detail.timelineAI.delayRisk == "Low" ? .green : (detail.timelineAI.delayRisk == "Medium" ? .orange : .red))
            }
            .font(.system(size: 12, weight: .bold))
        }
        .buxDetailSectionCard()
    }

    // MARK: - Operations

    private var operationsRow: some View {
        HStack(spacing: 12) {
            Button(action: { showContributeGoal = true }) {
                VStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18))
                    BuxCatalogText.text("Save Money")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(themeManager.current.accentColor)
                .clipShape(RoundedRectangle(cornerRadius: BuxTokens.Radius.card, style: .continuous))
            }

            Button(action: { showAdjustGoal = true }) {
                VStack(spacing: 6) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 18))
                    BuxCatalogText.text("Adjust")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .buxDetailCard(cornerRadius: BuxTokens.Radius.card)

            Button(action: { showEditGoal = true }) {
                VStack(spacing: 6) {
                    Image(systemName: "pencil")
                        .font(.system(size: 18))
                    BuxCatalogText.text("Edit Goal")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .buxDetailCard(cornerRadius: BuxTokens.Radius.card)
        }
        .buttonStyle(BuxMicroShrinkStyle())
    }

    // MARK: - Scenarios

    private var scenariosSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            BuxDetailSectionHeader(title: "Savings velocity scenarios")

            VStack(spacing: 12) {
                ForEach(detail.timelineAI.scenarios) { scenario in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(scenario.localizedName(locale: appSettingsManager.interfaceLocale))
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(themeManager.labelPrimary(for: colorScheme))

                            Text(scenario.localizedDescription(locale: appSettingsManager.interfaceLocale))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(secondary)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 4) {
                            Text(formatDate(scenario.projectedDate))
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))

                            Text(
                                BuxLocalizedString.format(
                                    "Delay Risk: %@",
                                    locale: appSettingsManager.interfaceLocale,
                                    scenario.localizedDelayRisk(locale: appSettingsManager.interfaceLocale)
                                )
                            )
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(delayRiskColor(scenario.delayRisk))
                        }
                    }
                    .buxDetailRowCard()
                }
            }
        }
    }

    // MARK: - Risks

    @ViewBuilder
    private var risksSection: some View {
        if !detail.risks.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                BuxCatalogText.text("Detected progress threats")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.red.opacity(0.8))
                    .kerning(0.6)

                ForEach(detail.risks) { risk in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(risk.localizedDescription(locale: appSettingsManager.interfaceLocale))
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                        }

                        Text(
                            BuxLocalizedString.format(
                                "Fix: %@",
                                locale: appSettingsManager.interfaceLocale,
                                risk.localizedSuggestedFix(locale: appSettingsManager.interfaceLocale)
                            )
                        )
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.red.opacity(0.8))
                            .padding(.leading, 22)
                    }
                    .padding(BuxDetailStyle.cardPadding)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: BuxDetailStyle.rowCardRadius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: BuxDetailStyle.rowCardRadius, style: .continuous)
                            .stroke(Color.red.opacity(0.12), lineWidth: 1)
                    )
                }
            }
        }
    }

    // MARK: - Opportunities

    @ViewBuilder
    private var opportunitiesSection: some View {
        if !detail.opportunities.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                BuxCatalogText.text("Smart savings redirections")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.green)
                    .kerning(0.6)

                ForEach(detail.opportunities) { opportunity in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Image(systemName: "lightbulb.fill")
                                .foregroundColor(.green)
                            Text(opportunity.localizedDescription(locale: appSettingsManager.interfaceLocale))
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                        }

                        Text(opportunity.localizedBenefit(locale: appSettingsManager.interfaceLocale))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.green)
                            .padding(.leading, 22)
                    }
                    .padding(BuxDetailStyle.cardPadding)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.green.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: BuxDetailStyle.rowCardRadius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: BuxDetailStyle.rowCardRadius, style: .continuous)
                            .stroke(Color.green.opacity(0.12), lineWidth: 1)
                    )
                }
            }
        }
    }

    // MARK: - Momentum

    private var momentumSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            BuxDetailSectionHeader(title: "Savings momentum")

            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text(
                        BuxLocalizedString.format(
                            "Status: %@",
                            locale: appSettingsManager.interfaceLocale,
                            detail.momentum.localizedStatus(locale: appSettingsManager.interfaceLocale)
                        )
                    )
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))

                    Spacer()

                    Text(
                        BuxLocalizedString.format(
                            "%+.1f",
                            locale: appSettingsManager.interfaceLocale,
                            detail.momentum.score
                        )
                    )
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(detail.momentum.score >= 0.2 ? .green : (detail.momentum.score <= -0.2 ? .red : .orange))
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05))
                            .frame(height: 6)

                        Capsule()
                            .fill(detail.momentum.score >= 0.2 ? .green : (detail.momentum.score <= -0.2 ? .red : .orange))
                            .frame(width: geo.size.width * CGFloat(detail.normalizedScore), height: 6)
                    }
                }
                .frame(height: 6)

                if !detail.momentum.microActions.isEmpty {
                    Divider().opacity(0.08)

                    BuxCatalogText.text("Suggested Actions:")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))

                    ForEach(detail.momentum.localizedMicroActions(locale: appSettingsManager.interfaceLocale), id: \.self) { act in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 12))
                                .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                                .padding(.top, 2)

                            Text(act)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(secondary)
                                .multilineTextAlignment(.leading)
                        }
                    }
                }

                if !detail.momentum.habitActions.isEmpty {
                    Divider().opacity(0.08)

                    BuxCatalogText.text("Habit Builders:")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))

                    ForEach(detail.momentum.localizedHabitActions(locale: appSettingsManager.interfaceLocale), id: \.self) { act in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                                .padding(.top, 2)

                            Text(act)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(secondary)
                                .multilineTextAlignment(.leading)
                        }
                    }
                }
            }
            .buxDetailSectionCard(cornerRadius: BuxDetailStyle.rowCardRadius)
        }
    }

    // MARK: - Contributions

    @ViewBuilder
    private var contributionsSection: some View {
        if !detail.sortedContributions.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                BuxDetailSectionHeader(title: "Savings log")

                VStack(spacing: 0) {
                    ForEach(detail.sortedContributions) { contrib in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(
                                    contrib.notes
                                        ?? BuxLocalizedString.string(
                                            "Goal contribution",
                                            locale: appSettingsManager.interfaceLocale
                                        )
                                )
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(themeManager.labelPrimary(for: colorScheme))

                                Text(formatDate(contrib.date))
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(secondary)
                            }

                            Spacer()

                            Text(
                                BuxLocalizedString.format(
                                    "+%@",
                                    locale: appSettingsManager.interfaceLocale,
                                    appSettingsManager.format(contrib.amount)
                                )
                            )
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(.green)
                        }
                        .padding(BuxDetailStyle.cardPadding)
                    }
                }
                .buxDetailSectionCard(cornerRadius: BuxDetailStyle.rowCardRadius)
            }
        }
    }

    // MARK: - Delete

    private var deleteButton: some View {
        BuxButton(
            title: "Delete Goal & Discard savings data",
            systemImage: "trash.fill",
            role: .destructive,
            expands: true
        ) {
            onDeleteGoal(detail.goal.id)
            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                isPresented = false
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.locale = appSettingsManager.interfaceLocale
        fmt.dateStyle = .medium
        fmt.timeStyle = .none
        return fmt.string(from: date)
    }

    private func delayRiskColor(_ localizedRisk: String) -> Color {
        let locale = appSettingsManager.interfaceLocale
        if localizedRisk == BuxLocalizedString.string("Low", locale: locale) { return .green }
        if localizedRisk == BuxLocalizedString.string("Medium", locale: locale) { return .orange }
        return .red
    }
}
