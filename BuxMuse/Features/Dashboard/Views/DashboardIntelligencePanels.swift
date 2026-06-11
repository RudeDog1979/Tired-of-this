//
//  DashboardIntelligencePanels.swift
//  BuxMuse
//
//  Enriched Insights pill, Money Map, and feature strip components.
//

import SwiftUI

// MARK: - Feature strips (horizontal MAT row)

struct DashboardFeatureInsightStrips: View {
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    let strips: [FeatureInsightStrip]
    var onOpenStudioSettings: (() -> Void)?

    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            BuxCatalogText.text("Feature intelligence")
                .buxSectionLabelStyle(color: themeManager.sectionHeaderColor(for: colorScheme))
                .padding(.horizontal, 4)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: BuxTokens.tight) {
                    ForEach(strips) { strip in
                        featureStripCard(strip)
                    }
                }
                .padding(.horizontal, BuxTokens.marginRegular)
            }
            .padding(.horizontal, -BuxTokens.marginRegular)
            .modifier(BuxPadHorizontalFeatureStripChromeModifier())
        }
    }

    private func featureStripCard(_ strip: FeatureInsightStrip) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: strip.systemIcon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(accent(for: strip.accentColorName))
                Text(strip.localizedTitle(locale: appSettingsManager.interfaceLocale))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                    .lineLimit(1)
            }

            Text(strip.localizedValue(locale: appSettingsManager.interfaceLocale))
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(strip.localizedSubtitle(locale: appSettingsManager.interfaceLocale))
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(themeManager.labelSecondary(for: colorScheme))
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            if !strip.isFeatureEnabled || !strip.hasData, let cta = strip.ctaLabel {
                Button(action: { onOpenStudioSettings?() }) {
                    Text(BuxInsightCopy.copy(cta, locale: appSettingsManager.interfaceLocale))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .frame(width: 168, alignment: .leading)
        .dashboardMaterialCardChrome(strip.hasData ? .filled : .outlined)
        .opacity(strip.isFeatureEnabled ? 1 : 0.72)
    }

    private func accent(for name: String) -> Color {
        switch name {
        case "red": return .red
        case "green": return .green
        case "orange": return .orange
        case "blue": return .blue
        case "purple": return .purple
        default: return themeManager.contrastAccentColor(for: colorScheme)
        }
    }
}

// MARK: - Enriched Insights pill

