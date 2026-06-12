//
//  BuxPadExternalMoneyMapHost.swift
//  BuxMuse — Read-only Money Map for external display (controls stay on iPad).
//

import SwiftUI

struct BuxPadExternalMoneyMapHost: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @EnvironmentObject private var brain: BuxMuseBrain
    @EnvironmentObject private var financialBridge: FinancialEngineBridge
    @EnvironmentObject private var insightsViewModel: InsightsViewModel
    @EnvironmentObject private var studioStore: StudioStore
    @EnvironmentObject private var padBrain: BuxPadNavigationBrain

    @ObservedObject private var settingsStore = SettingsStore.shared

    @State private var graph: MoneyMapGraph?
    @State private var appeared = false

    private var graphRefreshToken: String {
        let tx = financialBridge.engine.allTransactions().count
        let insights = insightsViewModel.rankedInsights.count
        let strips = insightsViewModel.featureStrips.count
        return "\(tx)-\(insights)-\(strips)-\(settingsStore.studioEnabled)-\(studioStore.projects.count)-\(studioStore.invoices.count)-\(padBrain.externalPresentationRevision)"
    }

    var body: some View {
        ZStack {
            BuxLandingTintBackground()
                .ignoresSafeArea()

            if let graph {
                VStack(spacing: BuxTokens.block) {
                    BuxCatalogText.text("Money Map")
                        .font(.system(size: 28, weight: .black))
                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, BuxTokens.marginRegular)

                    MoneyMapCanvasView(
                        graph: graph,
                        mode: .full,
                        motionPaused: false,
                        onNodeSelected: { _ in }
                    )
                    .environmentObject(themeManager)
                    .buxScreenEntrance(index: 0, isVisible: appeared)
                    .padding(.horizontal, BuxTokens.marginRegular)
                }
            } else {
                ProgressView()
            }
        }
        .task(id: graphRefreshToken) {
            graph = MoneyMapBuilder.build(
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
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
                appeared = true
            }
        }
    }
}
