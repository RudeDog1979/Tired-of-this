//
//  DashboardView.swift
//  BuxMuse
//  Features/Dashboard/
//
//  The Home Dashboard view featuring the balance card, quick actions,
//  and category selection stacked cards.
//

import SwiftUI

struct DashboardView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var appSettingsManager: AppSettingsManager
    @EnvironmentObject var financialBridge: FinancialEngineBridge
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    @EnvironmentObject var brain: BuxMuseBrain
    @EnvironmentObject var goalsViewModel: GoalsViewModel
    @EnvironmentObject var goalsSheetCoordinator: GoalsSheetCoordinator
    @EnvironmentObject var insightsViewModel: InsightsViewModel
    @EnvironmentObject var studioBrain: StudioBrain
    @EnvironmentObject var studioStore: StudioStore

    @ObservedObject private var settingsStore = SettingsStore.shared

    var transactionNamespace: Namespace.ID

    // Category pill horizontal slider expand state
    @State private var isPillSectionExpanded = false
    @State private var expensesPillScale: CGFloat = 1.0
    @State private var isFabMenuExpanded = false
    @State private var categorySlideDirection: Int = 1
    @State private var categoryMotionToken = UUID()
    @State private var activeSheet: DashboardActiveSheet?
    @State private var showQuickNewInvoice = false
    @State private var showTipPopup = false
    @State private var tipGlowPhase = false

    private var dashSnapshot: DashboardSnapshot { brain.dashboardSnapshot }

    /// Keeps hero sizing proportional on narrow phones (fixed 82×4 slots were overflowing the card).
    private var heroLayoutScale: CGFloat {
        min(1, UIScreen.main.bounds.width / 430)
    }

    var body: some View {
        NavigationStack {
            dashboardRoot
        }
    }

    private var dashboardRoot: some View {
        ZStack {
            BuxLandingTintBackground()
                .ignoresSafeArea()
            // Scroll view containing page elements
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: BuxTokens.block) {
                    VStack(alignment: .leading, spacing: BuxTokens.block) {
                        DashboardHeroSection(
                            dashSnapshot: dashSnapshot,
                            heroLayoutScale: heroLayoutScale,
                            activeSheet: $activeSheet,
                            isFabMenuExpanded: $isFabMenuExpanded,
                            showTipPopup: $showTipPopup,
                            tipGlowPhase: $tipGlowPhase
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)

                        HustleSelectorBar()
                            .padding(.bottom, 4)

                        VStack(alignment: .leading, spacing: BuxTokens.tight) {
                                if let budgetName = dashSnapshot.activeBudgetName {
                                    let limit = dashSnapshot.activeBudgetLimit
                                    let spent = dashSnapshot.activeBudgetSpent
                                    let remaining = limit - spent
                                    let progress = limit > 0 ? min(1.0, max(0.0, Double(NSDecimalNumber(decimal: spent).doubleValue / NSDecimalNumber(decimal: limit).doubleValue))) : 0.0
                                    let warnBudget = settingsStore.showBudgetWarnings && progress > 0.9
                                    
                                    Button(action: {
                                        withAnimation {
                                            navigationCoordinator.selectedTab = .settings
                                        }
                                    }) {
                                        VStack(alignment: .leading, spacing: 12) {
                                            HStack {
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text(
                                                        BuxLocalizedString.format(
                                                            "Active budget: %@",
                                                            locale: appSettingsManager.interfaceLocale,
                                                            budgetName
                                                        )
                                                    )
                                                        .buxSectionLabelStyle(color: themeManager.current.accentColor)
                                                    
                                                    Text(
                                                        BuxLocalizedString.format(
                                                            "%@ left of %@",
                                                            locale: appSettingsManager.interfaceLocale,
                                                            appSettingsManager.format(remaining),
                                                            appSettingsManager.format(limit)
                                                        )
                                                    )
                                                        .font(.system(size: 16, weight: .bold))
                                                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                                                }
                                                
                                                Spacer()
                                                
                                                Text(
                                                    BuxLocalizedString.format(
                                                        "%lld%% spent",
                                                        locale: appSettingsManager.interfaceLocale,
                                                        Int(progress * 100)
                                                    )
                                                )
                                                    .font(.system(size: 12, weight: .bold))
                                                    .foregroundColor(warnBudget ? .red : themeManager.labelSecondary(for: colorScheme))
                                            }
                                            
                                            // Progress Bar
                                            GeometryReader { geometry in
                                                ZStack(alignment: .leading) {
                                                    RoundedRectangle(cornerRadius: 4)
                                                        .fill(Color(.systemGray5).opacity(colorScheme == .dark ? 0.35 : 0.55))
                                                        .frame(height: 8)
                                                    
                                                    RoundedRectangle(cornerRadius: 4)
                                                        .fill(LinearGradient(
                                                            colors: warnBudget ? [.red, .orange] : [themeManager.current.accentColor, themeManager.current.accentColor.opacity(0.7)],
                                                            startPoint: .leading,
                                                            endPoint: .trailing
                                                        ))
                                                        .frame(width: geometry.size.width * CGFloat(progress), height: 8)
                                                }
                                            }
                                            .frame(height: 8)
                                        }
                                        .padding(BuxTokens.section)
                                        .dashboardMaterialCardChrome(.outlined)
                                    }
                                    .buttonStyle(BuxDashboardCardButtonStyle())
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                } else {
                                    // Empty state: No active budget profile
                                    Button(action: {
                                        withAnimation {
                                            navigationCoordinator.selectedTab = .settings
                                        }
                                    }) {
                                        VStack(alignment: .leading, spacing: 8) {
                                            HStack {
                                                Image(systemName: "chart.pie.fill")
                                                    .foregroundColor(themeManager.current.accentColor)
                                                BuxCatalogText.text("No Active Budget Profile")
                                                    .font(.system(size: 13, weight: .bold))
                                                    .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                                                Spacer()
                                                BuxChevron()
                                            }
                                            
                                            Text(
                                                BuxLocalizedString.format(
                                                    "You have enabled %@ budgeting mode, but do not have an active budget profile yet. Tap here to configure a profile in App Settings.",
                                                    locale: appSettingsManager.interfaceLocale,
                                                    settingsStore.budgetingMode.localizedDisplayName(locale: appSettingsManager.interfaceLocale)
                                                )
                                            )
                                                .font(.system(size: 11, weight: .medium))
                                                .foregroundStyle(themeManager.labelSecondary(for: colorScheme))
                                                .multilineTextAlignment(.leading)
                                        }
                                        .padding(BuxTokens.section)
                                        .dashboardMaterialCardChrome(.outlined)
                                    }
                                    .buttonStyle(BuxDashboardCardButtonStyle())
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))

                        if settingsStore.studioEnabled {
                            StudioDashboardWidget()
                                .environmentObject(themeManager)
                                .environmentObject(navigationCoordinator)
                                .environmentObject(studioBrain)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        if !settingsStore.studioEnabled, !settingsStore.studioDiscoveryOfferDismissed {
                            StudioDiscoveryCard()
                                .environmentObject(themeManager)
                                .environmentObject(navigationCoordinator)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        CategoryPillBar(
                            activeCategory: $navigationCoordinator.activeCategoryPill,
                            isExpanded: $isPillSectionExpanded,
                            usesDashboardTint: true
                        )
                        .environmentObject(themeManager)
                        .frame(maxWidth: .infinity, alignment: .center)

                        // Category content — horizontal slide + bounce (original behavior)
                        ZStack(alignment: .topLeading) {
                            if navigationCoordinator.activeCategoryPill == "Expenses" {
                                let expenseHeader = brain.expenseInteractionSnapshot.header
                                let monthlyTotal = Decimal(expenseHeader.totalSpent)
                                let changeVsLast = expenseHeader.changeVsLastMonth
                                let txnCount = expenseHeader.monthlyTransactionCount
                                let changeFormatted = appSettingsManager.format(Decimal(abs(changeVsLast)))
                                let changeTrend = changeVsLast >= 0 ? "+\(changeFormatted)" : "-\(changeFormatted)"
                                let changeColor: Color = changeVsLast >= 0 ? .orange : .green

                                HStack(alignment: .top, spacing: BuxTokens.tight) {
                                    Button(action: {
                                        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                                            navigationCoordinator.openExpensesTab()
                                        }
                                    }) {
                                        SubscriptionSummaryCardView(
                                            title: BuxLocalizedString.string("This Month", locale: appSettingsManager.interfaceLocale),
                                            cost: appSettingsManager.format(monthlyTotal),
                                            subtext: expenseHeader.biggestCategory.map {
                                                BuxLocalizedString.format(
                                                    "Top: %@",
                                                    locale: appSettingsManager.interfaceLocale,
                                                    $0
                                                )
                                            } ?? BuxLocalizedString.string("All categories", locale: appSettingsManager.interfaceLocale),
                                            trendText: changeTrend,
                                            trendColor: changeColor,
                                            icon: "creditcard.fill",
                                            iconColor: themeManager.current.accentColor,
                                            includesDashboardChrome: false
                                        )
                                        .dashboardMaterialPillCardLabel()
                                    }
                                    .buttonStyle(BuxDashboardCardButtonStyle())
                                    .buxDashboardCategoryCard(
                                        index: 0,
                                        direction: categorySlideDirection,
                                        motionToken: categoryMotionToken
                                    )
                                    .offset(y: navigationCoordinator.isScreenLoaded ? 0 : 50)
                                    .opacity(navigationCoordinator.isScreenLoaded ? 1.0 : 0.0)
                                    .animation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.05), value: navigationCoordinator.isScreenLoaded)

                                    Button(action: {
                                        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                                            navigationCoordinator.openExpensesTab()
                                        }
                                    }) {
                                        SubscriptionSummaryCardView(
                                            title: BuxLocalizedString.string("Transactions", locale: appSettingsManager.interfaceLocale),
                                            cost: BuxLocalizedString.format(
                                                "%lld This Month",
                                                locale: appSettingsManager.interfaceLocale,
                                                txnCount
                                            ),
                                            subtext: expenseHeader.biggestMerchant.map {
                                                BuxLocalizedString.format(
                                                    "Top: %@",
                                                    locale: appSettingsManager.interfaceLocale,
                                                    $0
                                                )
                                            } ?? BuxLocalizedString.string("All merchants", locale: appSettingsManager.interfaceLocale),
                                            trendText: expenseHeader.microInsight
                                                ?? BuxLocalizedString.string("On track", locale: appSettingsManager.interfaceLocale),
                                            trendColor: themeManager.current.accentColor,
                                            icon: "list.bullet.rectangle.fill",
                                            iconColor: themeManager.current.accentColor,
                                            includesDashboardChrome: false
                                        )
                                        .dashboardMaterialPillCardLabel()
                                    }
                                    .buttonStyle(BuxDashboardCardButtonStyle())
                                    .buxDashboardCategoryCard(
                                        index: 1,
                                        direction: categorySlideDirection,
                                        motionToken: categoryMotionToken
                                    )
                                    .offset(y: navigationCoordinator.isScreenLoaded ? 0 : 50)
                                    .opacity(navigationCoordinator.isScreenLoaded ? 1.0 : 0.0)
                                    .animation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.12), value: navigationCoordinator.isScreenLoaded)
                                }
                                .transition(.buxCategorySlide(direction: categorySlideDirection))
                            } else if navigationCoordinator.activeCategoryPill == "Subscriptions" {
                                let activeSubs = financialBridge.activeSubscriptions()
                                HStack(alignment: .top, spacing: BuxTokens.tight) {
                                    if activeSubs.isEmpty {
                                        HStack {
                                            Image(systemName: "sparkles")
                                                .foregroundColor(themeManager.current.accentColor)
                                                BuxCatalogText.text("No active subscriptions. Tapping quick action opens Subscription Hub.")
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundStyle(themeManager.labelSecondary(for: colorScheme))
                                                .multilineTextAlignment(.center)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 32)
                                        .dashboardMaterialCardChrome(.outlined)
                                        .buxDashboardCategoryCard(
                                            index: 0,
                                            direction: categorySlideDirection,
                                            motionToken: categoryMotionToken
                                        )
                                    } else {
                                        ForEach(Array(activeSubs.prefix(2).enumerated()), id: \.offset) { index, sub in
                                            Button(action: {
                                                withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                                                    navigationCoordinator.openSubscriptionHub()
                                                }
                                            }) {
                                                SubscriptionCardView(
                                                    title: sub.merchantName,
                                                    cost: appSettingsManager.format(abs(sub.cost.value)),
                                                    billingDate: sub.billingCycle.localizedDisplayName(
                                                        locale: appSettingsManager.interfaceLocale
                                                    ),
                                                    accentColor: index == 0 ? themeManager.current.accentColor : Color.purple,
                                                    includesDashboardChrome: false
                                                )
                                                .dashboardMaterialPillCardLabel()
                                            }
                                            .buttonStyle(BuxDashboardCardButtonStyle())
                                            .buxDashboardCategoryCard(
                                                index: index,
                                                direction: categorySlideDirection,
                                                motionToken: categoryMotionToken
                                            )
                                        }
                                    }
                                }
                                .transition(.buxCategorySlide(direction: categorySlideDirection))
                            } else if navigationCoordinator.activeCategoryPill == "Goals" {
                                VStack(alignment: .leading, spacing: 16) {
                                    HStack {
                                        BuxCatalogText.text("Active savings goals")
                                            .buxSectionLabelStyle(color: themeManager.sectionHeaderColor(for: colorScheme))
                                        
                                        Spacer()
                                        
                                        Button(action: {
                                            goalsSheetCoordinator.presentAddGoal()
                                        }) {
                                            HStack(spacing: 4) {
                                                Image(systemName: "plus.circle.fill")
                                                    .font(.system(size: 14, weight: .bold))
                                                BuxCatalogText.text("Add Goal")
                                                    .font(.system(size: 12, weight: .bold))
                                            }
                                            .foregroundColor(themeManager.current.accentColor)
                                        }
                                        .buttonStyle(BuxMicroShrinkStyle())
                                    }
                                    .padding(.horizontal, 4)
                                    
                                    if goalsViewModel.goals.isEmpty {
                                        HStack {
                                            Spacer()
                                            VStack(spacing: 8) {
                                                Image(systemName: "target")
                                                    .font(.system(size: 24))
                                                    .foregroundColor(themeManager.labelSecondary(for: colorScheme))
                                                BuxCatalogText.text("No active savings goals yet.")
                                                    .font(.system(size: 13, weight: .medium))
                                                    .foregroundStyle(themeManager.labelSecondary(for: colorScheme))
                                            }
                                            Spacer()
                                        }
                                        .padding(.vertical, 32)
                                        .dashboardMaterialCardChrome(.outlined)
                                        .buxDashboardCategoryCard(
                                            index: 0,
                                            direction: categorySlideDirection,
                                            motionToken: categoryMotionToken
                                        )
                                    } else {
                                        ScrollView(.horizontal, showsIndicators: false) {
                                            HStack(spacing: BuxTokens.tight) {
                                                ForEach(Array(goalsViewModel.goals.enumerated()), id: \.element.id) { index, goal in
                                                    let progress = min(1.0, max(0.0, Double(NSDecimalNumber(decimal: goal.currentAmount).doubleValue / max(1.0, NSDecimalNumber(decimal: goal.targetAmount).doubleValue))))
                                                    let accentColor = index == 0 ? Color(red: 46/255, green: 204/255, blue: 113/255) : themeManager.current.accentColor
                                                    
                                                    Button(action: {
                                                        goalsViewModel.selectGoal(goal)
                                                        if let detail = goalsViewModel.selectedGoalDetail {
                                                            goalsSheetCoordinator.presentGoalDetail(detail)
                                                        }
                                                    }) {
                                                        GoalCardView(
                                                            title: goal.name,
                                                            saved: appSettingsManager.format(goal.currentAmount),
                                                            target: appSettingsManager.format(goal.targetAmount),
                                                            progress: progress,
                                                            accentColor: accentColor,
                                                            includesDashboardChrome: false
                                                        )
                                                        .dashboardMaterialPillCardLabel()
                                                    }
                                                    .buttonStyle(BuxDashboardCardButtonStyle())
                                                    .buxDashboardCategoryCard(
                                                        index: index,
                                                        direction: categorySlideDirection,
                                                        motionToken: categoryMotionToken
                                                    )
                                                    .offset(y: navigationCoordinator.isScreenLoaded ? 0 : 50)
                                                    .opacity(navigationCoordinator.isScreenLoaded ? 1.0 : 0.0)
                                                    .animation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.05 + Double(index) * 0.07), value: navigationCoordinator.isScreenLoaded)
                                                }
                                            }
                                            .padding(.horizontal, 2)
                                        }

                                        Button(action: {
                                            if let firstGoal = goalsViewModel.goals.first {
                                                goalsViewModel.selectGoal(firstGoal)
                                                if let detail = goalsViewModel.selectedGoalDetail {
                                                    goalsSheetCoordinator.presentGoalDetail(detail)
                                                }
                                            }
                                        }) {
                                            HStack {
                                                Image(systemName: "chart.bar.fill")
                                                    .font(.system(size: 16))
                                                    .foregroundColor(themeManager.current.accentColor)
                                                
                                                VStack(alignment: .leading, spacing: 2) {
                                                    BuxCatalogText.text("See your progress")
                                                        .font(.system(size: 13, weight: .bold))
                                                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                                                    BuxCatalogText.text("Get structural forecast and potential acceleration timeline AI insights.")
                                                        .font(.system(size: 11, weight: .medium))
                                                        .foregroundStyle(themeManager.labelSecondary(for: colorScheme))
                                                }
                                                .multilineTextAlignment(.leading)
                                                
                                                Spacer()
                                                
                                                BuxChevron()
                                            }
                                            .padding(16)
                                            .dashboardMaterialPillAuxCardLabel()
                                        }
                                        .buttonStyle(BuxDashboardCardButtonStyle())
                                        .buxDashboardCategoryCard(
                                            index: 1,
                                            direction: categorySlideDirection,
                                            motionToken: categoryMotionToken
                                        )
                                    }
                                }
                                .transition(.buxCategorySlide(direction: categorySlideDirection))
                            } else if navigationCoordinator.activeCategoryPill == "Insights" {
                                DashboardInsightsPanel(
                                    categorySlideDirection: categorySlideDirection,
                                    categoryMotionToken: categoryMotionToken,
                                    isScreenLoaded: navigationCoordinator.isScreenLoaded,
                                    onOpenStudioSettings: openStudioSettings
                                )
                                .environmentObject(themeManager)
                                .environmentObject(insightsViewModel)
                            } else if navigationCoordinator.activeCategoryPill == "Money Map" {
                                MoneyMapDashboardPanel(
                                    categorySlideDirection: categorySlideDirection,
                                    categoryMotionToken: categoryMotionToken,
                                    onOpenStudioSettings: openStudioSettings
                                )
                                .environmentObject(themeManager)
                                .environmentObject(appSettingsManager)
                                .environmentObject(brain)
                                .environmentObject(financialBridge)
                                .environmentObject(insightsViewModel)
                                .environmentObject(studioStore)
                                .environmentObject(navigationCoordinator)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .id(navigationCoordinator.activeCategoryPill)
                        .animation(.buxCategorySpring, value: navigationCoordinator.activeCategoryPill)
                        .onChange(of: navigationCoordinator.activeCategoryPill) { oldValue, newValue in
                            let oldIndex = categoryIndex(for: oldValue)
                            let newIndex = categoryIndex(for: newValue)
                            categorySlideDirection = newIndex >= oldIndex ? 1 : -1
                            withAnimation(.buxCategorySpring) {
                                categoryMotionToken = UUID()
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    // Buxmation Focus overlays: blurs and dims elements above stack on expansion
                    .blur(radius: goalsSheetCoordinator.showGoalDetail ? 5 : 0)
                    .opacity(goalsSheetCoordinator.showGoalDetail ? 0.45 : 1.0)
                    .scaleEffect(goalsSheetCoordinator.showGoalDetail ? 0.95 : 1.0)
                    .animation(.spring(response: 0.45, dampingFraction: 0.75), value: goalsSheetCoordinator.showGoalDetail)
                    
                    RecentTransactionsSectionView(
                        transactions: dashSnapshot.recentTransactions,
                        onSeeMore: { navigationCoordinator.openExpensesTab() }
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .offset(y: navigationCoordinator.isScreenLoaded ? 0 : 30)
                    .opacity(navigationCoordinator.isScreenLoaded ? 1.0 : 0.0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.24), value: navigationCoordinator.isScreenLoaded)
                    .animation(nil, value: navigationCoordinator.activeCategoryPill)

                    Spacer().frame(height: BuxTokens.tight)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, BuxTokens.section)
                .environment(\.dashboardEnhancedTint, true)
            }
            .buxRootTabScrollChrome()
            .coordinateSpace(name: "dashboard_scroll")
            .onTapGesture {
                // Tapping scroll area collapses category and transaction bars
                if isPillSectionExpanded {
                    withAnimation(.spring(response: 0.52, dampingFraction: 0.58)) {
                        isPillSectionExpanded = false
                    }
                }
            }
            .onChange(of: navigationCoordinator.selectedTab) { _, tab in
                guard tab != .home, isPillSectionExpanded else { return }
                withAnimation(.spring(response: 0.52, dampingFraction: 0.58)) {
                    isPillSectionExpanded = false
                }
            }
            
            // FAB Submenu
            if isFabMenuExpanded {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isFabMenuExpanded = false
                        }
                    }
                    .zIndex(5)

                VStack(spacing: 12) {
                    Spacer()
                    VStack(spacing: 12) {
                        FabSubmenuItem(title: "Manual Entry", icon: "square.and.pencil", delay: 0.04) {
                            closeFabAnd { activeSheet = .addExpense(.add) }
                        }
                        FabSubmenuItem(title: "Select Category", icon: "tag.fill", delay: 0.08) {
                            closeFabAnd { activeSheet = .addExpense(.addWithCategoryFocus) }
                        }
                        FabSubmenuItem(title: "Manage Categories", icon: "folder.fill", delay: 0.09) {
                            closeFabAnd { activeSheet = .categoryList }
                        }

                        if settingsStore.studioEnabled {
                            FabSubmenuDivider(title: "Studio", delay: 0.10)

                            FabSubmenuItem(title: "Scan Receipt", icon: "camera.fill", delay: 0.12) {
                                closeFabAnd { activeSheet = .addExpense(.addWithAutoScan) }
                            }
                            FabSubmenuItem(title: "New Invoice", icon: "plus.rectangle.fill.on.folder.fill", delay: 0.16) {
                                closeFabAnd { showQuickNewInvoice = true }
                            }
                        }
                    }
                }
                .padding(.horizontal, BuxLayout.marginHorizontal)
                .zIndex(6)
            }

            if showTipPopup, !brain.dailyTipDisplay.isEmpty {
                TipPopupView(tip: brain.dailyTipDisplay) {
                    showTipPopup = false
                    brain.markDailyTipSeen()
                }
                .zIndex(20)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .buxRootNavigationChrome()
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .addExpense(let mode):
                AddExpenseSheet(brain: brain, settingsManager: appSettingsManager, mode: mode)
                    .environmentObject(brain)
                    .environmentObject(themeManager)
                    .environmentObject(appSettingsManager)
                    .environment(\.expensesEnhancedTint, true)
            case .categoryList:
                ExpenseCategoryListSheet()
                    .environmentObject(brain)
                    .environmentObject(themeManager)
                    .buxThemedSheetContent()
            case .scanReceipt:
                StudioReceiptScannerView()
                    .environmentObject(studioStore)
                    .environmentObject(studioBrain)
                    .environmentObject(appSettingsManager)
                    .environmentObject(themeManager)
                    .buxThemedSheetContent()
            case .notificationInbox:
                NotificationInboxView()
                    .environmentObject(brain)
                    .environmentObject(themeManager)
                    .environmentObject(navigationCoordinator)
                    .buxThemedSheetContent()
            }
        }
        .onChange(of: navigationCoordinator.openTipPopupRequest) { _, request in
            guard request else { return }
            navigationCoordinator.openTipPopupRequest = false
            withAnimation(BuxMotion.tipPopupPresent) {
                showTipPopup = true
            }
        }
        .fullScreenCover(isPresented: $showQuickNewInvoice) {
            StudioInvoiceEditorView(invoiceToEdit: nil)
                .environmentObject(studioStore)
                .environmentObject(studioBrain)
                .environmentObject(appSettingsManager)
                .environmentObject(themeManager)
        }
    }

    private func closeFabAnd(_ action: @escaping () -> Void) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isFabMenuExpanded = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            action()
        }
    }

    private func openStudioSettings() {
        navigationCoordinator.openStudioSettings()
    }

    private func categoryIndex(for name: String) -> Int {
        switch name {
        case "Expenses": return 0
        case "Subscriptions": return 1
        case "Goals": return 2
        case "Insights": return 3
        case "Money Map": return 4
        default: return 0
        }
    }
}