struct DashboardInsightsPanel: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @EnvironmentObject private var insightsViewModel: InsightsViewModel

    let categorySlideDirection: Int
    let categoryMotionToken: UUID
    let isScreenLoaded: Bool
    var showsFeatureStrips: Bool = true
    var onOpenStudioSettings: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: BuxTokens.block) {
            smartInsightStack

            if showsFeatureStrips {
                DashboardFeatureInsightStrips(
                    strips: insightsViewModel.featureStrips,
                    onOpenStudioSettings: onOpenStudioSettings
                )
                .buxDashboardCategoryCard(index: 2, direction: categorySlideDirection, motionToken: categoryMotionToken)
            }
        }
        .transition(.buxCategorySlide(direction: categorySlideDirection))
    }

    private var smartInsightStack: some View {
        let topInsights = Array(insightsViewModel.rankedInsights.prefix(3))

        return VStack(alignment: .leading, spacing: 10) {
            BuxCatalogText.text("Top insights")
                .buxSectionLabelStyle(color: themeManager.sectionHeaderColor(for: colorScheme))
                .padding(.horizontal, 4)

            if topInsights.isEmpty {
                emptyInsightsCard
            } else {
                ForEach(Array(topInsights.enumerated()), id: \.element.id) { index, insight in
                    insightButton(insight, index: index)
                }
            }
        }
    }

    private var emptyInsightsCard: some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 24))
                    .foregroundColor(themeManager.labelSecondary(for: colorScheme))
                BuxCatalogText.text("No insights yet.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(themeManager.labelSecondary(for: colorScheme))
                BuxCatalogText.text("Add expenses to unlock spending insights.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
            Spacer()
        }
        .padding(.vertical, 28)
        .frame(maxWidth: .infinity)
        .dashboardMaterialCardChrome(.outlined)
        .buxDashboardCategoryCard(index: 0, direction: categorySlideDirection, motionToken: categoryMotionToken)
    }

    private func insightButton(_ insight: FinancialInsight, index: Int) -> some View {
        Button(action: { insightsViewModel.selectInsight(insight) }) {
            HStack(spacing: 12) {
                Image(systemName: insight.systemIcon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(accent(for: insight.accentColorName))
                    .frame(width: 36)

                VStack(alignment: .leading, spacing: 3) {
                    Text(insight.localizedTitle(locale: appSettingsManager.interfaceLocale))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                    Text(insight.localizedDescription(locale: appSettingsManager.interfaceLocale))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(themeManager.labelSecondary(for: colorScheme))
                        .lineLimit(2)
                }

                Spacer()

                Text(insight.localizedValue(locale: appSettingsManager.interfaceLocale))
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundColor(accent(for: insight.accentColorName))
            }
            .padding(14)
            .dashboardMaterialPillAuxCardLabel()
        }
        .buttonStyle(BuxDashboardCardButtonStyle())
        .buxDashboardCategoryCard(index: index, direction: categorySlideDirection, motionToken: categoryMotionToken)
    }

    private func accent(for name: String) -> Color {
        switch name {
        case "red": return .red
        case "green": return .green
        case "orange": return .orange
        case "blue": return .blue
        case "purple": return .purple
        default: return themeManager.contrastAccentColor(for: colorScheme)
        }
    }
}

// MARK: - Money Map (widgets + insights unified)

