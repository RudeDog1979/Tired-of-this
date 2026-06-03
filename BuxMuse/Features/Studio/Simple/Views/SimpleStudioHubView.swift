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
    @EnvironmentObject private var simpleStudioBrain: SimpleStudioBrain
    @EnvironmentObject private var simpleStudioStore: SimpleStudioStore
    @EnvironmentObject private var navigationCoordinator: NavigationCoordinator
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
    @State private var proUpsellFeature: StudioProUpsellSheet.Feature?

    private var display: SimpleStudioHubDisplay { simpleStudioBrain.hubDisplay }

    private var simpleInsights: SimpleStudioInsightsSnapshot {
        SimpleStudioInsightsEngine.build(
            entries: simpleStudioStore.entries,
            currencyFormat: { appSettingsManager.format($0) }
        )
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                BuxLandingTintBackground()
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: BuxTokens.block) {
                        SimpleStudioHeader()
                            .padding(.horizontal, BuxTokens.marginRegular)
                            .buxScreenEntrance(index: 0, isVisible: hubAppeared)

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
                        .buxScreenEntrance(index: 1, isVisible: hubAppeared)

                        SimpleStudioHeroCard(display: display)
                            .buxScreenEntrance(index: 2, isVisible: hubAppeared)

                        SimpleStudioInsightsHubSection(snapshot: simpleInsights)
                            .padding(.horizontal, BuxTokens.marginRegular)
                            .buxScreenEntrance(index: 2, isVisible: hubAppeared)

                        SimpleStudioInvoiceSuggestionsSection(
                            suggestions: StudioInvoiceSuggestionEngine.simpleSuggestions(
                                store: simpleStudioStore,
                                studioStore: studioStore
                            )
                        ) { suggestion in
                            invoicePrefill = suggestion
                        }
                        .padding(.horizontal, BuxTokens.marginRegular)
                        .buxScreenEntrance(index: 2, isVisible: hubAppeared)

                        simpleLogTimeQuickAction
                            .buxScreenEntrance(index: 2, isVisible: hubAppeared)

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

                        SimpleStudioTaxSection(tile: display.taxTile) {
                            proUpsellFeature = .fullTax
                        }
                            .buxScreenEntrance(index: 8, isVisible: hubAppeared)

                        Spacer().frame(height: 100)
                    }
                    .padding(.top, BuxTokens.tight)
                    .padding(.horizontal, BuxTokens.marginRegular)
                }
                .buxRootTabScrollChrome()

                fabLayer
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .buxRootNavigationChrome()
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        Button {
                            showSearch = true
                        } label: {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(themeManager.current.accentColor)
                        }
                        .accessibilityLabel("Search")

                        Menu {
                            Button("People") { showPeople = true }
                            Button("Upgrade to Pro") {
                                _ = SimpleStudioUpgradeCoordinator.upgradeToPro(
                                    simpleStore: simpleStudioStore,
                                    studioStore: studioStore,
                                    settings: settingsStore,
                                    currencyCode: appSettingsManager.selectedCurrency.id
                                )
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .foregroundColor(themeManager.current.accentColor)
                        }
                    }
                }
            }
            .navigationDestination(isPresented: $showSearch) {
                SimpleStudioSearchView(store: simpleStudioStore, isProSearch: false)
                    .environmentObject(themeManager)
                    .environmentObject(appSettingsManager)
                    .environmentObject(studioStore)
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
                Button("Cancel", role: .cancel) {
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
            }
            .sheet(isPresented: $showScan) {
                SimpleStudioScanView(store: simpleStudioStore)
                    .environmentObject(themeManager)
                    .environmentObject(appSettingsManager)
            }
            .sheet(isPresented: $showInvoice) {
                SimpleStudioSimpleInvoiceSheet(store: simpleStudioStore)
                    .environmentObject(themeManager)
                    .environmentObject(appSettingsManager)
                    .environmentObject(studioStore)
            }
            .sheet(item: $invoicePrefill) { prefill in
                SimpleStudioSimpleInvoiceSheet(store: simpleStudioStore, prefill: prefill)
                    .environmentObject(themeManager)
                    .environmentObject(appSettingsManager)
                    .environmentObject(studioStore)
            }
            .sheet(isPresented: $showBusinessCard) {
                SimpleStudioBusinessCardSheet(store: simpleStudioStore)
                    .environmentObject(themeManager)
                    .environmentObject(appSettingsManager)
                    .environmentObject(studioStore)
            }
            .sheet(isPresented: $showQuoteJob) {
                SimpleStudioJobQuoteSheet(store: simpleStudioStore, existingJob: editingJob)
                    .environmentObject(themeManager)
                    .environmentObject(appSettingsManager)
                    .environmentObject(studioStore)
                    .onDisappear { editingJob = nil }
            }
            .navigationDestination(isPresented: $showPeople) {
                SimpleStudioPeopleView(store: simpleStudioStore)
                    .environmentObject(themeManager)
                    .environmentObject(appSettingsManager)
            }
        }
    }

    @ViewBuilder
    private var fabLayer: some View {
        if isFabExpanded {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                        isFabExpanded = false
                    }
                }
                .zIndex(4)

            VStack(spacing: 10) {
                fabItem(title: "Work clock", icon: "stopwatch.fill", delay: 0.01) {
                    closeFab { showLogTime = true }
                }
                fabItem(title: "Scan", icon: "camera.viewfinder", delay: 0.02) {
                    closeFab { showScan = true }
                }
                fabItem(title: "Quote job", icon: "doc.text.magnifyingglass", delay: 0.04) {
                    closeFab {
                        editingJob = nil
                        showQuoteJob = true
                    }
                }
                fabItem(title: "Log money", icon: "banknote.fill", delay: 0.07) {
                    closeFab {
                        logMoneyKind = nil
                        showLogMoney = true
                    }
                }
                fabItem(title: "Invoice", icon: "doc.text.fill", delay: 0.08) {
                    closeFab { showInvoice = true }
                }
                fabItem(title: "Business card", icon: "person.crop.rectangle.fill", delay: 0.09) {
                    closeFab { showBusinessCard = true }
                }
                fabItem(title: "They owe me", icon: "person.fill.questionmark", delay: 0.11) {
                    closeFab {
                        logMoneyKind = .owedToMe
                        showLogMoney = true
                    }
                }
                fabItem(title: "I owe", icon: "person.fill.xmark", delay: 0.14) {
                    closeFab {
                        logMoneyKind = .iOwe
                        showLogMoney = true
                    }
                }
            }
            .padding(.horizontal, BuxTokens.marginRegular)
            .padding(.bottom, 88)
            .zIndex(5)
        }

        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
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
        }
        .padding(.trailing, BuxTokens.marginRegular)
        .padding(.bottom, BuxTokens.section)
        .zIndex(6)
        .accessibilityLabel(isFabExpanded ? "Close menu" : "Add")
    }

    private func fabItem(title: String, icon: String, delay: Double, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 36, height: 36)
                    .background(themeManager.accentWash(for: colorScheme))
                    .foregroundColor(themeManager.current.accentColor)
                    .clipShape(Circle())
                Text(title)
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
                             : "Work clock")
                            .font(.system(size: 15, weight: .bold))
                        Text("Track time — hourly or one-price jobs")
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

    private func presentLogTimeIfRequested() {
        guard navigationCoordinator.consumeStudioLogTimeRequest() else { return }
        showLogTime = true
    }

    private func closeFab(_ action: @escaping () -> Void) {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
            isFabExpanded = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            action()
        }
    }

    private var markPaidAlertTitle: String {
        guard let id = pendingMarkPaidId else { return "Mark as paid?" }
        return display.iOweItems.contains { $0.id == id } ? "Mark as settled?" : "Mark as paid?"
    }

    private var markPaidConfirmLabel: String {
        guard let id = pendingMarkPaidId else { return "Mark paid" }
        return display.iOweItems.contains { $0.id == id } ? "Mark settled" : "Mark paid"
    }

    private var markPaidAlertMessage: String {
        guard let id = pendingMarkPaidId else {
            return "This will mark the balance as fully paid."
        }
        return display.iOweItems.contains { $0.id == id }
            ? "This clears what you owe them."
            : "This will mark the balance as fully paid."
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
                accent: themeManager.current.accentColor
            ),
            openURL: openURL
        )
    }
}