// MARK: - Hero card (isolated scroll collapse — avoids commit hitches on Money Map / pills)

private struct DashboardHeroSection: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @EnvironmentObject private var navigationCoordinator: NavigationCoordinator
    @EnvironmentObject private var brain: BuxMuseBrain

    @ObservedObject private var settingsStore = SettingsStore.shared

    let dashSnapshot: DashboardSnapshot
    let heroLayoutScale: CGFloat

    @Binding var activeSheet: DashboardActiveSheet?
    @Binding var isFabMenuExpanded: Bool
    @Binding var showTipPopup: Bool
    @Binding var tipGlowPhase: Bool

    /// Local only — scroll collapse must not invalidate Money Map / category pills.
    @State private var scrollOffset: CGFloat = 0

    private var heroCardPadding: CGFloat {
        heroLayoutScale < 0.92 ? BuxTokens.section : BuxTokens.block
    }

    private var heroAvatarSize: CGFloat {
        collapseValue(start: 66 * heroLayoutScale, end: 52 * heroLayoutScale)
    }

    private var heroBellSize: CGFloat {
        collapseValue(start: 50 * heroLayoutScale, end: 44 * heroLayoutScale)
    }

    private var heroBellIconSize: CGFloat {
        max(16, 18 * heroLayoutScale)
    }

    private var heroActionDiameter: CGFloat {
        58 * heroLayoutScale
    }

    private var heroActionIconSize: CGFloat {
        max(18, 22 * heroLayoutScale)
    }

    var body: some View {
        BuxCard(elevation: .hero, cornerRadius: BuxTokens.Radius.sheet, padding: heroCardPadding) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .center, spacing: 0) {
                    HStack(spacing: 12) {
                        Button(action: { navigationCoordinator.openProfileSettings() }) {
                            BuxUserAvatarView(size: heroAvatarSize)
                        }
                        .buttonStyle(BuxmationPressCardStyle())
                        .accessibilityLabel("Profile settings")

                        Text(settingsStore.resolvedDisplayName)
                            .font(.system(size: collapseValue(start: 16, end: 14), weight: .bold))
                            .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                            .lineLimit(1)
                    }

                    Spacer(minLength: 12)

                    heroNotificationBell
                }
                .padding(.top, collapseValue(start: 8, end: 0))
                .opacity(max(0, 1.0 + (scrollOffset / 140.0)))

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        let balanceTitle = {
                            switch settingsStore.budgetingMode {
                            case .simple:
                                return BuxLocalizedString.string("Remaining budget", locale: appSettingsManager.interfaceLocale)
                            case .envelope, .custom:
                                if dashSnapshot.activeBudgetName != nil {
                                    return BuxLocalizedString.string("Remaining budget", locale: appSettingsManager.interfaceLocale)
                                } else {
                                    return BuxLocalizedString.string(
                                        "Total balance (no active budget)",
                                        locale: appSettingsManager.interfaceLocale
                                    )
                                }
                            }
                        }()

                        Text(balanceTitle)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(themeManager.labelSecondary(for: colorScheme))
                            .opacity(max(0, 1.0 + (scrollOffset / 100.0)))

                        Button(action: {
                            withAnimation { navigationCoordinator.isBalanceVisible.toggle() }
                        }) {
                            Image(systemName: navigationCoordinator.isBalanceVisible ? "eye" : "eye.slash")
                                .font(.system(size: 12))
                                .foregroundStyle(themeManager.labelSecondary(for: colorScheme))
                        }
                        .opacity(max(0, 1.0 + (scrollOffset / 100.0)))
                    }

                    let balanceToFormat: Decimal = {
                        switch settingsStore.budgetingMode {
                        case .simple:
                            return dashSnapshot.activeBudgetLimit - dashSnapshot.activeBudgetSpent
                        case .envelope, .custom:
                            if dashSnapshot.activeBudgetName != nil {
                                return dashSnapshot.activeBudgetLimit - dashSnapshot.activeBudgetSpent
                            } else {
                                return dashSnapshot.totalBalance
                            }
                        }
                    }()

                    Text(navigationCoordinator.isBalanceVisible ? appSettingsManager.format(balanceToFormat) : "\(appSettingsManager.selectedCurrency.symbol) ••••••••")
                        .font(.system(size: collapseValue(start: 38, end: 24), weight: .semibold, design: .rounded))
                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                        .offset(y: collapseValue(start: 0, end: -10))
                }
                .padding(.top, BuxTokens.section + BuxTokens.tight)

                HStack(spacing: 0) {
                    BuxHeroQuickActionButton(
                        action: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.62)) {
                                isFabMenuExpanded.toggle()
                            }
                        },
                        diameter: heroActionDiameter,
                        title: "Expense",
                        titleFont: .system(size: max(11, 12 * heroLayoutScale), weight: .medium),
                        titleColor: themeManager.labelSecondary(for: colorScheme)
                    ) { isPressed in
                        Image(systemName: "plus")
                            .font(.system(size: heroActionIconSize, weight: .semibold))
                            .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                            .buxHeroActionIcon(.plus(isExpanded: isFabMenuExpanded), isPressed: isPressed)
                    }
                    .buxScreenEntrance(index: 0, isVisible: navigationCoordinator.isScreenLoaded)

                    BuxHeroQuickActionButton(
                        action: { activeSheet = .addExpense(.addIncome) },
                        diameter: heroActionDiameter,
                        title: "Income",
                        titleFont: .system(size: max(11, 12 * heroLayoutScale), weight: .medium),
                        titleColor: themeManager.labelSecondary(for: colorScheme)
                    ) { isPressed in
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: heroActionIconSize + 2))
                            .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                            .buxHeroActionIcon(.income, isPressed: isPressed)
                    }
                    .buxScreenEntrance(index: 1, isVisible: navigationCoordinator.isScreenLoaded)

                    BuxHeroQuickActionButton(
                        action: {
                            withAnimation(BuxMotion.tipPopupPresent) {
                                showTipPopup = true
                            }
                        },
                        diameter: heroActionDiameter,
                        title: "Tips",
                        titleFont: .system(size: max(11, 12 * heroLayoutScale), weight: .medium),
                        titleColor: themeManager.labelSecondary(for: colorScheme),
                        circleShadowColor: brain.tipNeedsAttention && tipGlowPhase ? Color.yellow.opacity(0.55) : .clear,
                        circleShadowRadius: 12
                    ) { isPressed in
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: heroActionIconSize))
                            .foregroundColor(brain.tipNeedsAttention ? .yellow : themeManager.contrastAccentColor(for: colorScheme))
                            .buxHeroActionIcon(.tips, isPressed: isPressed)
                    }
                    .onChange(of: brain.tipPulseToken) { _, _ in
                        guard brain.tipNeedsAttention else { return }
                        withAnimation(.easeInOut(duration: 0.45).repeatCount(2, autoreverses: true)) {
                            tipGlowPhase = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            tipGlowPhase = false
                        }
                    }
                    .buxScreenEntrance(index: 2, isVisible: navigationCoordinator.isScreenLoaded)

                    BuxHeroQuickActionButton(
                        action: {
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                                navigationCoordinator.openSubscriptionHub()
                            }
                        },
                        diameter: heroActionDiameter,
                        title: "Subscriptions",
                        titleFont: .system(size: max(11, 12 * heroLayoutScale), weight: .medium),
                        titleColor: themeManager.labelSecondary(for: colorScheme)
                    ) { isPressed in
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: heroActionIconSize, weight: .semibold))
                            .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                            .buxHeroActionIcon(.subscriptions, isPressed: isPressed)
                    }
                    .buxScreenEntrance(index: 3, isVisible: navigationCoordinator.isScreenLoaded)
                }
                .padding(.top, BuxTokens.block + BuxTokens.tight)
                .padding(.bottom, BuxTokens.section)
                .offset(y: collapseValue(start: 0, end: -15))
            }
        }
        .background {
            GeometryReader { geo in
                Color.clear.preference(
                    key: ScrollOffsetPreferenceKey.self,
                    value: geo.frame(in: .named("dashboard_scroll")).minY
                )
            }
        }
        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
            let next = value < 0 ? max(-150, value) : 0
            let stepped = (next / 8).rounded() * 8
            guard abs(stepped - scrollOffset) >= 7 else { return }
            scrollOffset = stepped
        }
    }

    private var heroNotificationBell: some View {
        let diameter = heroBellSize
        let hasUnread = brain.notificationInboxDisplay.unreadCount > 0

        return Button(action: { activeSheet = .notificationInbox }) {
            Image(systemName: hasUnread ? "bell.fill" : "bell")
                .font(.system(size: heroBellIconSize, weight: .semibold))
                .foregroundStyle(themeManager.contrastAccentColor(for: colorScheme))
                .frame(width: diameter, height: diameter)
        }
        .buxHeroGlassCircleButtonStyle(diameter: diameter)
        .frame(width: diameter, height: diameter)
        .accessibilityLabel(hasUnread ? "Notifications, unread" : "Notifications")
    }

    private func collapseValue(start: CGFloat, end: CGFloat) -> CGFloat {
        let range = start - end
        let factor = min(1.0, max(0.0, -scrollOffset / 100.0))
        return start - (range * factor)
    }
}