struct MoneyMapDashboardPanel: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @EnvironmentObject private var brain: BuxMuseBrain
    @EnvironmentObject private var financialBridge: FinancialEngineBridge
    @EnvironmentObject private var insightsViewModel: InsightsViewModel
    @EnvironmentObject private var studioStore: StudioStore
    @EnvironmentObject private var navigationCoordinator: NavigationCoordinator

    @ObservedObject private var settingsStore = SettingsStore.shared

    let categorySlideDirection: Int
    let categoryMotionToken: UUID
    var onOpenStudioSettings: (() -> Void)?

    @State private var showFullMoneyMap = false
    @State private var graph: MoneyMapGraph?

    private var graphRefreshToken: String {
        let tx = financialBridge.engine.allTransactions().count
        let insights = insightsViewModel.rankedInsights.count
        let strips = insightsViewModel.featureStrips.count
        return "\(tx)-\(insights)-\(strips)-\(settingsStore.studioEnabled)-\(studioStore.projects.count)-\(studioStore.invoices.count)-\(appSettingsManager.selectedCountry.id)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BuxTokens.block) {
            if let graph {
                miniPreviewCard(graph: graph)

                Button(action: { showFullMoneyMap = true }) {
                    HStack(spacing: 10) {
                        Image(systemName: "map.fill")
                            .font(.system(size: 18, weight: .bold))
                        VStack(alignment: .leading, spacing: 2) {
                            BuxCatalogText.text("Open full Money Map")
                                .font(.system(size: 15, weight: .black))
                            Text(
                                BuxLocalizedString.format(
                                    "%lld territories · charts · Pro lanes · insights",
                                    locale: appSettingsManager.interfaceLocale,
                                    graph.nodes.count
                                )
                            )
                                .font(.system(size: 11, weight: .medium))
                                .opacity(0.85)
                        }
                        Spacer()
                        Image(systemName: "arrow.up.right.circle.fill")
                            .font(.system(size: 22, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(BuxTokens.section)
                    .background(
                        LinearGradient(
                            colors: [themeManager.current.accentColor, .purple.opacity(0.85)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(BuxDashboardCardButtonStyle())
                .buxDashboardCategoryCard(index: 1, direction: categorySlideDirection, motionToken: categoryMotionToken)
            }
        }
        .task(id: graphRefreshToken) {
            graph = buildGraph()
        }
        .fullScreenCover(isPresented: $showFullMoneyMap) {
            MoneyMapFullView(onOpenStudioSettings: onOpenStudioSettings)
                .environmentObject(themeManager)
                .environmentObject(appSettingsManager)
                .environmentObject(brain)
                .environmentObject(financialBridge)
                .environmentObject(insightsViewModel)
                .environmentObject(studioStore)
                .environmentObject(navigationCoordinator)
        }
        .transition(.buxCategorySlide(direction: categorySlideDirection))
    }

    private func buildGraph() -> MoneyMapGraph {
        MoneyMapBuilder.build(
            snapshot: brain.expenseInteractionSnapshot,
            transactions: financialBridge.engine.allTransactions(),
            insights: insightsViewModel.rankedInsights,
            featureStrips: insightsViewModel.featureStrips,
            settings: settingsStore,
            projects: studioStore.projects,
            invoices: studioStore.invoices,
            format: { appSettingsManager.format($0) }
        )
    }

    private func miniPreviewCard(graph: MoneyMapGraph) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                BuxCatalogText.text("Money Map")
                    .buxSectionLabelStyle(color: themeManager.sectionHeaderColor(for: colorScheme))
                Spacer()
                if graph.isProEnriched {
                    ProFeatureBadge(compact: true)
                }
            }
            .padding(.horizontal, 4)

            MoneyMapMiniPreview(
                graph: graph,
                onExpandRequested: { showFullMoneyMap = true }
            )
                .environmentObject(themeManager)
        }
        .buxDashboardCategoryCard(index: 0, direction: categorySlideDirection, motionToken: categoryMotionToken)
    }
}

/// Dashboard mini preview — always reflects the shared layout store.
private struct MoneyMapMiniPreview: View {
    let graph: MoneyMapGraph
    var onExpandRequested: (() -> Void)?

    var body: some View {
        MoneyMapCanvasView(
            graph: graph,
            mode: .mini,
            allowsNodeSelection: false,
            onExpandRequested: onExpandRequested
        )
    }
}

// MARK: - Studio intelligence summary for Money Map / Studio hub

struct StudioIntelligenceSummaryCard: View {
    let projects: [StudioProject]
    let transactions: [Transaction]

    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @ObservedObject private var settings = SettingsStore.shared
    @ObservedObject private var burnoutEngine = BurnoutEngine.shared

    var body: some View {
        let scopedProjects = HustleWorkspaceFilter.filter(projects) { $0.hustleId }
        let scopedTxs = HustleWorkspaceFilter.filter(transactions) { $0.hustleId }
        let monthSpend = scopedTxs
            .filter { $0.amount.value < 0 && $0.date >= (Calendar.current.dateInterval(of: .month, for: Date())?.start ?? Date()) }
            .reduce(Decimal(0)) { $0 + abs($1.amount.value) }
        let workHours = scopedProjects.flatMap(\.timeEntries).reduce(0.0) { $0 + $1.duration / 3600.0 }
        let burnoutHours = settings.burnoutGuardEnabled ? burnoutEngine.currentStatus.workHours : 0
        let scopeAlerts = ScopeCreepInsightsEngine.generateInsights(
            projects: scopedProjects,
            locale: appSettingsManager.interfaceLocale
        ).count
        let workspaceName = HustleWorkspaceFilter.activeWorkspaceLabel()
            ?? BuxCatalogLabel.string("All workspaces", locale: appSettingsManager.interfaceLocale)

        BuxCard(elevation: .card, cornerRadius: 18, padding: BuxTokens.section) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(
                        BuxLocalizedString.format(
                            "Studio · %@",
                            locale: appSettingsManager.interfaceLocale,
                            workspaceName
                        )
                    )
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                    Spacer()
                    if settings.antiScopeCreepEnabled && scopeAlerts > 0 {
                        Label("\(scopeAlerts)", systemImage: "scope")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.red)
                    }
                }

                HStack(spacing: 16) {
                    metricColumn(titleKey: "Workspace spend", value: appSettingsManager.format(monthSpend))
                    metricColumn(
                        titleKey: "Tracked hours",
                        value: settings.burnoutGuardEnabled
                            ? BuxLocalizedString.format(
                                "%.1f h / %.1f h",
                                locale: appSettingsManager.interfaceLocale,
                                workHours,
                                burnoutHours
                            )
                            : BuxLocalizedString.format(
                                "%.1fh",
                                locale: appSettingsManager.interfaceLocale,
                                workHours
                            )
                    )
                    metricColumn(
                        titleKey: "Energy",
                        value: settings.burnoutGuardEnabled ? "\(Int(burnoutEngine.currentStatus.creativeEnergyPercent))%" : "—"
                    )
                }

                if settings.burnoutGuardEnabled && settings.antiScopeCreepEnabled {
                    Text(
                        BuxLocalizedString.format(
                            "Workload %@h vs project time %@h · Scope alerts %lld",
                            locale: appSettingsManager.interfaceLocale,
                            String(format: "%.1f", burnoutHours),
                            String(format: "%.1f", workHours),
                            scopeAlerts
                        )
                    )
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(themeManager.labelSecondary(for: colorScheme))
                }
            }
        }
    }

    private func metricColumn(titleKey: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            BuxCatalogText.text(titleKey)
                .font(.system(size: 9, weight: .bold))
                .textCase(.uppercase)
                .foregroundStyle(themeManager.labelSecondary(for: colorScheme))
                .kerning(0.4)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
            Text(value)
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Workspace Nexus ROI

struct WorkspaceSynergyROIPanel: View {
    let summary: WorkspaceSynergySummary

    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            BuxCatalogText.text("Cross-workspace flows")
                .buxSectionLabelStyle(color: themeManager.sectionHeaderColor(for: colorScheme))
                .padding(.horizontal, 4)

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 16) {
                    metricColumn(
                        titleKey: "Splits this month",
                        value: "\(summary.splitGroupsThisMonth)"
                    )
                    metricColumn(
                        titleKey: "Transfer lanes",
                        value: "\(summary.flows.count)"
                    )
                }

                if summary.flows.isEmpty {
                    BuxCatalogText.text("No owner transfers logged yet. Use Nexus bridge when adding an entry.")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(themeManager.labelSecondary(for: colorScheme))
                } else {
                    ForEach(summary.flows.prefix(3)) { flow in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(flow.sourceName) → \(flow.targetName)")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                                Text(
                                    BuxLocalizedString.format(
                                        "%lld transfers",
                                        locale: appSettingsManager.interfaceLocale,
                                        flow.eventCount
                                    )
                                )
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(themeManager.labelSecondary(for: colorScheme))
                            }
                            Spacer()
                            Text(appSettingsManager.format(flow.totalAmount))
                            .font(.system(size: 14, weight: .black, design: .rounded))
                            .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                        }
                    }
                }
            }
            .padding(BuxTokens.section)
            .dashboardMaterialCardChrome(.outlined)
        }
    }

    private func metricColumn(titleKey: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            BuxCatalogText.text(titleKey)
                .font(.system(size: 9, weight: .bold))
                .textCase(.uppercase)
                .foregroundStyle(themeManager.labelSecondary(for: colorScheme))
            Text(value)
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundColor(themeManager.labelPrimary(for: colorScheme))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - iPad carousel chrome (iPhone keeps soft horizontal fade)

private struct BuxPadHorizontalFeatureStripChromeModifier: ViewModifier {
    func body(content: Content) -> some View {
        if BuxPadIdiom.isPad {
            content.buxViewAlignedHorizontalCarousel()
        } else {
            content.buxSoftHorizontalScrollChrome()
        }
    }
}
