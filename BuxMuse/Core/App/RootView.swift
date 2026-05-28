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

    @State private var isAppLocked = false
    @State private var lastUnlockDate = Date()
    @State private var hasUnlockedThisSession = false
    @State private var didEnterBackground = false

    var body: some View {
        ZStack {
            themeManager.screenBackground(for: colorScheme)
                .ignoresSafeArea()

            buxMuseTabView

            overlayStack
        }
        .overlay(alignment: .bottom) {
            BuxDockAnchoredTabBar(
                selectedTab: $navigationCoordinator.selectedTab,
                studioEnabled: settingsStore.studioEnabled,
                accentColor: themeManager.current.accentColor
            )
        }
        .overlay(alignment: .top) {
            ConnectivityToastView()
                .environmentObject(themeManager)
                .allowsHitTesting(ConnectivityBrain.shared.activeToast != nil)
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.85, blendDuration: 0), value: navigationCoordinator.showSubscriptionHub)
        .buxRootBrandTheme()
        .sheet(item: $goalsSheetCoordinator.activeSheet) { sheet in
            switch sheet {
            case .addGoal:
                AddGoalSheet()
                    .environmentObject(themeManager)
                    .environmentObject(appSettingsManager)
                    .environmentObject(goalsViewModel)
                    .environmentObject(goalsSheetCoordinator)
                    .environmentObject(insightsViewModel)
                    .buxThemedPresentation()
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                navigationCoordinator.isScreenLoaded = true
            }
            evaluateAppLock(forceOnLaunch: true)
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background:
                didEnterBackground = true
                StudioTimerDisplayMonitor.shared.handleSceneEnteredBackground()
            case .inactive:
                StudioTimerDisplayMonitor.shared.handleSceneBecameInactive()
            case .active:
                StudioTimerDisplayMonitor.shared.handleSceneBecameActive()
                if didEnterBackground {
                    evaluateAppLock(forceOnLaunch: false)
                    didEnterBackground = false
                }
            @unknown default:
                break
            }
        }
        .onChange(of: navigationCoordinator.selectedTab) { _, newTab in
            navigationCoordinator.registerTabSelection()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
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
        .onChange(of: settingsStore.studioEnabled) { _, enabled in
            if !enabled && navigationCoordinator.selectedTab == .studio {
                navigationCoordinator.selectedTab = .home
            }
        }
    }

    private var buxMuseTabView: some View {
        coreTabView
            .toolbar(.hidden, for: .tabBar)
            .toolbarBackground(.hidden, for: .tabBar)
            .background(BuxNativeTabBarSuppressor())
            .ignoresSafeArea(edges: .bottom)
    }

    private var coreTabView: some View {
        TabView(selection: $navigationCoordinator.selectedTab) {
            Tab(value: AppTab.home) {
                DashboardView(transactionNamespace: transactionNamespace)
            } label: {
                hiddenTabLabel
            }

            Tab(value: AppTab.expense) {
                ExpenseTabView()
            } label: {
                hiddenTabLabel
            }

            if settingsStore.studioEnabled {
                Tab(value: AppTab.studio) {
                    StudioHubView()
                        .environmentObject(themeManager)
                        .environmentObject(appSettingsManager)
                        .environmentObject(navigationCoordinator)
                } label: {
                    hiddenTabLabel
                }
            }

            Tab(value: AppTab.settings) {
                SettingsView()
            } label: {
                hiddenTabLabel
            }
        }
    }

    private var hiddenTabLabel: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
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
                            .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                    }
                )
                .transition(.opacity)
                .zIndex(999)
        }

        if isAppLocked && scenePhase == .active {
            BuxAppLockOverlay {
                unlockApp()
            }
            .environmentObject(themeManager)
            .transition(.opacity)
            .zIndex(1000)
        }
    }

    private func evaluateAppLock(forceOnLaunch: Bool) {
        guard settingsStore.biometricLockEnabled else {
            isAppLocked = false
            return
        }
        guard settingsStore.requireBiometricOnLaunch || settingsStore.hasAppPasscode else {
            isAppLocked = false
            return
        }

        var shouldLock = false
        if forceOnLaunch, settingsStore.requireBiometricOnLaunch, !hasUnlockedThisSession {
            shouldLock = true
        } else if settingsStore.requireBiometricOnLaunch {
            shouldLock = true
        } else if settingsStore.lockAfterInactivityMinutes == 0 {
            shouldLock = true
        } else {
            let threshold = Double(settingsStore.lockAfterInactivityMinutes * 60)
            shouldLock = Date().timeIntervalSince(lastUnlockDate) >= threshold
        }

        isAppLocked = shouldLock
    }

    private func unlockApp() {
        hasUnlockedThisSession = true
        lastUnlockDate = Date()
        isAppLocked = false
    }
}
