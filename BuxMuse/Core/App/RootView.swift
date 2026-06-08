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
            .background {
                TaxTranslationSessionBridgeView()
            }
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
                    .environmentObject(appSettingsManager)
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
                .environmentObject(appSettingsManager)
                .environment(\.locale, appSettingsManager.interfaceLocale)
            }
            .fullScreenCover(isPresented: Binding(
                get: { !settingsStore.hasCompletedOnboarding },
                set: { isCompleted in
                    if isCompleted {
                        settingsStore.hasCompletedOnboarding = true
                        settingsStore.save()
                    }
                }
            )) {
                OnboardingWizardView()
                    .environmentObject(themeManager)
                    .environmentObject(appSettingsManager)
                    .buxThemedSheetContent()
            }
            .onChange(of: navigationCoordinator.showStudioUnlockAnimation) { _, isShowing in
                if !isShowing {
                    navigationCoordinator.finishStudioUnlockPresentation()
                }
            }
            .animation(.spring(response: 0.45, dampingFraction: 0.85, blendDuration: 0), value: navigationCoordinator.showSubscriptionHub)
            .buxRootBrandTheme()
            .buxInterfaceLocale()
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
            }
            .onChange(of: settingsStore.studioEnabled) { _, enabled in
                if !enabled && navigationCoordinator.selectedTab == .studio {
                    navigationCoordinator.selectedTab = .home
                }
            }
            .environment(\.locale, appSettingsManager.interfaceLocale)
            .id(appSettingsManager.selectedCountry.id)
    }

    private var coreTabView: some View {
        TabView(selection: $navigationCoordinator.selectedTab) {
            Tab(value: AppTab.home) {
                DashboardView(transactionNamespace: transactionNamespace)
            } label: {
                BuxTabBarLabel(titleKey: "Home", systemImage: AppTab.home.nativeTabSymbol)
            }

            Tab(value: AppTab.expense) {
                ExpenseTabView()
            } label: {
                BuxTabBarLabel(titleKey: "Expenses", systemImage: AppTab.expense.nativeTabSymbol)
            }

            if settingsStore.studioEnabled {
                Tab(value: AppTab.studio) {
                    StudioHubView()
                        .environmentObject(themeManager)
                        .environmentObject(appSettingsManager)
                        .environmentObject(navigationCoordinator)
                        .environmentObject(financialBridge)
                        .environmentObject(container.studioStore)
                        .environmentObject(container.studioBrain)
                        .environmentObject(container.simpleStudioStore)
                        .environmentObject(container.simpleStudioBrain)
                } label: {
                    BuxTabBarLabel(titleKey: "Studio", systemImage: AppTab.studio.nativeTabSymbol)
                }
            }

            Tab(value: AppTab.settings) {
                SettingsView()
            } label: {
                BuxTabBarLabel(titleKey: "Settings", systemImage: AppTab.settings.nativeTabSymbol)
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
