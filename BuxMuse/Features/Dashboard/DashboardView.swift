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
    @EnvironmentObject var freelanceBrain: FreelanceBrain

    @ObservedObject private var settingsStore = SettingsStore.shared

    var transactionNamespace: Namespace.ID

    // Category pill horizontal slider expand state
    @State private var isPillSectionExpanded = false
    @State private var expensesPillScale: CGFloat = 1.0
    @State private var isFabMenuExpanded = false
    @State private var scrollOffset: CGFloat = 0
    @State private var categorySlideDirection: Int = 1
    @State private var categoryMotionToken = UUID()

    private var dashSnapshot: DashboardSnapshot { brain.dashboardSnapshot }

    var body: some View {
        ZStack {
            // Scroll view containing page elements
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: BuxLayout.section) {
                    
                    // Track coordinate offset of top card
                    GeometryReader { geo in
                        Color.clear.preference(
                            key: ScrollOffsetPreferenceKey.self,
                            value: geo.frame(in: .named("dashboard_scroll")).minY
                        )
                    }
                    .frame(height: 0)
                    
                    // Group elements above Transactions to apply Buxmation Darken/Blur
                    VStack(alignment: .leading, spacing: BuxLayout.section) {
                        // Top Custom Header Card with Buxmation Header Collapse
                        ZStack {
                            // Dynamic background brand glow bloomer (Unclipped glowing)
                            ZStack {
                                if colorScheme == .dark {
                                    RadialGradient(
                                        gradient: Gradient(colors: [themeManager.current.accentColor.opacity(0.32), Color.clear]),
                                        center: .bottomTrailing,
                                        startRadius: 10,
                                        endRadius: 400
                                    )
                                    .blur(radius: 20)
                                } else {
                                    RadialGradient(
                                        gradient: Gradient(colors: [themeManager.current.accentColor.opacity(0.20), Color.clear]),
                                        center: .bottomTrailing,
                                        startRadius: 10,
                                        endRadius: 320
                                    )
                                    .blur(radius: 15)
                                }
                                
                                // Main Card Frame
                                if colorScheme == .dark {
                                    RoundedRectangle(cornerRadius: 32)
                                        .fill(Color(red: 22/255, green: 24/255, blue: 31/255))
                                        .overlay(
                                            ZStack {
                                                LinearGradient(
                                                    colors: [themeManager.current.accentColor.opacity(0.15), Color.clear],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                                
                                                RadialGradient(
                                                    gradient: Gradient(colors: [themeManager.current.accentColor.opacity(0.35), Color.clear]),
                                                    center: .bottomTrailing,
                                                    startRadius: 10,
                                                    endRadius: 300
                                                )
                                            }
                                            .clipShape(RoundedRectangle(cornerRadius: 32))
                                        )
                                } else {
                                    RoundedRectangle(cornerRadius: 32)
                                        .fill(LinearGradient(
                                            colors: [
                                                themeManager.current.accentColor.opacity(0.14),
                                                themeManager.current.accentColor.opacity(0.04),
                                                Color.white
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ))
                                        .overlay(
                                            RadialGradient(
                                                gradient: Gradient(colors: [themeManager.current.accentColor.opacity(0.22), Color.clear]),
                                                center: .bottomTrailing,
                                                startRadius: 0,
                                                endRadius: 280
                                            )
                                            .clipShape(RoundedRectangle(cornerRadius: 32))
                                        )
                                }
                            }

                            // Collapsing header details
                            VStack(alignment: .leading, spacing: 24) {
                                
                                // Header row (Avatar + Username) collapses/fades out slightly on scroll
                                HStack {
                                    MitchellSantosAvatarView(size: collapseValue(start: 44, end: 32))
                                    
                                    Text(settingsStore.userDisplayName ?? "Mitchell Santos")
                                        .font(.system(size: collapseValue(start: 15, end: 13), weight: .bold))
                                        .foregroundColor(colorScheme == .dark ? .white : Color(red: 26/255, green: 28/255, blue: 32/255))
                                        .opacity(max(0, 1.0 + (scrollOffset / 140.0)))
                                    
                                    Spacer()
                                    
                                    // Bell Button
                                    ZStack {
                                        Circle()
                                            .fill(colorScheme == .dark ? Color.white.opacity(0.08) : .white)
                                            .frame(width: collapseValue(start: 44, end: 34), height: collapseValue(start: 44, end: 34))
                                            .shadow(color: colorScheme == .dark ? .clear : Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
                                        
                                        Image(systemName: "bell")
                                            .font(.system(size: collapseValue(start: 18, end: 14), weight: .medium))
                                            .foregroundColor(colorScheme == .dark ? .white : .black)
                                        
                                        Circle()
                                            .fill(Color.red)
                                            .frame(width: 5, height: 5)
                                            .offset(x: collapseValue(start: 7, end: 5), y: collapseValue(start: -7, end: -5))
                                    }
                                }
                                .padding(.top, collapseValue(start: 8, end: 0))
                                
                                // Balance Section collapses smoothly
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 6) {
                                        let balanceTitle: String = {
                                            switch settingsStore.budgetingMode {
                                            case .simple:
                                                return "Remaining simple budget"
                                            case .envelope, .custom:
                                                if dashSnapshot.activeBudgetName != nil {
                                                    return "Remaining budget"
                                                } else {
                                                    return "Total balance (no active budget)"
                                                }
                                            }
                                        }()
                                        
                                        Text(balanceTitle)
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : Color(red: 100/255, green: 110/255, blue: 130/255))
                                            .opacity(max(0, 1.0 + (scrollOffset / 100.0)))
                                        
                                        Button(action: {
                                            withAnimation { navigationCoordinator.isBalanceVisible.toggle() }
                                        }) {
                                            Image(systemName: navigationCoordinator.isBalanceVisible ? "eye" : "eye.slash")
                                                .font(.system(size: 12))
                                                .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : Color(red: 100/255, green: 110/255, blue: 130/255))
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
                                        .foregroundColor(colorScheme == .dark ? .white : Color(red: 26/255, green: 28/255, blue: 32/255))
                                        .offset(y: collapseValue(start: 0, end: -10))
                                }
                                
                                // 4 Circular Quick Action Buttons (Updated with custom staggers, Subscriptions, & arrow-down)
                                HStack(spacing: 0) {
                                    // 1. FAB ADD EXPENSE BUTTON
                                    Button(action: {
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                            isFabMenuExpanded.toggle()
                                        }
                                    }) {
                                        VStack(spacing: 8) {
                                            ZStack {
                                                Circle()
                                                    .fill(colorScheme == .dark ? themeManager.current.accentColor.opacity(0.12) : .white)
                                                    .frame(width: 52, height: 52)
                                                    .overlay(
                                                        Circle()
                                                            .stroke(themeManager.current.accentColor.opacity(colorScheme == .dark ? 0.2 : 0.1), lineWidth: 1)
                                                    )
                                                    .shadow(color: colorScheme == .dark ? .clear : themeManager.current.accentColor.opacity(0.08), radius: 8, x: 0, y: 4)
                                                
                                                Image(systemName: "plus")
                                                    .font(.system(size: 20, weight: .semibold))
                                                    .foregroundColor(themeManager.current.accentColor)
                                                    .rotationEffect(.degrees(isFabMenuExpanded ? 45 : 0))
                                            }
                                            
                                            Text("Add expense")
                                                .font(.system(size: 11, weight: .medium))
                                                .foregroundColor(colorScheme == .dark ? .white.opacity(0.7) : Color(red: 70/255, green: 80/255, blue: 95/255))
                                        }
                                        .frame(width: 76)
                                    }
                                    .buttonStyle(BuxmationPressCardStyle())
                                    .offset(y: navigationCoordinator.isScreenLoaded ? 0 : 8)
                                    .opacity(navigationCoordinator.isScreenLoaded ? 1.0 : 0.0)
                                    .animation(.spring(response: 0.4, dampingFraction: 0.75).delay(0.0), value: navigationCoordinator.isScreenLoaded)
                                    
                                    Spacer()
                                    
                                    // 2. Log Income (downward arrow matching request)
                                    Button(action: { print("Log income tapped") }) {
                                        VStack(spacing: 8) {
                                            ZStack {
                                                Circle()
                                                    .fill(colorScheme == .dark ? themeManager.current.accentColor.opacity(0.12) : .white)
                                                    .frame(width: 52, height: 52)
                                                    .overlay(
                                                        Circle()
                                                            .stroke(themeManager.current.accentColor.opacity(colorScheme == .dark ? 0.2 : 0.1), lineWidth: 1)
                                                    )
                                                    .shadow(color: colorScheme == .dark ? .clear : themeManager.current.accentColor.opacity(0.08), radius: 8, x: 0, y: 4)
                                                
                                                Image(systemName: "arrow.down.circle.fill")
                                                    .font(.system(size: 22))
                                                    .foregroundColor(themeManager.current.accentColor)
                                            }
                                            
                                            Text("Log income")
                                                .font(.system(size: 11, weight: .medium))
                                                .foregroundColor(colorScheme == .dark ? .white.opacity(0.7) : Color(red: 70/255, green: 80/255, blue: 95/255))
                                        }
                                        .frame(width: 76)
                                    }
                                    .buttonStyle(BuxmationPressCardStyle())
                                    .offset(y: navigationCoordinator.isScreenLoaded ? 0 : 8)
                                    .opacity(navigationCoordinator.isScreenLoaded ? 1.0 : 0.0)
                                    .animation(.spring(response: 0.4, dampingFraction: 0.75).delay(0.06), value: navigationCoordinator.isScreenLoaded)
                                    
                                    Spacer()
                                    
                                    // 3. Notification
                                    Button(action: { print("Notification tapped") }) {
                                        VStack(spacing: 8) {
                                            ZStack {
                                                Circle()
                                                    .fill(colorScheme == .dark ? themeManager.current.accentColor.opacity(0.12) : .white)
                                                    .frame(width: 52, height: 52)
                                                    .overlay(
                                                        Circle()
                                                            .stroke(themeManager.current.accentColor.opacity(colorScheme == .dark ? 0.2 : 0.1), lineWidth: 1)
                                                    )
                                                    .shadow(color: colorScheme == .dark ? .clear : themeManager.current.accentColor.opacity(0.08), radius: 8, x: 0, y: 4)
                                                
                                                Image(systemName: "bell.fill")
                                                    .font(.system(size: 20))
                                                    .foregroundColor(themeManager.current.accentColor)
                                            }
                                            
                                            Text("Notification")
                                                .font(.system(size: 11, weight: .medium))
                                                .foregroundColor(colorScheme == .dark ? .white.opacity(0.7) : Color(red: 70/255, green: 80/255, blue: 95/255))
                                        }
                                        .frame(width: 76)
                                    }
                                    .buttonStyle(BuxmationPressCardStyle())
                                    .offset(y: navigationCoordinator.isScreenLoaded ? 0 : 8)
                                    .opacity(navigationCoordinator.isScreenLoaded ? 1.0 : 0.0)
                                    .animation(.spring(response: 0.4, dampingFraction: 0.75).delay(0.12), value: navigationCoordinator.isScreenLoaded)
                                    
                                    Spacer()
                                    
                                    // 4. Subscriptions (Replaces Scan with subscription stacked cards logo)
                                    Button(action: {
                                        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                                            navigationCoordinator.openSubscriptionHub()
                                        }
                                    }) {
                                        VStack(spacing: 8) {
                                            ZStack {
                                                Circle()
                                                    .fill(colorScheme == .dark ? themeManager.current.accentColor.opacity(0.12) : .white)
                                                    .frame(width: 52, height: 52)
                                                    .overlay(
                                                        Circle()
                                                            .stroke(themeManager.current.accentColor.opacity(colorScheme == .dark ? 0.2 : 0.1), lineWidth: 1)
                                                    )
                                                    .shadow(color: colorScheme == .dark ? .clear : themeManager.current.accentColor.opacity(0.08), radius: 8, x: 0, y: 4)
                                                
                                                Image(systemName: "arrow.triangle.2.circlepath")
                                                    .font(.system(size: 20, weight: .semibold))
                                                    .foregroundColor(themeManager.current.accentColor)
                                            }
                                            
                                            Text("Subscriptions")
                                                .font(.system(size: 11, weight: .medium))
                                                .foregroundColor(colorScheme == .dark ? .white.opacity(0.7) : Color(red: 70/255, green: 80/255, blue: 95/255))
                                        }
                                        .frame(width: 76)
                                    }
                                    .buttonStyle(BuxmationPressCardStyle())
                                    .offset(y: navigationCoordinator.isScreenLoaded ? 0 : 8)
                                    .opacity(navigationCoordinator.isScreenLoaded ? 1.0 : 0.0)
                                    .animation(.spring(response: 0.4, dampingFraction: 0.75).delay(0.18), value: navigationCoordinator.isScreenLoaded)
                                }
                                .padding(.top, 4)
                                .offset(y: collapseValue(start: 0, end: -15))
                            }
                            .padding(BuxLayout.loose)
                        }
                        .padding(.top, BuxLayout.section)
                        // Expanded vertical base height to 315 to completely prevent bottom detail and button clipping!
                        .frame(height: max(100, 315 + scrollOffset))
                        .clipShape(RoundedRectangle(cornerRadius: BuxLayout.cornerHero))
                        .shadow(
                            color: themeManager.heroCardShadow(for: colorScheme).color,
                            radius: themeManager.heroCardShadow(for: colorScheme).radius,
                            x: 0,
                            y: themeManager.heroCardShadow(for: colorScheme).y
                        )

                        if true {
                            VStack(alignment: .leading, spacing: 12) {
                                if let budgetName = dashSnapshot.activeBudgetName {
                                    let limit = dashSnapshot.activeBudgetLimit
                                    let spent = dashSnapshot.activeBudgetSpent
                                    let remaining = limit - spent
                                    let progress = limit > 0 ? min(1.0, max(0.0, Double(NSDecimalNumber(decimal: spent).doubleValue / NSDecimalNumber(decimal: limit).doubleValue))) : 0.0
                                    
                                    Button(action: {
                                        withAnimation {
                                            navigationCoordinator.selectedTab = .settings
                                        }
                                    }) {
                                        VStack(alignment: .leading, spacing: 12) {
                                            HStack {
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text("ACTIVE BUDGET: \(budgetName.uppercased())")
                                                        .font(.system(size: 11, weight: .bold))
                                                        .foregroundColor(themeManager.current.accentColor)
                                                        .kerning(1.1)
                                                    
                                                    Text("\(appSettingsManager.format(remaining)) left of \(appSettingsManager.format(limit))")
                                                        .font(.system(size: 16, weight: .bold))
                                                        .foregroundColor(colorScheme == .dark ? .white : .black)
                                                }
                                                
                                                Spacer()
                                                
                                                Text("\(Int(progress * 100))% spent")
                                                    .font(.system(size: 12, weight: .bold))
                                                    .foregroundColor(progress > 0.9 ? .red : .gray)
                                            }
                                            
                                            // Progress Bar
                                            GeometryReader { geometry in
                                                ZStack(alignment: .leading) {
                                                    RoundedRectangle(cornerRadius: 4)
                                                        .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05))
                                                        .frame(height: 8)
                                                    
                                                    RoundedRectangle(cornerRadius: 4)
                                                        .fill(LinearGradient(
                                                            colors: progress > 0.9 ? [.red, .orange] : [themeManager.current.accentColor, themeManager.current.accentColor.opacity(0.7)],
                                                            startPoint: .leading,
                                                            endPoint: .trailing
                                                        ))
                                                        .frame(width: geometry.size.width * CGFloat(progress), height: 8)
                                                }
                                            }
                                            .frame(height: 8)
                                        }
                                        .padding(16)
                                        .background(colorScheme == .dark ? Color(red: 24/255, green: 26/255, blue: 32/255) : .white)
                                        .clipShape(RoundedRectangle(cornerRadius: 24))
                                        .buxCardOutline(themeManager: themeManager, colorScheme: colorScheme, cornerRadius: 24)
                                    }
                                    .buttonStyle(BuxMicroShrinkStyle())
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
                                                Text("No Active Budget Profile")
                                                    .font(.system(size: 13, weight: .bold))
                                                    .foregroundColor(colorScheme == .dark ? .white : .black)
                                                Spacer()
                                                Image(systemName: "chevron.right")
                                                    .font(.system(size: 12, weight: .bold))
                                                    .foregroundColor(.gray)
                                            }
                                            
                                            Text("You have enabled \(settingsStore.budgetingMode.rawValue) budgeting mode, but do not have an active budget profile yet. Tap here to configure a profile in App Settings.")
                                                .font(.system(size: 11, weight: .medium))
                                                .foregroundColor(.gray)
                                                .multilineTextAlignment(.leading)
                                        }
                                        .padding(16)
                                        .background(colorScheme == .dark ? Color(red: 24/255, green: 26/255, blue: 32/255) : .white)
                                        .clipShape(RoundedRectangle(cornerRadius: 24))
                                        .buxCardOutline(themeManager: themeManager, colorScheme: colorScheme, cornerRadius: 24)
                                    }
                                    .buttonStyle(BuxMicroShrinkStyle())
                                }
                            }
                            .padding(.horizontal, BuxLayout.marginHorizontal)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        if settingsStore.freelanceEnabled {
                            FreelanceDashboardWidget()
                                .environmentObject(themeManager)
                                .environmentObject(navigationCoordinator)
                                .environmentObject(freelanceBrain)
                                .padding(.top, 4)
                        }

                        CategoryPillBar(
                            activeCategory: $navigationCoordinator.activeCategoryPill,
                            isExpanded: $isPillSectionExpanded
                        )
                        .environmentObject(themeManager)

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

                                HStack(alignment: .top, spacing: BuxLayout.section) {
                                    Button(action: {
                                        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                                            navigationCoordinator.openExpensesTab()
                                        }
                                    }) {
                                        SubscriptionSummaryCardView(
                                            title: "This Month",
                                            cost: appSettingsManager.format(monthlyTotal),
                                            subtext: expenseHeader.biggestCategory.map { "Top: \($0)" } ?? "All categories",
                                            trendText: changeTrend,
                                            trendColor: changeColor,
                                            icon: "creditcard.fill",
                                            iconColor: themeManager.current.accentColor
                                        )
                                    }
                                    .buttonStyle(BuxmationPressCardStyle())
                                    .frame(maxWidth: .infinity, minHeight: BuxLayout.dashboardSmallCardHeight, alignment: .top)
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
                                            title: "Transactions",
                                            cost: "\(txnCount) This Month",
                                            subtext: expenseHeader.biggestMerchant.map { "Top: \($0)" } ?? "All merchants",
                                            trendText: expenseHeader.microInsight ?? "On track",
                                            trendColor: themeManager.current.accentColor,
                                            icon: "list.bullet.rectangle.fill",
                                            iconColor: themeManager.current.accentColor
                                        )
                                    }
                                    .buttonStyle(BuxmationPressCardStyle())
                                    .frame(maxWidth: .infinity, minHeight: BuxLayout.dashboardSmallCardHeight, alignment: .top)
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
                                HStack(alignment: .top, spacing: BuxLayout.section) {
                                    if activeSubs.isEmpty {
                                        HStack {
                                            Image(systemName: "sparkles")
                                                .foregroundColor(themeManager.current.accentColor)
                                            Text("No active subscriptions. Tapping quick action opens Subscription Hub.")
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundColor(.gray)
                                                .multilineTextAlignment(.center)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 32)
                                        .background(colorScheme == .dark ? Color(red: 24/255, green: 26/255, blue: 32/255) : .white)
                                        .clipShape(RoundedRectangle(cornerRadius: 24))
                                        .buxCardOutline(themeManager: themeManager, colorScheme: colorScheme, cornerRadius: 24)
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
                                                    billingDate: sub.billingCycle.displayName,
                                                    accentColor: index == 0 ? themeManager.current.accentColor : Color.purple
                                                )
                                            }
                                            .buttonStyle(BuxMicroShrinkStyle())
                                            .frame(maxWidth: .infinity, minHeight: BuxLayout.dashboardSmallCardHeight, alignment: .top)
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
                                        Text("ACTIVE SAVINGS GOALS")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(colorScheme == .dark ? .white.opacity(0.4) : Color(red: 140/255, green: 145/255, blue: 160/255))
                                            .kerning(1.2)
                                        
                                        Spacer()
                                        
                                        Button(action: {
                                            goalsSheetCoordinator.presentAddGoal()
                                        }) {
                                            HStack(spacing: 4) {
                                                Image(systemName: "plus.circle.fill")
                                                    .font(.system(size: 14, weight: .bold))
                                                Text("Add Goal")
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
                                                    .foregroundColor(.gray)
                                                Text("No active savings goals yet.")
                                                    .font(.system(size: 13, weight: .medium))
                                                    .foregroundColor(.gray)
                                            }
                                            Spacer()
                                        }
                                        .padding(.vertical, 32)
                                        .background(colorScheme == .dark ? Color(red: 24/255, green: 26/255, blue: 32/255) : .white)
                                        .clipShape(RoundedRectangle(cornerRadius: 24))
                                        .buxCardOutline(themeManager: themeManager, colorScheme: colorScheme, cornerRadius: 24)
                                        .buxDashboardCategoryCard(
                                            index: 0,
                                            direction: categorySlideDirection,
                                            motionToken: categoryMotionToken
                                        )
                                    } else {
                                        ScrollView(.horizontal, showsIndicators: false) {
                                            HStack(spacing: BuxLayout.section) {
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
                                                            accentColor: accentColor
                                                        )
                                                    }
                                                    .buttonStyle(BuxMicroShrinkStyle())
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
                                                    Text("See your progress")
                                                        .font(.system(size: 13, weight: .bold))
                                                        .foregroundColor(colorScheme == .dark ? .white : Color(red: 26/255, green: 28/255, blue: 32/255))
                                                    Text("Get structural forecast and potential acceleration timeline AI insights.")
                                                        .font(.system(size: 11, weight: .medium))
                                                        .foregroundColor(.gray)
                                                }
                                                .multilineTextAlignment(.leading)
                                                
                                                Spacer()
                                                
                                                Image(systemName: "chevron.right")
                                                    .font(.system(size: 12, weight: .bold))
                                                    .foregroundColor(.gray)
                                            }
                                            .padding(16)
                                            .background(colorScheme == .dark ? Color(red: 24/255, green: 26/255, blue: 32/255) : .white)
                                            .clipShape(RoundedRectangle(cornerRadius: 16))
                                            .buxCardOutline(themeManager: themeManager, colorScheme: colorScheme, cornerRadius: 16)
                                        }
                                        .buttonStyle(BuxMicroShrinkStyle())
                                        .buxDashboardCategoryCard(
                                            index: 1,
                                            direction: categorySlideDirection,
                                            motionToken: categoryMotionToken
                                        )
                                    }
                                }
                                .transition(.buxCategorySlide(direction: categorySlideDirection))
                            } else {
                                let displayInsights = insightsViewModel.rankedInsights
                                HStack(alignment: .top, spacing: BuxLayout.section) {
                                    if displayInsights.isEmpty {
                                        InsightCardView(
                                            title: "Monthly Savings",
                                            value: "+24.5%",
                                            description: "Higher than last month",
                                            accentColor: Color(red: 243/255, green: 156/255, blue: 18/255)
                                        )
                                        .frame(maxWidth: .infinity, minHeight: BuxLayout.dashboardSmallCardHeight, alignment: .top)
                                        .buxDashboardCategoryCard(
                                            index: 0,
                                            direction: categorySlideDirection,
                                            motionToken: categoryMotionToken
                                        )
                                        .offset(y: navigationCoordinator.isScreenLoaded ? 0 : 50)
                                        .opacity(navigationCoordinator.isScreenLoaded ? 1.0 : 0.0)
                                        .animation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.05), value: navigationCoordinator.isScreenLoaded)
                                        
                                        InsightCardView(
                                            title: "Spend Velocity",
                                            value: "Low Risk",
                                            description: "Within optimal limits",
                                            accentColor: Color(red: 155/255, green: 89/255, blue: 182/255)
                                        )
                                        .frame(maxWidth: .infinity, minHeight: BuxLayout.dashboardSmallCardHeight, alignment: .top)
                                        .buxDashboardCategoryCard(
                                            index: 1,
                                            direction: categorySlideDirection,
                                            motionToken: categoryMotionToken
                                        )
                                        .offset(y: navigationCoordinator.isScreenLoaded ? 0 : 50)
                                        .opacity(navigationCoordinator.isScreenLoaded ? 1.0 : 0.0)
                                        .animation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.12), value: navigationCoordinator.isScreenLoaded)
                                    } else {
                                        ForEach(Array(displayInsights.prefix(2).enumerated()), id: \.element.id) { index, insight in
                                            let accentColor: Color = {
                                                switch insight.accentColorName {
                                                case "red": return .red
                                                case "green": return .green
                                                case "orange": return .orange
                                                case "blue": return .blue
                                                case "purple": return .purple
                                                default: return themeManager.current.accentColor
                                                }
                                            }()
                                            
                                            Button(action: {
                                                insightsViewModel.selectInsight(insight)
                                            }) {
                                                InsightCardView(
                                                    title: insight.title,
                                                    value: insight.value,
                                                    description: insight.description,
                                                    accentColor: accentColor
                                                )
                                            }
                                            .buttonStyle(BuxMicroShrinkStyle())
                                            .frame(maxWidth: .infinity, minHeight: BuxLayout.dashboardSmallCardHeight, alignment: .top)
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
                                }
                                .transition(.buxCategorySlide(direction: categorySlideDirection))
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .clipped()
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
                    // Buxmation Focus overlays: blurs and dims elements above stack on expansion
                    .blur(radius: goalsSheetCoordinator.showGoalDetail ? 5 : 0)
                    .opacity(goalsSheetCoordinator.showGoalDetail ? 0.45 : 1.0)
                    .scaleEffect(goalsSheetCoordinator.showGoalDetail ? 0.95 : 1.0)
                    .animation(.spring(response: 0.45, dampingFraction: 0.75), value: goalsSheetCoordinator.showGoalDetail)
                    
                    RecentTransactionsSectionView(
                        transactions: dashSnapshot.recentTransactions,
                        onSeeMore: { navigationCoordinator.openExpensesTab() }
                    )
                    .offset(y: navigationCoordinator.isScreenLoaded ? 0 : 30)
                    .opacity(navigationCoordinator.isScreenLoaded ? 1.0 : 0.0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.24), value: navigationCoordinator.isScreenLoaded)
                    .padding(.bottom, 120)
                }
                .padding(.horizontal, BuxLayout.marginHorizontal)
            }
            .scrollClipDisabled()
            .buxReportsContainerWidth()
            .coordinateSpace(name: "dashboard_scroll")
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                if value < 0 {
                    scrollOffset = max(-150, value)
                } else {
                    scrollOffset = 0
                }
            }
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
                        FabSubmenuItem(title: "Scan Receipt", icon: "camera.fill", delay: 0.04)
                        FabSubmenuItem(title: "Manual Entry", icon: "square.and.pencil", delay: 0.08)
                        FabSubmenuItem(title: "Select Category", icon: "tag.fill", delay: 0.12)
                    }
                    .padding(.bottom, 120)
                }
                .padding(.horizontal, BuxLayout.marginHorizontal)
                .zIndex(6)
            }
        }
    }
    
    private func collapseValue(start: CGFloat, end: CGFloat) -> CGFloat {
        let range = start - end
        let factor = min(1.0, max(0.0, -scrollOffset / 100.0))
        return start - (range * factor)
    }

    private func categoryIndex(for name: String) -> Int {
        switch name {
        case "Expenses": return 0
        case "Subscriptions": return 1
        case "Goals": return 2
        default: return 3
        }
    }
}