// MARK: - Default user avatar

struct BuxUserAvatarView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @ObservedObject private var settings = SettingsStore.shared

    var size: CGFloat = 44

    var body: some View {
        if let data = settings.profileAvatarData, let img = UIImage(data: data) {
            Image(uiImage: img)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(themeManager.contrastAccentColor(for: colorScheme).opacity(0.35), lineWidth: 1.5)
                )
        } else {
            ZStack {
                Circle()
                    .fill(themeManager.cardFill(for: colorScheme))
                    .frame(width: size, height: size)
                    .overlay(
                        Circle()
                            .stroke(themeManager.contrastAccentColor(for: colorScheme).opacity(0.35), lineWidth: 1.5)
                    )
                Image(systemName: "person.fill")
                    .font(.system(size: size * 0.38, weight: .semibold))
                    .foregroundStyle(themeManager.contrastAccentColor(for: colorScheme))
            }
        }
    }
}

// MARK: - Dashboard sheets

private enum DashboardActiveSheet: Identifiable {
    case addExpense(ExpenseSheetMode)
    case categoryList
    case scanReceipt
    case notificationInbox

    var id: String {
        switch self {
        case .addExpense(let mode): return "expense-\(mode.id)"
        case .categoryList: return "categoryList"
        case .scanReceipt: return "scanReceipt"
        case .notificationInbox: return "notificationInbox"
        }
    }
}

