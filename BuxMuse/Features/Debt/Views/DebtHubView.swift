//
//  DebtHubView.swift
//  BuxMuse
//
//  Primary debt experience — opened from Home, not Settings.
//

import SwiftUI

struct DebtHubView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.buxLayoutMode) private var layoutMode
    @Environment(\.buxPadInspectorColumn) private var isPadInspectorColumn
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @EnvironmentObject private var debtEngine: DebtEngine
    @ObservedObject private var store = SettingsStore.shared

    @Binding var isPresented: Bool

    @State private var showAddSheet = false
    @State private var selectedDebt: Debt?
    @State private var showDetail = false

    private var accent: Color { themeManager.contrastAccentColor(for: colorScheme) }
    private var insights: [DebtInsight] {
        DebtIntelligenceEngine.portfolioInsights(debts: debtEngine.debts, locale: appSettingsManager.interfaceLocale)
    }
    private var reminders: [(debt: Debt, dueDate: Date, daysUntil: Int)] {
        DebtReminderScheduler.upcomingReminders(debts: debtEngine.debts)
    }

    var body: some View {
        if store.consumerDebtEnabled {
            ZStack {
                NavigationStack {
                    ZStack {
                        Group {
                            if isPadInspectorColumn {
                                Color.clear
                            } else {
                                themeManager.screenBackground(for: colorScheme)
                            }
                        }
                        .ignoresSafeArea()

                        ScrollView(showsIndicators: false) {
                            VStack(spacing: BuxLayout.section) {
                                heroCard
                                if !insights.isEmpty { intelligenceSection }
                                if !reminders.isEmpty { remindersSection }
                                if debtEngine.balanceBreakdown.count > 1 { breakdownSection }
                                debtsSection
                            }
                            .padding(.vertical, BuxLayout.section)
                            .padding(.bottom, BuxOverlayMetrics.scrollBottomInset)
                            .padding(.horizontal, BuxLayout.marginHorizontal)
                        }
                        .buxDetailScrollChrome()
                    }
                    .buxCatalogNavigationTitle("Debt Center")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            BuxToolbarBackButton {
                                withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                                    isPresented = false
                                }
                            }
                        }
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                showAddSheet = true
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(accent)
                            }
                        }
                    }
                    .buxDetailNavigationChrome()
                }

                if showDetail, let debt = selectedDebt {
                    DebtDetailView(
                        debt: debt,
                        isPresented: Binding(
                            get: { showDetail },
                            set: { isShown in
                                if !isShown {
                                    withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                                        showDetail = false
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                        if !showDetail { selectedDebt = nil }
                                    }
                                }
                            }
                        )
                    )
                    .environmentObject(themeManager)
                    .environmentObject(appSettingsManager)
                    .environmentObject(debtEngine)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .bottom).combined(with: .opacity)
                    ))
                    .zIndex(20)
                }
            }
            .sheet(isPresented: $showAddSheet) {
                DebtEditorSheet()
                    .environmentObject(themeManager)
                    .environmentObject(appSettingsManager)
                    .environmentObject(debtEngine)
            }
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    BuxCatalogText.text("Total owed")
                        .font(.system(size: 12, weight: .bold))
                        .buxLabelSecondary()
                    Text(appSettingsManager.format(debtEngine.totalOwed))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(themeManager.labelPrimary(for: colorScheme))
                }
                Spacer()
                Image(systemName: "brain.head.profile.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(accent.opacity(0.85))
                    .accessibilityLabel("On-device intelligence")
            }

            HStack(spacing: 12) {
                heroMetric(titleKey: "Paid this month", value: appSettingsManager.format(debtEngine.paidThisMonth))
                heroMetric(titleKey: "Active debts", value: "\(debtEngine.activeDebts.count)")
                if let nextDue = debtEngine.nextDueDate {
                    let formatter = DateFormatter()
                    let _ = formatter.locale = appSettingsManager.interfaceLocale
                    let _ = formatter.dateStyle = .medium
                    heroMetric(titleKey: "Next due", value: formatter.string(from: nextDue))
                }
            }
        }
        .padding(BuxTokens.section)
        .dashboardMaterialCardChrome(.filled)
    }

    private func heroMetric(titleKey: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            BuxCatalogText.text(titleKey)
                .font(.system(size: 10, weight: .semibold))
                .buxLabelSecondary()
            Text(value)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(themeManager.labelPrimary(for: colorScheme))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var intelligenceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(titleKey: "On-device insights", systemImage: "sparkles")

            VStack(spacing: 10) {
                ForEach(insights) { insight in
                    Button {
                        if let debtId = insight.debtId,
                           let debt = debtEngine.debts.first(where: { $0.id == debtId }) {
                            openDetail(debt)
                        }
                    } label: {
                        DebtInsightCard(insight: insight)
                    }
                    .buttonStyle(.plain)
                    .disabled(insight.debtId == nil)
                }
            }
        }
    }

    private var remindersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(titleKey: "Upcoming reminders", systemImage: "bell.badge.fill")

            VStack(spacing: 0) {
                ForEach(Array(reminders.prefix(4).enumerated()), id: \.element.debt.id) { index, item in
                    if index > 0 { BuxFormRowDivider() }
                    Button {
                        openDetail(item.debt)
                    } label: {
                        HStack(spacing: 12) {
                            DebtLogoView(debt: item.debt, size: 36)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.debt.name)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(themeManager.labelPrimary(for: colorScheme))
                                Text(item.dueDate, style: .date)
                                    .font(.system(size: 12, weight: .medium))
                                    .buxLabelSecondary()
                            }
                            Spacer()
                            Text(
                                item.daysUntil == 0
                                    ? BuxCatalogLabel.string("Today", locale: appSettingsManager.interfaceLocale)
                                    : BuxLocalizedString.format(
                                        "%lldd",
                                        locale: appSettingsManager.interfaceLocale,
                                        Int64(item.daysUntil)
                                    )
                            )
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(item.daysUntil <= 2 ? .orange : accent)
                        }
                        .padding(BuxTokens.section)
                    }
                    .buttonStyle(.plain)
                }
            }
            .dashboardMaterialCardChrome(.outlined)
        }
    }

    private var breakdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(titleKey: "Balance breakdown", systemImage: "chart.pie.fill")
            DebtBreakdownChartView(breakdown: debtEngine.balanceBreakdown)
                .padding(BuxTokens.section)
                .dashboardMaterialCardChrome(.outlined)
        }
    }

    private var debtsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(titleKey: "Your debts", systemImage: "creditcard.fill")

            if debtEngine.activeDebts.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    BuxCatalogText.text("No debts yet")
                        .font(.system(size: 16, weight: .bold))
                    BuxCatalogText.text("Track bank loans, credit cards, family loans, and informal lenders.")
                        .font(.system(size: 13, weight: .medium))
                        .buxLabelSecondary()
                    Button {
                        showAddSheet = true
                    } label: {
                        BuxCatalogText.text("Add your first debt")
                            .font(.system(size: 15, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(accent)
                }
                .padding(BuxTokens.section)
                .dashboardMaterialCardChrome(.outlined)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(debtEngine.activeDebts.enumerated()), id: \.element.id) { index, debt in
                        if index > 0 { BuxFormRowDivider() }
                        Button {
                            openDetail(debt)
                        } label: {
                            debtRow(debt)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .dashboardMaterialCardChrome(.outlined)
            }
        }
    }

    private func debtRow(_ debt: Debt) -> some View {
        HStack(spacing: 14) {
            DebtLogoView(debt: debt, size: 44)
            VStack(alignment: .leading, spacing: 4) {
                Text(debt.name)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(themeManager.labelPrimary(for: colorScheme))
                HStack(spacing: 6) {
                    BuxCatalogText.text(debt.type.catalogLabelKey)
                        .font(.system(size: 11, weight: .medium))
                        .buxLabelSecondary()
                    Text("·")
                        .buxLabelSecondary()
                    BuxCatalogText.text(debt.lenderSource.catalogLabelKey)
                        .font(.system(size: 11, weight: .medium))
                        .buxLabelSecondary()
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(appSettingsManager.format(debt.currentBalance))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(accent)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .buxLabelSecondary()
            }
        }
        .padding(BuxTokens.section)
    }

    private func sectionHeader(titleKey: String, systemImage: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(accent)
            BuxCatalogText.text(titleKey)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(themeManager.labelPrimary(for: colorScheme))
        }
    }

    private func openDetail(_ debt: Debt) {
        selectedDebt = debt
        withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
            showDetail = true
        }
    }
}

private struct DebtInsightCard: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager

    let insight: DebtInsight

    private var tint: Color {
        switch insight.tone {
        case .positive: return .green
        case .warning: return .orange
        case .neutral: return themeManager.contrastAccentColor(for: colorScheme)
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.14))
                    .frame(width: 36, height: 36)
                Image(systemName: insight.systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(tint)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(insight.title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(themeManager.labelPrimary(for: colorScheme))
                Text(insight.message)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(themeManager.labelSecondary(for: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(BuxTokens.section)
        .dashboardMaterialCardChrome(.outlined)
    }
}
