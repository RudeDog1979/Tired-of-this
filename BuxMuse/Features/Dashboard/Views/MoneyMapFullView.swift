//
//  MoneyMapFullView.swift
//  BuxMuse
//
//  Full-screen Money Map — the complete financial landscape.
//

import SwiftUI

struct MoneyMapFullView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @EnvironmentObject private var brain: BuxMuseBrain
    @EnvironmentObject private var financialBridge: FinancialEngineBridge
    @EnvironmentObject private var insightsViewModel: InsightsViewModel
    @EnvironmentObject private var studioStore: StudioStore
    @EnvironmentObject private var navigationCoordinator: NavigationCoordinator

    @ObservedObject private var settingsStore = SettingsStore.shared

    var onOpenStudioSettings: (() -> Void)?

    @State private var detailNode: MoneyMapNode?
    @State private var appeared = false
    @State private var isMapAtHome = true
    @State private var isMapScrolling = false
    @State private var scrollIdle = MoneyMapScrollIdleCoordinator()
    @State private var graph: MoneyMapGraph?
    /// Stable token — must not be `UUID()` inline or scroll updates re-trigger card entrance.
    @State private var insightsPanelMotionToken = UUID()

    private var isMapMotionPaused: Bool {
        detailNode != nil || isMapScrolling || !isMapAtHome
    }

    var body: some View {
        NavigationStack {
            ZStack {
                BuxLandingTintBackground()
                    .ignoresSafeArea()

                if let graph {
                    moneyMapScrollContent(graph: graph)
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .task(id: graphRefreshToken) {
                graph = buildGraph()
            }
            .navigationTitle("Money Map")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    BuxToolbarCancelButton { dismiss() }
                }
            }
            .buxDetailNavigationChrome()
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
                    appeared = true
                }
            }
            .sheet(item: $detailNode) { node in
                if let graph {
                    MoneyMapNodeDetailSheet(
                        node: node,
                        graph: graph,
                        onDeepLink: { link in
                            detailNode = nil
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                handleDeepLink(link)
                            }
                        }
                    )
                    .environmentObject(themeManager)
                    .environmentObject(appSettingsManager)
                    .environmentObject(insightsViewModel)
                }
            }
        }
    }

    private var graphRefreshToken: String {
        let tx = financialBridge.engine.allTransactions().count
        let insights = insightsViewModel.rankedInsights.count
        let strips = insightsViewModel.featureStrips.count
        return "\(tx)-\(insights)-\(strips)-\(settingsStore.studioEnabled)-\(settingsStore.burnoutGuardEnabled)-\(studioStore.projects.count)-\(studioStore.invoices.count)"
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

    @ViewBuilder
    private func moneyMapScrollContent(graph: MoneyMapGraph) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: BuxTokens.block) {
                heroBanner(graph: graph)

                MoneyMapCanvasView(
                    graph: graph,
                    mode: .full,
                    motionPaused: isMapMotionPaused,
                    onNodeSelected: { node in
                        detailNode = node
                    }
                )
                .environmentObject(themeManager)
                .buxScreenEntrance(index: 0, isVisible: appeared)

                if graph.isProEnriched {
                    proLegend
                        .buxScreenEntrance(index: 1, isVisible: appeared)
                }

                DashboardInsightsPanel(
                    categorySlideDirection: 0,
                    categoryMotionToken: insightsPanelMotionToken,
                    isScreenLoaded: true,
                    showsFeatureStrips: true,
                    onOpenStudioSettings: {
                        dismiss()
                        onOpenStudioSettings?()
                    }
                )
                .environmentObject(themeManager)
                .environmentObject(insightsViewModel)
                .buxScreenEntrance(index: 2, isVisible: appeared)

                if settingsStore.burnoutGuardEnabled {
                    BurnoutDashboardWidget()
                        .environmentObject(themeManager)
                        .environmentObject(appSettingsManager)
                        .environmentObject(financialBridge)
                        .environmentObject(insightsViewModel)
                        .environmentObject(studioStore)
                        .buxScreenEntrance(index: 3, isVisible: appeared)
                }

                if settingsStore.studioEnabled && settingsStore.dualCashDrawerEnabled {
                    DualCashDrawerWidget()
                        .environmentObject(themeManager)
                        .environmentObject(navigationCoordinator)
                        .buxScreenEntrance(index: 4, isVisible: appeared)
                }

                if settingsStore.studioEnabled {
                    StudioIntelligenceSummaryCard(
                        projects: studioStore.projects,
                        transactions: financialBridge.engine.allTransactions()
                    )
                    .environmentObject(themeManager)
                    .environmentObject(appSettingsManager)
                    .buxScreenEntrance(index: 5, isVisible: appeared)
                }

                Spacer(minLength: BuxTokens.section)
            }
            .padding(.horizontal, BuxTokens.marginRegular)
            .padding(.top, BuxTokens.tight)
            .padding(.bottom, BuxOverlayMetrics.scrollBottomInset)
        }
        .buxDetailScrollChrome()
        .onScrollGeometryChange(for: MoneyMapScrollActivity.self) { geometry in
            let y = max(0, geometry.contentOffset.y)
            return MoneyMapScrollActivity(offsetBucket: Int((y / 8).rounded()))
        } action: { _, activity in
            scrollIdle.generation += 1
            let generation = scrollIdle.generation

            if !isMapScrolling {
                isMapScrolling = true
            }

            let atHome = MoneyMapScrollHome.isAtHome(scrollOffsetY: activity.offsetY)
            if atHome != isMapAtHome {
                isMapAtHome = atHome
            }

            let settle = atHome ? MoneyMapMotionAnimation.scrollSettleAtHome : 0.12
            DispatchQueue.main.asyncAfter(deadline: .now() + settle) {
                guard generation == scrollIdle.generation else { return }
                isMapScrolling = false
            }
        }
    }

    private func handleDeepLink(_ link: MoneyMapDeepLink) {
        dismiss()
        switch link {
        case .insightsPill:
            navigationCoordinator.selectedTab = .home
            navigationCoordinator.activeCategoryPill = "Insights"
        case .studioTab:
            navigationCoordinator.selectedTab = .studio
        case .studioSettings:
            navigationCoordinator.openStudioSettings()
        case .subscriptionHub:
            navigationCoordinator.openSubscriptionHub()
        case .expensesTab:
            navigationCoordinator.openExpensesTab()
        case .paymentSettings:
            navigationCoordinator.openPaymentSettings()
        }
    }

    private func heroBanner(graph: MoneyMapGraph) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    BuxCatalogText.text("FULL TERRITORY VIEW")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(themeManager.current.accentColor)
                        .kerning(0.8)
                    Text(graph.centerValue)
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                    Text(
                        BuxLocalizedString.format(
                            "Spent this month across %lld live territories",
                            locale: appSettingsManager.interfaceLocale,
                            graph.nodes.count
                        )
                    )
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(themeManager.labelSecondary(for: colorScheme))
                }
                Spacer()
                Image(systemName: "map.fill")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [themeManager.current.accentColor, .purple.opacity(0.85)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        }
        .padding(BuxTokens.section)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dashboardMaterialCardChrome(.filled, cornerRadius: BuxTokens.Radius.hero)
    }

    private var proLegend: some View {
        HStack(spacing: 8) {
            ProFeatureBadge(compact: true)
            BuxCatalogText.text("Pro territories show merchants, scope radar, invoices, mileage, and more as you enable Studio tools.")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(themeManager.labelSecondary(for: colorScheme))
        }
        .padding(.horizontal, 4)
    }
}