// MARK: - FAB Submenu Item Component
struct FabSubmenuItem: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var themeManager: ThemeManager
    let title: String
    let icon: String
    let delay: Double
    let action: () -> Void

    @State private var animateIn = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Spacer()

                BuxCatalogDynamicText(key: title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(colorScheme == .dark ? Color(red: 24/255, green: 26/255, blue: 32/255) : .white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)

                ZStack {
                    Circle()
                        .fill(themeManager.current.accentColor)
                        .frame(width: 40, height: 40)

                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
            }
        }
        .buttonStyle(.plain)
        .offset(y: animateIn ? 0 : 30)
        .opacity(animateIn ? 1.0 : 0.0)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75).delay(delay)) {
                animateIn = true
            }
        }
    }
}

struct FabSubmenuDivider: View {
    @Environment(\.colorScheme) var colorScheme
    let title: String
    let delay: Double

    @State private var animateIn = false

    var body: some View {
        HStack(spacing: 12) {
            Spacer()
            BuxCatalogDynamicText(key: title)
                .buxSectionLabelStyle(color: colorScheme == .dark ? .white.opacity(0.45) : .gray)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.04))
                .clipShape(Capsule())
        }
        .offset(y: animateIn ? 0 : 20)
        .opacity(animateIn ? 1.0 : 0.0)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75).delay(delay)) {
                animateIn = true
            }
        }
    }
}
