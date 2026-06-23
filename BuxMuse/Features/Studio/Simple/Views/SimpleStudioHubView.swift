//
//  SimpleStudioHubView.swift
//  BuxMuse
//
//  Simple Studio — compressed hub for informal workers.
//

import SwiftUI

struct SimpleStudioHubView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @EnvironmentObject private var studioStore: StudioStore
    @EnvironmentObject private var studioBrain: StudioBrain
    @EnvironmentObject private var brain: BuxMuseBrain
    @EnvironmentObject private var appDataManager: AppDataManager
    @EnvironmentObject private var simpleStudioBrain: SimpleStudioBrain
    @EnvironmentObject private var simpleStudioStore: SimpleStudioStore
    @EnvironmentObject private var taxEnvelopeBrain: TaxEnvelopeBrain
    @EnvironmentObject private var navigationCoordinator: NavigationCoordinator
    @EnvironmentObject private var tutorialCoordinator: AppTutorialCoordinator
    @Environment(\.buxPadStudioUsesSplitLayout) private var usesPadSplitLayout
    @ObservedObject private var settingsStore = SettingsStore.shared
    @ObservedObject private var studioTimer = StudioTimerController.shared

    @State private var hubAppeared = false
    @State private var showLogTime = false
    @State private var isFabExpanded = false
    @State private var showLogMoney = false
    @State private var logMoneyKind: SimpleEntryKind?
    @State private var showScan = false
    @State private var showInvoice = false
    @State private var invoicePrefill: SimpleInvoiceSuggestion?
    @State private var showBusinessCard = false
    @State private var showQuoteJob = false
    @State private var editingJob: SimpleStudioEntry?
    @State private var showPeople = false
    @State private var pendingMarkPaidId: UUID?
    @State private var showMarkPaidConfirmation = false
    @State private var detailDestination: SimpleStudioDetailDestination?
    @State private var navigateMyMoney = false
    @State private var showSearch = false
    @State private var navigateToInvoiceArchive = false
    @State private var navigateToMileage = false
    @State private var proUpsellFeature: StudioProUpsellSheet.Feature?
    @State private var navigateTaxEnvelope = false

    private var display: SimpleStudioHubDisplay { simpleStudioBrain.hubDisplay }

    private var simpleInsights: SimpleStudioInsightsSnapshot {
        SimpleStudioInsightsEngine.build(
            entries: simpleStudioStore.entries,
            currencyFormat: { appSettingsManager.format($0) },
            locale: appSettingsManager.interfaceLocale
        )
    }

    private var locale: Locale { appSettingsManager.interfaceLocale }

    var body: some View {
        Group {
            if usesPadSplitLayout {
                simpleHubLayer
            } else {
                NavigationStack {
                    simpleHubLayer
                }
            }
        }
        .buxInterfaceLocale()
    }

    private var simpleHubLayer: some View {
        ZStack(alignment: .bottomTrailing) {
                BuxLandingTintBackground()
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: BuxTokens.block) {
                        if showsHeroWordmarkInScroll {
                            SimpleStudioHeader()
                                .buxScreenEntrance(index: 0, isVisible: hubAppeared)
                                .tutorialAnchor(.studioHubHeader, coordinator: tutorialCoordinator)
                        }

                        simpleQuickActions
                            .buxScreenEntrance(index: 1, isVisible: hubAppeared)

                        if StandardBudgetStudioBridgePrompt.shouldShow(settings: settingsStore) {
                            StandardBudgetStudioBridgePromptCard(
                                pendingAmount: StandardBudgetStudioBridgePrompt.pendingIncomeThisPeriod(
                                    period: {
                                        var calendar = Calendar.current
                                        calendar.firstWeekday = settingsStore.weekStartDay.calendarWeekday
                                        return BuxBudgetPeriodCalculator.currentPeriod(
                                            configuration: .fromSettings,
                                            calendar: calendar
                                        )
                                    }(),
                                    entries: simpleStudioStore.entries,
                                    invoices: studioStore.invoices,
                                    incomeRecords: (try? brain.fetchAllExpenseRecords()) ?? [],
                                    fundingSource: settingsStore.incomeFundingSource,
                                    studioMode: settingsStore.studioMode
                                )
                            ) {
                                // AppContainer wiring refreshes Home budget after toggle save.
                            }
                            .environmentObject(themeManager)
                            .environmentObject(appSettingsManager)
                            .buxScreenEntrance(index: 1, isVisible: hubAppeared)
                        }

                        NavigationLink {
                            SimpleStudioMyMoneyView(
                                store: simpleStudioStore,
                                display: simpleStudioBrain.myMoneyDisplay
                            )
                            .environmentObject(themeManager)
                            .environmentObject(appSettingsManager)
                            .environmentObject(studioStore)
                        } label: {
                            SimpleStudioThisMonthCard(display: display)
                        }
                        .buttonStyle(.plain)
                        .buxScreenEntrance(index: 2, isVisible: hubAppeared)

                        SimpleStudioHeroCard(display: display)
                            .buxScreenEntrance(index: 3, isVisible: hubAppeared)

                        SimpleStudioInsightsHubSection(snapshot: simpleInsights)
                            .buxScreenEntrance(index: 3, isVisible: hubAppeared)

                        SimpleStudioInvoiceSuggestionsSection(
                            suggestions: StudioInvoiceSuggestionEngine.simpleSuggestions(
                                store: simpleStudioStore,
                                studioStore: studioStore
                            )
                        ) { suggestion in
                            invoicePrefill = suggestion
                        }
                        .buxScreenEntrance(index: 3, isVisible: hubAppeared)

                        simpleLogTimeQuickAction
                            .buxScreenEntrance(index: 3, isVisible: hubAppeared)

                        if display.isEmpty {
                            SimpleStudioEmptyState()
                                .buxScreenEntrance(index: 3, isVisible: hubAppeared)
                        }

                        SimpleStudioMetricTiles(display: display)
                            .buxScreenEntrance(index: 4, isVisible: hubAppeared)

                        SimpleStudioWaitingSection(
                            items: display.waitingItems,
                            onMarkPaid: { id in
                                pendingMarkPaidId = id
                                showMarkPaidConfirmation = true
                            },
                            onRemind: { item in
                                shareReminder(for: item)
                            },
                            onTap: { id in
                                openEntry(for: id)
                            }
                        )
                        .buxScreenEntrance(index: 5, isVisible: hubAppeared)

                        if !display.iOweItems.isEmpty {
                            SimpleStudioIOweSection(
                                items: display.iOweItems,
                                onMarkSettled: { id in
                                    pendingMarkPaidId = id
                                    showMarkPaidConfirmation = true
                                },
                                onTap: { id in
                                    openEntry(for: id)
                                }
                            )
                            .buxScreenEntrance(index: 6, isVisible: hubAppeared)
                        }

                        SimpleStudioRecentSection(items: display.recentItems) { id in
                            openEntry(for: id)
                        }
                            .buxScreenEntrance(index: 7, isVisible: hubAppeared)

                        if settingsStore.studioEnabled {
                            TaxSavingsHubHeroSection {
                                navigateTaxEnvelope = true
                            }
                            .buxScreenEntrance(index: 8, isVisible: hubAppeared)
                        }

                        SimpleStudioTaxSection(tile: display.taxTile) {
                            proUpsellFeature = .fullTax
                        }
                            .buxScreenEntrance(index: 9, isVisible: hubAppeared)

                        simpleToolsSection
                            .buxScreenEntrance(index: 10, isVisible: hubAppeared)

                        Spacer().frame(height: 100)
                    }
                    .padding(.top, BuxTokens.tight)
                    .buxPadDashboardCardRail()
                    .environment(\.studioEnhancedTint, true)
                }
                .modifier(SimpleStudioHubScrollChromeModifier(usesPadSplitLayout: usesPadSplitLayout))

                fabLayer
            }
            .buxStudioHubPadNavigationChrome(usesPadSplitLayout: usesPadSplitLayout, brand: .simple) {
                simpleHubTrailingToolbar
            }
            .buxInterfaceLocale()
            .navigationDestination(isPresented: $showSearch) {
                SimpleStudioSearchView(store: simpleStudioStore, isProSearch: false)
                    .environmentObject(themeManager)
                    .environmentObject(appSettingsManager)
                    .environmentObject(studioStore)
            }
            .navigationDestination(isPresented: $navigateToInvoiceArchive) {
                StudioInvoiceArchiveView()
                    .environmentObject(themeManager)
                    .environmentObject(appSettingsManager)
                    .environmentObject(studioStore)
                    .environmentObject(simpleStudioStore)
            }
            .navigationDestination(isPresented: $navigateToMileage) {
                StudioMileageLogView()
                    .environmentObject(themeManager)
                    .environmentObject(appSettingsManager)
                    .environmentObject(studioStore)
                    .environmentObject(studioBrain)
                    .environment(\.studioEnhancedTint, true)
            }
            .navigationDestination(isPresented: $navigateTaxEnvelope) {
                TaxEnvelopeRootView()
                    .environmentObject(themeManager)
                    .environmentObject(appSettingsManager)
                    .environmentObject(studioStore)
                    .environmentObject(studioBrain)
                    .environmentObject(taxEnvelopeBrain)
                    .environmentObject(appDataManager)
            }
            .sheet(item: $proUpsellFeature) { feature in
                StudioProUpsellSheet(feature: feature)
                    .environmentObject(themeManager)
                    .environmentObject(appSettingsManager)
                    .environmentObject(studioStore)
                    .environmentObject(simpleStudioStore)
            }
            .onAppear {
                studioTimer.attach(simpleStore: simpleStudioStore)
                simpleStudioBrain.refreshAll()
                presentLogTimeIfRequested()
                guard !hubAppeared else { return }
                withAnimation(BuxMotion.bounce) { hubAppeared = true }
            }
            .onChange(of: navigationCoordinator.openStudioLogTimeRequest) { _, _ in
                presentLogTimeIfRequested()
            }
            .sheet(isPresented: $showLogTime) {
                SimpleStudioLogTimeView()
                    .environmentObject(themeManager)
                    .environmentObject(appSettingsManager)
                    .environmentObject(simpleStudioStore)
                    .environmentObject(studioStore)
                    .buxStudioSheetContent()
                    .buxPadSimpleStudioQuickSheet()
            }
            .alert(markPaidAlertTitle, isPresented: $showMarkPaidConfirmation) {
                Button(markPaidConfirmLabel) {
                    guard let id = pendingMarkPaidId else { return }
                    simpleStudioStore.markEntryPaid(id: id)
                    if simpleStudioStore.invoices.contains(where: { $0.id == id }) {
                        simpleStudioStore.markInvoicePaid(id: id)
                    }
                    pendingMarkPaidId = nil
                }
                Button(BuxCatalogLabel.string("Cancel", locale: locale), role: .cancel) {
                    pendingMarkPaidId = nil
                }
            } message: {
                Text(markPaidAlertMessage)
            }
            .sheet(item: $detailDestination) { destination in
                switch destination {
                case .entry(let id):
                    SimpleStudioEntryDetailView(store: simpleStudioStore, entryId: id)
                        .environmentObject(themeManager)
                        .environmentObject(appSettingsManager)
                        .environmentObject(studioStore)
                case .invoice(let id):
                    SimpleStudioInvoiceDetailView(store: simpleStudioStore, invoiceId: id)
                        .environmentObject(themeManager)
                        .environmentObject(appSettingsManager)
                        .environmentObject(studioStore)
                case .person(let id):
                    NavigationStack {
                        SimpleStudioPersonDetailView(store: simpleStudioStore, customerId: id)
                            .environmentObject(themeManager)
                            .environmentObject(appSettingsManager)
                            .environmentObject(studioStore)
                    }
                    .buxStudioSheetContent()
                }
            }
            .sheet(isPresented: $showLogMoney) {
                SimpleStudioLogMoneySheet(store: simpleStudioStore, initialKind: logMoneyKind)
                    .environmentObject(themeManager)
                    .environmentObject(appSettingsManager)
                    .buxPadSimpleStudioQuickSheet()
            }
            .sheet(isPresented: $showScan) {
                SimpleStudioScanView(store: simpleStudioStore)
                    .environmentObject(themeManager)
                    .environmentObject(appSettingsManager)
                    .buxPadSimpleStudioQuickSheet()
            }
            .sheet(isPresented: $showInvoice) {
                SimpleStudioSimpleInvoiceSheet(store: simpleStudioStore)
                    .environmentObject(themeManager)
                    .environmentObject(appSettingsManager)
                    .environmentObject(studioStore)
                    .buxPadSimpleStudioQuickSheet()
            }
            .sheet(item: $invoicePrefill) { prefill in
                SimpleStudioSimpleInvoiceSheet(store: simpleStudioStore, prefill: prefill)
                    .environmentObject(themeManager)
                    .environmentObject(appSettingsManager)
                    .environmentObject(studioStore)
                    .buxPadSimpleStudioQuickSheet()
            }
            .sheet(isPresented: $showBusinessCard) {
                SimpleStudioBusinessCardSheet(store: simpleStudioStore)
                    .environmentObject(themeManager)
                    .environmentObject(appSettingsManager)
                    .environmentObject(studioStore)
                    .buxPadSimpleStudioQuickSheet()
            }
            .sheet(isPresented: $showQuoteJob) {
                SimpleStudioJobQuoteSheet(store: simpleStudioStore, existingJob: editingJob)
                    .environmentObject(themeManager)
                    .environmentObject(appSettingsManager)
                    .environmentObject(studioStore)
                    .onDisappear { editingJob = nil }
                    .buxPadSimpleStudioQuickSheet()
            }
            .navigationDestination(isPresented: $showPeople) {
                SimpleStudioPeopleView(store: simpleStudioStore)
                    .environmentObject(themeManager)
                    .environmentObject(appSettingsManager)
            }
    }

    private var showsHeroWordmarkInScroll: Bool {
        if usesPadSplitLayout { return false }
        if #available(iOS 26, *) { return false }
        return true
    }

    private var simpleHubTrailingToolbar: some View {
        HStack(spacing: 16) {
            Button {
                showSearch = true
            } label: {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
            }
            .accessibilityLabel(BuxCatalogLabel.string("Search", locale: locale))

            Menu {
                Button(BuxCatalogLabel.string("People", locale: locale)) { showPeople = true }
                Button(BuxCatalogLabel.string("Upgrade to Pro", locale: locale)) {
                    proUpsellFeature = .fullTax
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
            }
        }
    }

    @ViewBuilder
    private var fabLayer: some View {
        // Backdrop — always in the hierarchy, opacity-driven for smooth fade
        Color.black.opacity(isFabExpanded ? 0.35 : 0)
            .ignoresSafeArea()
            .allowsHitTesting(isFabExpanded)
            .onTapGesture { closeFabAnimated() }
            .animation(.easeInOut(duration: 0.22), value: isFabExpanded)
            .zIndex(4)

        // Menu items — always in hierarchy, animated with scale + opacity + slide
        VStack(spacing: 10) {
            fabItem(titleKey: "Work clock", icon: "stopwatch.fill", index: 0) {
                closeFab { showLogTime = true }
            }
            fabItem(titleKey: "Scan", icon: "camera.viewfinder", index: 1) {
                closeFab { showScan = true }
            }
            fabItem(titleKey: "Quote job", icon: "doc.text.magnifyingglass", index: 2) {
                closeFab {
                    editingJob = nil
                    showQuoteJob = true
                }
            }
            fabItem(titleKey: "Log money", icon: "banknote.fill", index: 3) {
                closeFab {
                    logMoneyKind = nil
                    showLogMoney = true
                }
            }
            fabItem(titleKey: "Invoice", icon: "doc.text.fill", index: 4) {
                closeFab { showInvoice = true }
            }
            fabItem(titleKey: "Business card", icon: "person.crop.rectangle.fill", index: 5) {
                closeFab { showBusinessCard = true }
            }
            fabItem(titleKey: "They owe me", icon: "person.fill.questionmark", index: 6) {
                closeFab {
                    logMoneyKind = .owedToMe
                    showLogMoney = true
                }
            }
            fabItem(titleKey: "I owe", icon: "person.fill.xmark", index: 7) {
                closeFab {
                    logMoneyKind = .iOwe
                    showLogMoney = true
                }
            }
        }
        .padding(.horizontal, BuxTokens.marginRegular)
        .padding(.bottom, 88)
        .allowsHitTesting(isFabExpanded)
        .zIndex(5)

        // FAB button
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) {
                isFabExpanded.toggle()
            }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(themeManager.current.accentColor)
                .clipShape(Circle())
                .shadow(color: themeManager.current.accentColor.opacity(0.35), radius: 8, y: 4)
                .rotationEffect(.degrees(isFabExpanded ? 45 : 0))
                .animation(.spring(response: 0.38, dampingFraction: 0.72), value: isFabExpanded)
        }
        .padding(.trailing, BuxTokens.marginRegular)
        .padding(.bottom, BuxTokens.section)
        .zIndex(6)
        .accessibilityLabel(
            BuxCatalogLabel.string(isFabExpanded ? "Close menu" : "Add", locale: locale)
        )
        .tutorialAnchor(.studioMoneyEntry, coordinator: tutorialCoordinator)
    }

    private func fabItem(titleKey: String, icon: String, index: Int, action: @escaping () -> Void) -> some View {
        let totalItems = 8
        // Open: items slide in bottom-to-top (highest index = lowest item = first to appear)
        // Close: all collapse together quickly
        let openDelay  = Double(totalItems - 1 - index) * 0.030   // 0…0.21s stagger on open
        let closeDelay = Double(index) * 0.012                     // 0…0.084s stagger on close (much faster)
        let delay = isFabExpanded ? openDelay : closeDelay
        let spring: Animation = isFabExpanded
            ? .spring(response: 0.44, dampingFraction: 0.78).delay(delay)
            : .spring(response: 0.28, dampingFraction: 0.90).delay(delay)

        return Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 36, height: 36)
                    .background(themeManager.accentWash(for: colorScheme))
                    .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                    .clipShape(Circle())
                BuxCatalogText.text(titleKey)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                Spacer()
            }
            .padding(.horizontal, BuxTokens.section)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: BuxTokens.Radius.card, style: .continuous))
        }
        .buttonStyle(.plain)
        .opacity(isFabExpanded ? 1 : 0)
        .scaleEffect(isFabExpanded ? 1 : 0.82, anchor: .bottomTrailing)
        .offset(y: isFabExpanded ? 0 : 18)
        .animation(spring, value: isFabExpanded)
    }

    private var simpleLogTimeQuickAction: some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { _ in
            Button {
                showLogTime = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: studioTimer.isRunning ? "stopwatch.fill" : "stopwatch")
                        .font(.system(size: 18, weight: .semibold))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(studioTimer.hasActiveSession && studioTimer.session?.isSimpleJobSession == true
                             ? StudioTimerSession.formattedElapsed(studioTimer.displayElapsed, style: .hub)
                             : BuxCatalogLabel.string("Work clock", locale: locale))
                            .font(.system(size: 15, weight: .bold))
                        BuxCatalogDynamicText(key: "Track time — hourly or one-price jobs")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(themeManager.labelSecondary(for: colorScheme))
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(themeManager.labelSecondary(for: colorScheme))
                }
                .foregroundStyle(themeManager.labelPrimary(for: colorScheme))
                .padding(BuxLayout.section)
                .background(themeManager.cardFill(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: BuxTokens.Radius.card, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    private var simpleQuickActions: some View {
        HStack(spacing: BuxTokens.tight) {
            BuxQuickActionButton(
                title: "Invoice",
                systemImage: "doc.text.fill",
                role: .primary
            ) { showInvoice = true }

            BuxQuickActionButton(
                title: "Scan",
                systemImage: "camera.viewfinder",
                role: .primary
            ) { showScan = true }

            BuxQuickActionButton(
                title: "Quote job",
                systemImage: "doc.text.magnifyingglass",
                role: .primary
            ) {
                editingJob = nil
                showQuoteJob = true
            }

            BuxQuickActionButton(
                title: "Log money",
                systemImage: "banknote.fill",
                role: .primary
            ) {
                logMoneyKind = nil
                showLogMoney = true
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .buxNativeGlassButtonRowContainer(spacing: BuxTokens.tight)
        .tint(themeManager.contrastAccentColor(for: colorScheme))
    }

    private func presentLogTimeIfRequested() {
        guard navigationCoordinator.consumeStudioLogTimeRequest() else { return }
        showLogTime = true
    }

    private func closeFabAnimated() {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.90)) {
            isFabExpanded = false
        }
    }

    private func closeFab(_ action: @escaping () -> Void) {
        // Use the fast close spring — same as closeFabAnimated
        // Items stagger close in ~0.084s (7 × 12ms) + spring settles in ~0.28s ≈ 0.36s total.
        // Fire the sheet at 0.30s: items are visually gone, spring is nearly settled,
        // giving the sheet a clean stage with no animation fighting.
        withAnimation(.spring(response: 0.28, dampingFraction: 0.90)) {
            isFabExpanded = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) {
            action()
        }
    }

    private var simpleToolsSection: some View {
        VStack(alignment: .leading, spacing: BuxTokens.tight) {
            BuxSectionHeader(title: "Tools")

            BuxCard(elevation: .card, cornerRadius: BuxTokens.Radius.card, padding: 0) {
                BuxCardButton(action: { navigateToMileage = true }) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: BuxTokens.tight, style: .continuous)
                                .fill(Color.cyan.opacity(0.14))
                                .frame(width: 32, height: 32)
                            Image(systemName: "car.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.cyan)
                        }
                        BuxCatalogText.text("Mileage Log")
                            .buxHeadlineStyle(color: themeManager.labelPrimary(for: colorScheme))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(themeManager.labelSecondary(for: colorScheme).opacity(0.6))
                    }
                    .padding(.horizontal, BuxTokens.section)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }

                Divider().padding(.leading, 44)

                BuxCardButton(action: { showQuoteJob = true }) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: BuxTokens.tight, style: .continuous)
                                .fill(themeManager.accentWash(for: colorScheme))
                                .frame(width: 32, height: 32)
                            Image(systemName: "doc.text.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                        }
                        BuxCatalogText.text("Quote a job")
                            .buxHeadlineStyle(color: themeManager.labelPrimary(for: colorScheme))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(themeManager.labelSecondary(for: colorScheme).opacity(0.6))
                    }
                    .padding(.horizontal, BuxTokens.section)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }

                Divider().padding(.leading, 44)

                BuxCardButton(action: { navigateToInvoiceArchive = true }) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: BuxTokens.tight, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.brown.opacity(0.16),
                                            themeManager.current.accentColor.opacity(0.12)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 32, height: 32)
                            Image(systemName: "doc.text.image.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.brown, themeManager.current.accentColor],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                        BuxCatalogText.text("Backup invoices")
                            .buxHeadlineStyle(color: themeManager.labelPrimary(for: colorScheme))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(themeManager.labelSecondary(for: colorScheme).opacity(0.6))
                    }
                    .padding(.horizontal, BuxTokens.section)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
            }
        }
        .padding(.horizontal, BuxTokens.marginRegular)
    }

    private var markPaidAlertTitle: String {
        guard let id = pendingMarkPaidId else {
            return SimpleStudioCopy.line("Mark as paid?", locale: locale)
        }
        return display.iOweItems.contains { $0.id == id }
            ? SimpleStudioCopy.line("Mark as settled?", locale: locale)
            : SimpleStudioCopy.line("Mark as paid?", locale: locale)
    }

    private var markPaidConfirmLabel: String {
        guard let id = pendingMarkPaidId else {
            return SimpleStudioCopy.line("Mark paid", locale: locale)
        }
        return display.iOweItems.contains { $0.id == id }
            ? SimpleStudioCopy.line("Mark settled", locale: locale)
            : SimpleStudioCopy.line("Mark paid", locale: locale)
    }

    private var markPaidAlertMessage: String {
        guard let id = pendingMarkPaidId else {
            return SimpleStudioCopy.line("This will mark the balance as fully paid.", locale: locale)
        }
        return display.iOweItems.contains { $0.id == id }
            ? SimpleStudioCopy.line("This clears what you owe them.", locale: locale)
            : SimpleStudioCopy.line("This will mark the balance as fully paid.", locale: locale)
    }

    private func openEntry(for id: UUID) {
        if simpleStudioStore.entry(id: id) != nil {
            detailDestination = .entry(id)
        } else if simpleStudioStore.invoice(id: id) != nil {
            detailDestination = .invoice(id)
        }
    }

    private func shareReminder(for item: SimpleWaitingItem) {
        let phone = simpleStudioStore.customer(named: item.customerName)?.phone
        SimpleStudioReminderHelper.presentContactOptions(
            SimpleStudioReminderHelper.Payload(
                customerName: item.customerName,
                amountFormatted: item.amountFormatted,
                jobLabel: item.jobLabel,
                businessName: display.businessTitle,
                phone: phone,
                accent: themeManager.contrastAccentColor(for: colorScheme)
            ),
            openURL: openURL
        )
    }
}

private struct SimpleStudioHubScrollChromeModifier: ViewModifier {
    let usesPadSplitLayout: Bool

    func body(content: Content) -> some View {
        if usesPadSplitLayout {
            content.modifier(StudioPadSplitScrollChromeModifier())
        } else {
            content.modifier(SimpleStudioRootTabScrollChromeModifier())
        }
    }
}

private struct SimpleStudioRootTabScrollChromeModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
                .buxRootTabScrollChrome()
                .contentMargins(.top, BuxLayout.simpleStudioRootTabScrollTopInset, for: .scrollContent)
        } else {
            content.buxRootTabScrollChrome()
        }
    }
}