// MARK: - Mitchell Santos Avatar Drawing Component
struct MitchellSantosAvatarView: View {
    var size: CGFloat = 44
    
    var body: some View {
        if let data = SettingsStore.shared.profileAvatarData, let img = UIImage(data: data) {
            Image(uiImage: img)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.8), lineWidth: 1.5)
                )
        } else {
            ZStack {
                // Circle background
                Circle()
                    .fill(LinearGradient(
                        colors: [Color(red: 224/255, green: 231/255, blue: 255/255), Color(red: 199/255, green: 210/255, blue: 254/255)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: size, height: size)
                
                // Face skin
                Circle()
                    .fill(Color(red: 245/255, green: 210/255, blue: 185/255))
                    .frame(width: size * 0.727, height: size * 0.727)
                    .offset(y: size * 0.022)
                
                // Hair (Purple)
                Group {
                    Path { path in
                        path.addArc(center: CGPoint(x: size * 0.5, y: size * 0.5), radius: size * 0.437, startAngle: .degrees(160), endAngle: .degrees(380), clockwise: false)
                    }
                    .fill(Color(red: 104/255, green: 58/255, blue: 180/255))
                    .frame(width: size * 0.727, height: size * 0.727)
                    .offset(y: -size * 0.09)
                    
                    Circle()
                        .fill(Color(red: 104/255, green: 58/255, blue: 180/255))
                        .frame(width: size * 0.318, height: size * 0.318)
                        .offset(x: -size * 0.18, y: -size * 0.22)
                }
                
                // Glasses (Black round rims)
                HStack(spacing: size * 0.045) {
                    Circle()
                        .stroke(Color.black, lineWidth: size * 0.045)
                        .frame(width: size * 0.204, height: size * 0.204)
                    
                    Rectangle()
                        .fill(Color.black)
                        .frame(width: size * 0.068, height: size * 0.045)
                        .offset(y: -size * 0.022)
                    
                    Circle()
                        .stroke(Color.black, lineWidth: size * 0.045)
                        .frame(width: size * 0.204, height: size * 0.204)
                }
                .offset(y: -size * 0.022)
                
                // Eyes inside glasses
                HStack(spacing: size * 0.18) {
                    Circle()
                        .fill(Color.black)
                        .frame(width: size * 0.056, height: size * 0.056)
                    
                    Circle()
                        .fill(Color.black)
                        .frame(width: size * 0.056, height: size * 0.056)
                }
                .offset(y: -size * 0.022)
                
                // Smile/Mouth
                Path { path in
                    path.addArc(center: CGPoint(x: size * 0.25, y: size * 0.125), radius: size * 0.187, startAngle: .degrees(10), endAngle: .degrees(170), clockwise: false)
                }
                .stroke(Color.black, lineWidth: size * 0.034)
                .frame(width: size * 0.5, height: size * 0.25)
                .offset(y: size * 0.136)
            }
            .frame(width: size, height: size)
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.8), lineWidth: 1.5)
            )
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
    
    @State private var animateIn = false
    
    var body: some View {
        HStack(spacing: 12) {
            Spacer()
            
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(colorScheme == .dark ? .white : .black)
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
        .offset(y: animateIn ? 0 : 30)
        .opacity(animateIn ? 1.0 : 0.0)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75).delay(delay)) {
                animateIn = true
            }
        }
    }
}
