//
//  RootView.swift
//  BuxMuse
//
//  Tab router and overlay orchestration — no app data stored here.
//

import SwiftUI

struct RootView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var container: AppContainer
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @EnvironmentObject private var financialBridge: FinancialEngineBridge
    @EnvironmentObject private var navigationCoordinator: NavigationCoordinator
    @EnvironmentObject private var goalsSheetCoordinator: GoalsSheetCoordinator
    @EnvironmentObject private var goalsViewModel: GoalsViewModel
    @EnvironmentObject private var insightsViewModel: InsightsViewModel
    @EnvironmentObject private var brain: BuxMuseBrain
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var settingsStore = SettingsStore.shared
    @Namespace private var transactionNamespace

    var body: some View {
        ZStack {
            themeManager.screenBackground(for: colorScheme)
                .ignoresSafeArea()

            buxMuseTabView

            overlayStack
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.85, blendDuration: 0), value: navigationCoordinator.showSubscriptionHub)
        .sheet(item: $goalsSheetCoordinator.activeSheet) { sheet in
            switch sheet {
            case .addGoal:
                AddGoalSheet()
                    .environmentObject(themeManager)
                    .environmentObject(appSettingsManager)
                    .environmentObject(goalsViewModel)
                    .environmentObject(goalsSheetCoordinator)
                    .environmentObject(insightsViewModel)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                navigationCoordinator.isScreenLoaded = true
            }
        }
        .onChange(of: navigationCoordinator.selectedTab) { _, newTab in
            if newTab != .expense {
                navigationCoordinator.dismissExpenseSearch()
            }
            brain.persistPreferences(navigation: navigationCoordinator, appSettings: appSettingsManager)
        }
        .onChange(of: navigationCoordinator.activeCategoryPill) { _, _ in
            brain.persistPreferences(navigation: navigationCoordinator, appSettings: appSettingsManager)
        }
        .onChange(of: navigationCoordinator.isBalanceVisible) { _, _ in
            brain.persistPreferences(navigation: navigationCoordinator, appSettings: appSettingsManager)
        }
        .onChange(of: settingsStore.freelanceEnabled) { _, enabled in
            if !enabled && navigationCoordinator.selectedTab == .freelance {
                navigationCoordinator.selectedTab = .home
            }
        }
    }

    @ViewBuilder
    private var buxMuseTabView: some View {
        if #available(iOS 26, *) {
            coreTabView
                .tabBarMinimizeBehavior(.onScrollDown)
        } else {
            coreTabView
        }
    }

    private var coreTabView: some View {
        TabView(selection: $navigationCoordinator.selectedTab) {
            Tab("Home", systemImage: "house", value: AppTab.home) {
                DashboardView(transactionNamespace: transactionNamespace)
            }

            Tab("Expense", systemImage: "creditcard", value: AppTab.expense) {
                ExpenseTabView()
            }

            if settingsStore.freelanceEnabled {
                Tab("Freelance", systemImage: "briefcase", value: AppTab.freelance) {
                    FreelanceHubView()
                        .environmentObject(themeManager)
                        .environmentObject(appSettingsManager)
                }
            }

            Tab("Settings", systemImage: "gearshape", value: AppTab.settings) {
                SettingsView()
            }
        }
        .tint(themeManager.current.accentColor)
    }

    @ViewBuilder
    private var overlayStack: some View {
        if let cardType = navigationCoordinator.selectedCryptoCard {
            CardExpansionDetailView(cardType: cardType, isPresented: $navigationCoordinator.selectedCryptoCard)
                .transition(.opacity)
                .zIndex(15)
        }

        if navigationCoordinator.showSubscriptionHub {
            SubscriptionHubView(
                isPresented: $navigationCoordinator.showSubscriptionHub,
                engine: financialBridge.engine,
                settingsManager: appSettingsManager,
                hubSnapshot: brain.subscriptionHubSnapshot
            )
            .transition(.asymmetric(
                insertion: .move(edge: .trailing),
                removal: .move(edge: .trailing)
            ))
            .zIndex(10)
        }

        if goalsSheetCoordinator.showGoalDetail, let detail = goalsSheetCoordinator.selectedGoalDetail {
            GoalDetailView(
                detail: detail,
                onAddContribution: { goalId, amount, notes in
                    goalsViewModel.addContribution(toGoalId: goalId, amount: amount, notes: notes)
                },
                onDeleteGoal: { goalId in
                    goalsViewModel.deleteGoal(id: goalId)
                },
                isPresented: Binding(
                    get: { goalsSheetCoordinator.showGoalDetail },
                    set: { isShown in
                        if !isShown {
                            goalsSheetCoordinator.dismissGoalDetail()
                        }
                    }
                )
            )
            .transition(.asymmetric(
                insertion: .move(edge: .bottom).combined(with: .opacity),
                removal: .move(edge: .bottom).combined(with: .opacity)
            ))
            .zIndex(10)
        }

        if insightsViewModel.showInsightDetail, let selectedInsight = insightsViewModel.selectedInsight {
            InsightDetailView(
                insight: selectedInsight,
                isPresented: Binding(
                    get: { insightsViewModel.showInsightDetail },
                    set: { isShown in
                        if !isShown {
                            insightsViewModel.dismissInsightDetail()
                        }
                    }
                )
            )
            .transition(.asymmetric(
                insertion: .move(edge: .bottom).combined(with: .opacity),
                removal: .move(edge: .bottom).combined(with: .opacity)
            ))
            .zIndex(10)
        }

        if settingsStore.privacyBlurInAppSwitching && (scenePhase == .inactive || scenePhase == .background) {
            Color.clear
                .background(.ultraThickMaterial)
                .ignoresSafeArea()
                .overlay(
                    VStack(spacing: 16) {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 48))
                            .foregroundColor(themeManager.current.accentColor)
                        Text("BuxMuse Vault Active")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(colorScheme == .dark ? .white : .black)
                    }
                )
                .transition(.opacity)
                .zIndex(999)
        }
    }
}
