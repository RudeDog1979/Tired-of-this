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
    @EnvironmentObject private var padNavigationBrain: BuxPadNavigationBrain
    @Environment(\.buxLayoutMode) private var buxLayoutMode
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var settingsStore = SettingsStore.shared
    @Namespace private var transactionNamespace

    @State private var isAppLocked = false
    @State private var lastUnlockDate = Date()
    @State private var hasUnlockedThisSession = false
    @State private var didEnterBackground = false

    var body: some View {
        Group {
            if BuxPadIdiom.isPad {
                BuxPadShell {
                    coreTabView
                }
            } else {
                coreTabView
            }
        }
            .tutorialCoachMarkOverlay(
                layer: .root,
                coordinator: container.tutorialCoordinator,
                reservesTabBarSpace: !BuxPadIdiom.isPad
            )
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
                if !BuxPadIdiom.isPad {
                    ExpenseUndoToastView()
                        .environmentObject(themeManager)
                        .environmentObject(brain)
                        .zIndex(1100)
                }
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
            .onChange(of: settingsStore.hasCompletedOnboarding) { _, completed in
                guard completed else { return }
                container.tutorialCoordinator.consumeAutoStartIfNeeded()
            }
            .onChange(of: navigationCoordinator.showStudioUnlockAnimation) { _, isShowing in
                if !isShowing {
                    navigationCoordinator.finishStudioUnlockPresentation()
                }
            }
            .animation(.spring(response: 0.45, dampingFraction: 0.85, blendDuration: 0), value: navigationCoordinator.showSubscriptionHub)
            .animation(.spring(response: 0.45, dampingFraction: 0.85, blendDuration: 0), value: navigationCoordinator.showDebtHub)
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
                container.tutorialCoordinator.attach(
                    navigationCoordinator: navigationCoordinator,
                    appSettingsManager: appSettingsManager
                )
                withAnimation(.easeOut(duration: 0.5)) {
                    navigationCoordinator.isScreenLoaded = true
                }
                evaluateAppLock(forceOnLaunch: true)
                container.tutorialCoordinator.consumeAutoStartIfNeeded()
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
                    if settingsStore.personalCloudSyncEnabled {
                        Task { await PersonalCloudSyncEngine.shared.syncNow() }
                    }
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
            .buxPadRootChrome(isPad: BuxPadIdiom.isPad)
            .buxPadCommandBridge(isPad: BuxPadIdiom.isPad)
            .buxPadExternalDisplayBridge(isPad: BuxPadIdiom.isPad)
            .buxPadAdaptiveSheet(
                isPresented: $navigationCoordinator.showSubscriptionHub,
                trigger: .subscriptionHub
            ) {
                BuxPadSubscriptionHubHost(
                    isPresented: $navigationCoordinator.showSubscriptionHub,
                    engine: financialBridge.engine,
                    settingsManager: appSettingsManager,
                    hubSnapshot: brain.subscriptionHubSnapshot
                )
                .environmentObject(themeManager)
                .buxThemedSheetContent()
            }
            .buxPadAdaptiveSheet(
                isPresented: Binding(
                    get: { goalsSheetCoordinator.showGoalDetail },
                    set: { isShown in
                        if !isShown { goalsSheetCoordinator.dismissGoalDetail() }
                    }
                ),
                trigger: .goalDetail
            ) {
                if let detail = goalsSheetCoordinator.selectedGoalDetail {
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
                                if !isShown { goalsSheetCoordinator.dismissGoalDetail() }
                            }
                        )
                    )
                    .environmentObject(themeManager)
                    .environmentObject(appSettingsManager)
                    .environmentObject(goalsViewModel)
                    .buxThemedSheetContent()
                }
            }
            .buxPadAdaptiveSheet(
                isPresented: Binding(
                    get: { insightsViewModel.showInsightDetail },
                    set: { isShown in
                        if !isShown { insightsViewModel.dismissInsightDetail() }
                    }
                ),
                trigger: .insightDetail
            ) {
                if let selectedInsight = insightsViewModel.selectedInsight {
                    InsightDetailView(
                        insight: selectedInsight,
                        isPresented: Binding(
                            get: { insightsViewModel.showInsightDetail },
                            set: { isShown in
                                if !isShown { insightsViewModel.dismissInsightDetail() }
                            }
                        )
                    )
                    .environmentObject(themeManager)
                    .environmentObject(appSettingsManager)
                    .buxThemedSheetContent()
                }
            }
    }

    private var coreTabView: some View {
        TabView(selection: $navigationCoordinator.selectedTab) {
            Tab(value: AppTab.home) {
                if BuxPadIdiom.isPad {
                    BuxPadHomeHost(transactionNamespace: transactionNamespace)
                } else {
                    DashboardView(transactionNamespace: transactionNamespace)
                }
            } label: {
                BuxTabBarLabel(titleKey: "Home", systemImage: AppTab.home.nativeTabSymbol)
            }

            Tab(value: AppTab.expense) {
                if BuxPadIdiom.isPad {
                    BuxPadExpenseHost()
                } else {
                    ExpenseTabView()
                }
            } label: {
                BuxTabBarLabel(titleKey: "Expenses", systemImage: AppTab.expense.nativeTabSymbol)
            }

            if settingsStore.studioEnabled {
                Tab(value: AppTab.studio) {
                    if BuxPadIdiom.isPad {
                        BuxPadStudioHost()
                            .environmentObject(themeManager)
                            .environmentObject(appSettingsManager)
                            .environmentObject(navigationCoordinator)
                            .environmentObject(financialBridge)
                            .environmentObject(container.studioStore)
                            .environmentObject(container.studioBrain)
                            .environmentObject(container.simpleStudioStore)
                            .environmentObject(container.simpleStudioBrain)
                            .environmentObject(container.taxEnvelopeBrain)
                            .environmentObject(container.appDataManager)
                            .environmentObject(padNavigationBrain)
                    } else {
                        StudioHubView()
                            .environmentObject(themeManager)
                            .environmentObject(appSettingsManager)
                            .environmentObject(navigationCoordinator)
                            .environmentObject(financialBridge)
                            .environmentObject(container.studioStore)
                            .environmentObject(container.studioBrain)
                            .environmentObject(container.simpleStudioStore)
                            .environmentObject(container.simpleStudioBrain)
                    }
                } label: {
                    BuxTabBarLabel(titleKey: "Studio", systemImage: AppTab.studio.nativeTabSymbol)
                }
            }

            Tab(value: AppTab.settings) {
                if BuxPadIdiom.isPad {
                    BuxPadSettingsHost()
                        .environmentObject(container.studioStore)
                        .environmentObject(container.simpleStudioStore)
                } else {
                    SettingsView()
                }
            } label: {
                BuxTabBarLabel(titleKey: "Settings", systemImage: AppTab.settings.nativeTabSymbol)
            }
        }
        .buxNativeTabBarMinimizeOnScroll()
    }

    @ViewBuilder
    private var overlayStack: some View {
        if BuxPadIdiom.isPad {
            padOverlayStack
        } else {
            phoneOverlayStack
        }
    }

    @ViewBuilder
    private var phoneOverlayStack: some View {
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
                hubSnapshot: brain.subscriptionHubSnapshot,
                onCancelSubscription: { name in
                    try? brain.cancelSubscription(merchantName: name)
                }
            )
            .transition(.asymmetric(
                insertion: .move(edge: .trailing),
                removal: .move(edge: .trailing)
            ))
            .zIndex(10)
        }

        if navigationCoordinator.showDebtHub {
            DebtHubView(isPresented: $navigationCoordinator.showDebtHub)
                .environmentObject(themeManager)
                .environmentObject(appSettingsManager)
                .environmentObject(container.debtEngine)
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
                            .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                        Image("BuxMuseLogo")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: 200)
                        BuxCatalogText.text("BuxMuse Vault Active")
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

    @ViewBuilder
    private var padOverlayStack: some View {
        if let cardType = navigationCoordinator.selectedCryptoCard {
            CardExpansionDetailView(cardType: cardType, isPresented: $navigationCoordinator.selectedCryptoCard)
                .transition(.opacity)
                .zIndex(15)
        }

        if navigationCoordinator.showSubscriptionHub {
            padHubOverlay(
                trigger: .subscriptionHub,
                isPresented: navigationCoordinator.showSubscriptionHub,
                onDismiss: { navigationCoordinator.closeSubscriptionHub() }
            ) {
                BuxPadSubscriptionHubHost(
                    isPresented: $navigationCoordinator.showSubscriptionHub,
                    engine: financialBridge.engine,
                    settingsManager: appSettingsManager,
                    hubSnapshot: brain.subscriptionHubSnapshot
                )
                .environmentObject(themeManager)
            }
        }

        if navigationCoordinator.showDebtHub {
            padHubOverlay(
                trigger: .debtHub,
                isPresented: navigationCoordinator.showDebtHub,
                onDismiss: { navigationCoordinator.closeDebtHub() }
            ) {
                DebtHubView(isPresented: $navigationCoordinator.showDebtHub)
                    .environmentObject(themeManager)
                    .environmentObject(appSettingsManager)
                    .environmentObject(container.debtEngine)
            }
        }

        if goalsSheetCoordinator.showGoalDetail, let detail = goalsSheetCoordinator.selectedGoalDetail {
            padHubOverlay(
                trigger: .goalDetail,
                isPresented: goalsSheetCoordinator.showGoalDetail,
                onDismiss: { goalsSheetCoordinator.dismissGoalDetail() }
            ) {
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
                            if !isShown { goalsSheetCoordinator.dismissGoalDetail() }
                        }
                    )
                )
                .environmentObject(themeManager)
                .environmentObject(appSettingsManager)
                .environmentObject(goalsViewModel)
            }
        }

        if insightsViewModel.showInsightDetail, let selectedInsight = insightsViewModel.selectedInsight {
            padHubOverlay(
                trigger: .insightDetail,
                isPresented: insightsViewModel.showInsightDetail,
                onDismiss: { insightsViewModel.dismissInsightDetail() }
            ) {
                InsightDetailView(
                    insight: selectedInsight,
                    isPresented: Binding(
                        get: { insightsViewModel.showInsightDetail },
                        set: { isShown in
                            if !isShown { insightsViewModel.dismissInsightDetail() }
                        }
                    )
                )
                .environmentObject(themeManager)
                .environmentObject(appSettingsManager)
            }
        }

        if settingsStore.privacyBlurInAppSwitching && (scenePhase == .inactive || scenePhase == .background) {
            Color.clear
                .background(.ultraThickMaterial)
                .ignoresSafeArea()
                .overlay(
                    VStack(spacing: 16) {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 48))
                            .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                        Image("BuxMuseLogo")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: 200)
                        BuxCatalogText.text("BuxMuse Vault Active")
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

    @ViewBuilder
    private func padHubOverlay<Content: View>(
        trigger: BuxPadPresentationTrigger,
        isPresented: Bool,
        onDismiss: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        let surface = BuxPadOverlayRouter.surface(for: trigger, layoutMode: buxLayoutMode)
        switch surface {
        case .splitColumn:
            BuxPadInspectorPanel(content: content, onDismiss: onDismiss)
            .zIndex(10)
        case .rootOverlay:
            content()
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .trailing)
                ))
                .zIndex(10)
        case .sheetLarge, .sheetMedium, .popover, .fullScreenCover:
            EmptyView()
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
        if #available(iOS 26, *) {
            tabBarMinimizeBehavior(.onScrollDown)
        } else {
            self
        }
    }
}
