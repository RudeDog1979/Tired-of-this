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
        coreTabView
            .background(themeManager.screenBackground(for: colorScheme))
            .overlay(alignment: .top) {
                ConnectivityToastView()
                    .environmentObject(themeManager)
                    .allowsHitTesting(ConnectivityBrain.shared.activeToast != nil)
            }
            .overlay {
                ExpenseUndoToastView()
                    .environmentObject(themeManager)
                    .environmentObject(brain)
                    .allowsHitTesting(brain.expenseUndoOffer != nil)
            }
            .overlay {
                overlayStack
            }
            .overlay(alignment: .topTrailing) {
                if settingsStore.enableDebugOverlay {
                    BuxDebugOverlay(showMetrics: settingsStore.showPerformanceMetrics)
                }
            }
            .overlay {
                if navigationCoordinator.showStudioUnlockAnimation {
                    StudioUnlockAnimationView(
                        isPresented: $navigationCoordinator.showStudioUnlockAnimation,
                        onMidpointReveal: { navigationCoordinator.commitStudioUnlock() }
                    )
                    .transition(.opacity)
                    .zIndex(200)
                }
            }
            .animation(.easeInOut(duration: 0.45), value: navigationCoordinator.showStudioUnlockAnimation)
            .fullScreenCover(isPresented: $navigationCoordinator.showStudioPersonaPicker) {
                SimpleStudioPersonaPickerView {
                    navigationCoordinator.showStudioPersonaPicker = false
                    navigationCoordinator.selectedTab = .studio
                }
                .environmentObject(themeManager)
            }
            .onChange(of: navigationCoordinator.showStudioUnlockAnimation) { _, isShowing in
                if !isShowing {
                    navigationCoordinator.finishStudioUnlockPresentation()
                }
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
                        .buxThemedSheetContent()
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
                    settingsStore.save()
                    StudioTimerDisplayMonitor.shared.handleSceneEnteredBackground()
                case .inactive:
                    StudioTimerDisplayMonitor.shared.handleSceneBecameInactive()
                case .active:
                    StudioTimerDisplayMonitor.shared.handleSceneBecameActive()
                    if didEnterBackground {
                        evaluateAppLock(forceOnLaunch: false)
                        container.scheduleEngagementRefresh()
                        container.scheduleTipsRefresh()
                        didEnterBackground = false
                    }
                @unknown default:
                    break
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
            .onChange(of: settingsStore.studioEnabled) { _, enabled in
                if !enabled && navigationCoordinator.selectedTab == .studio {
                    navigationCoordinator.selectedTab = .home
                }
            }
    }

    private var coreTabView: some View {
        TabView(selection: $navigationCoordinator.selectedTab) {
            Tab(value: AppTab.home) {
                DashboardView(transactionNamespace: transactionNamespace)
            } label: {
                Label(AppTab.home.nativeTabTitle, systemImage: AppTab.home.nativeTabSymbol)
            }

            Tab(value: AppTab.expense) {
                ExpenseTabView()
            } label: {
                Label(AppTab.expense.nativeTabTitle, systemImage: AppTab.expense.nativeTabSymbol)
            }

            if settingsStore.studioEnabled {
                Tab(value: AppTab.studio) {
                    StudioHubView()
                        .environmentObject(themeManager)
                        .environmentObject(appSettingsManager)
                        .environmentObject(navigationCoordinator)
                        .environmentObject(container.simpleStudioStore)
                        .environmentObject(container.simpleStudioBrain)
                } label: {
                    Label(AppTab.studio.nativeTabTitle, systemImage: AppTab.studio.nativeTabSymbol)
                }
            }

            Tab(value: AppTab.settings) {
                SettingsView()
            } label: {
                Label(AppTab.settings.nativeTabTitle, systemImage: AppTab.settings.nativeTabSymbol)
            }
        }
        .buxNativeTabBarMinimizeOnScroll()
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
            .environmentObject(themeManager)
            .environmentObject(appSettingsManager)
            .environmentObject(goalsViewModel)
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
            .environmentObject(themeManager)
            .environmentObject(appSettingsManager)
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

extension View {
    /// Native tab bar — collapses when scrolling down (iOS 18+).
    @ViewBuilder
    func buxNativeTabBarMinimizeOnScroll() -> some View {
        if #available(iOS 26.0, *) {
            tabBarMinimizeBehavior(.onScrollDown)
        } else {
            self
        }
    }
}
