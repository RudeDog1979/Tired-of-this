//
//  StudioHubView.swift
//  BuxMuse
//
//  Studio — on-device command center for self-employed professionals.
//

import SwiftUI

struct StudioHubView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @EnvironmentObject private var store: StudioStore
    @EnvironmentObject private var studioBrain: StudioBrain
    @EnvironmentObject private var appDataManager: AppDataManager
    @EnvironmentObject private var navigationCoordinator: NavigationCoordinator
    @EnvironmentObject private var simpleStudioStore: SimpleStudioStore
    @EnvironmentObject private var financialBridge: FinancialEngineBridge
    @ObservedObject private var settingsStore = SettingsStore.shared
    @ObservedObject private var studioTimer = StudioTimerController.shared

    @State private var navigateToProfile = false
    @State private var navigateToClients = false
    @State private var navigateToInvoices = false
    @State private var navigateToProjects = false
    @State private var navigateToReceipts = false
    @State private var navigateToTax = false
    @State private var navigateToCashflow = false
    @State private var navigateToDeductions = false
    @State private var navigateToMileage = false
    @State private var navigateToAgreements = false
    @State private var navigateToInsights = false
    @State private var taxHubInitialTab: TaxStudioTab = .overview

    @State private var showNewInvoice = false
    @State private var proInvoicePrefill: StudioInvoiceSuggestion?
    @State private var showNewClient = false
    @State private var showScanReceipt = false
    @State private var showTimeTracker = false
    @State private var showProSearch = false
    @State private var showBusinessCardStudio = false
    @State private var navigateToInvoiceArchive = false
    @State private var hubAppeared = false

    private var display: StudioHubDisplay {
        studioBrain.hubDisplay
    }

    private var studioInsightsSnapshot: StudioInsightsSnapshot {
        StudioInsightsEngine.build(
            projects: store.projects,
            invoices: store.invoices,
            receipts: store.receipts,
            simpleEntries: simpleStudioStore.entries,
            profile: store.profile,
            locale: appSettingsManager.interfaceLocale,
            currencyFormat: { appSettingsManager.format($0) }
        )
    }

    var body: some View {
        Group {
            if settingsStore.studioMode == .pro {
                proStudioHub
            } else {
                SimpleStudioHubView()
                    .environmentObject(themeManager)
                    .environmentObject(appSettingsManager)
                    .environmentObject(store)
                    .environmentObject(navigationCoordinator)
            }
        }
    }

    private var proStudioHub: some View {
        NavigationStack {
            studioHubLayer
        }
        .background {
            TaxTranslationSessionBridgeView()
        }
        .buxInterfaceLocale()
    }

    private var studioHubLayer: some View {
        ZStack {
                BuxLandingTintBackground()
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: BuxTokens.block) {
                        StudioTierWordmark(style: .hero)
                            .padding(.horizontal, BuxTokens.marginRegular)
                            .buxScreenEntrance(index: 0, isVisible: hubAppeared)

                        HustleSelectorBar()
                            .padding(.bottom, 4)

                        StudioHeroCard(display: display.hero)
                            .buxScreenEntrance(index: 1, isVisible: hubAppeared)

                        if settingsStore.studioEnabled {
                            StudioIntelligenceSummaryCard(
                                projects: store.projects,
                                transactions: financialBridge.engine.allTransactions()
                            )
                            .environmentObject(themeManager)
                            .environmentObject(appSettingsManager)
                            .buxScreenEntrance(index: 2, isVisible: hubAppeared)
                        }

                        if display.isEmpty {
                            StudioHubEmptyState()
                                .buxScreenEntrance(index: 2, isVisible: hubAppeared)
                        }

                        StudioMetricsGrid(display: display.hero)
                            .buxScreenEntrance(index: 3, isVisible: hubAppeared)

                        StudioHubPulseCard(cashflow: display.cashflow)
                            .environmentObject(themeManager)
                            .buxScreenEntrance(index: 4, isVisible: hubAppeared)

                        quickActionsSection
                            .buxScreenEntrance(index: 5, isVisible: hubAppeared)

                        StudioProInvoiceSuggestionsSection(
                            suggestions: StudioInvoiceSuggestionEngine.proSuggestions(store: store)
                        ) { suggestion in
                            proInvoicePrefill = suggestion
                        }
                        .padding(.horizontal, BuxTokens.marginRegular)
                        .buxScreenEntrance(index: 5, isVisible: hubAppeared)

                        StudioInsightsHubSection(
                            snapshot: studioInsightsSnapshot,
                            onOpenDashboard: { navigateToInsights = true }
                        )
                        .padding(.horizontal, BuxTokens.marginRegular)
                        .buxScreenEntrance(index: 5, isVisible: hubAppeared)

                        StudioInvoicesSection(display: display.invoicesSummary) { navigateToInvoices = true }
                            .buxScreenEntrance(index: 6, isVisible: hubAppeared)
                        StudioClientsSection(clients: display.topClients) { navigateToClients = true }
                            .buxScreenEntrance(index: 7, isVisible: hubAppeared)
                        StudioTaxSection(display: display.taxSummary) { openTaxHub(.overview) }
                            .buxScreenEntrance(index: 8, isVisible: hubAppeared)
                        StudioCashflowSection(display: display.cashflow) { navigateToCashflow = true }
                            .buxScreenEntrance(index: 9, isVisible: hubAppeared)
                        StudioProjectsSection(display: display.projectsSummary) { navigateToProjects = true }
                            .buxScreenEntrance(index: 10, isVisible: hubAppeared)
                        StudioReceiptsSection(display: display.receiptsSummary) { navigateToReceipts = true }
                            .buxScreenEntrance(index: 11, isVisible: hubAppeared)
                        StudioDeductionsSection(items: display.deductionOpportunities) { navigateToDeductions = true }
                            .buxScreenEntrance(index: 12, isVisible: hubAppeared)
                        StudioAlertsSection(alerts: display.alerts)
                            .buxScreenEntrance(index: 13, isVisible: hubAppeared)

                        toolsSection
                            .buxScreenEntrance(index: 14, isVisible: hubAppeared)

                        Spacer().frame(height: BuxTokens.tight)
                    }
                    .padding(.top, BuxTokens.tight)
                    .environment(\.studioEnhancedTint, true)
                }
                .buxRootTabScrollChrome()
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .buxRootNavigationChrome()
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        StudioTierWordmark(style: .badge)

                        Button {
                            showProSearch = true
                        } label: {
                            Image(systemName: "sparkle.magnifyingglass")
                                .foregroundColor(themeManager.current.accentColor)
                        }
                        .accessibilityLabel(
                            BuxCatalogLabel.string("Pro Search", locale: appSettingsManager.interfaceLocale)
                        )

                        BuxProfileToolbarMenu {
                            Button {
                                navigateToProfile = true
                            } label: {
                                BuxCatalogText.text("Business Profile")
                            }
                            Button {
                                openTaxHub(.settings)
                            } label: {
                                BuxCatalogText.text("Tax Profile")
                            }
                        }
                    }
                }
            }
            .navigationDestination(isPresented: $showProSearch) {
                ProStudioSearchView()
                    .environmentObject(themeManager)
                    .environmentObject(appSettingsManager)
                    .environmentObject(store)
                    .environmentObject(simpleStudioStore)
                    .environmentObject(studioBrain)
            }
            .onAppear {
                studioTimer.attach(store: store)
                presentLogTimeIfRequested()
                guard !hubAppeared else { return }
                withAnimation(BuxMotion.bounce) {
                    hubAppeared = true
                }
            }
            .onChange(of: navigationCoordinator.openStudioLogTimeRequest) { _, _ in
                presentLogTimeIfRequested()
            }
            .fullScreenCover(isPresented: $showNewInvoice) {
                StudioInvoiceEditorView(invoiceToEdit: nil)
                    .environmentObject(themeManager)
                    .environmentObject(appSettingsManager)
                    .environmentObject(store)
            }
            .fullScreenCover(item: $proInvoicePrefill) { suggestion in
                StudioInvoiceEditorView(invoiceToEdit: nil, prefillSuggestion: suggestion)
                    .environmentObject(themeManager)
                    .environmentObject(appSettingsManager)
                    .environmentObject(store)
            }
            .sheet(isPresented: $showNewClient) {
                NewClientSheet()
                    .environmentObject(themeManager)
                    .environmentObject(appSettingsManager)
                    .buxStudioSheetContent()
            }
            .sheet(isPresented: $showScanReceipt) {
                StudioReceiptScannerView()
                    .environmentObject(themeManager)
                    .environmentObject(appSettingsManager)
                    .environmentObject(store)
                    .buxStudioSheetContent()
            }
            .sheet(isPresented: $showTimeTracker) {
                ActiveTimeTrackerView()
                    .environmentObject(themeManager)
                    .environmentObject(store)
                    .buxStudioSheetContent()
            }
            .navigationDestination(isPresented: $navigateToProfile) {
                StudioProfileView()
                    .environmentObject(themeManager)
                    .environmentObject(appSettingsManager)
                    .environment(\.studioEnhancedTint, true)
            }
            .navigationDestination(isPresented: $navigateToInvoices) {
                StudioInvoicesListView()
                    .environmentObject(themeManager)
                    .environmentObject(appSettingsManager)
                    .environmentObject(store)
                    .environment(\.studioEnhancedTint, true)
            }
            .navigationDestination(isPresented: $navigateToClients) {
                StudioClientsListView()
                    .environmentObject(themeManager)
                    .environmentObject(appSettingsManager)
                    .environmentObject(store)
                    .environment(\.studioEnhancedTint, true)
            }
            .navigationDestination(isPresented: $navigateToProjects) {
                StudioProjectsListView()
                    .environmentObject(themeManager)
                    .environmentObject(appSettingsManager)
                    .environmentObject(store)
                    .environmentObject(simpleStudioStore)
                    .environment(\.studioEnhancedTint, true)
            }
            .navigationDestination(isPresented: $navigateToAgreements) {
                AgreementScratchpadListView()
                    .environmentObject(themeManager)
                    .environmentObject(store)
                    .environmentObject(simpleStudioStore)
                    .environment(\.studioEnhancedTint, true)
            }
            .navigationDestination(isPresented: $navigateToInsights) {
                StudioInsightsDashboardView()
                    .environmentObject(themeManager)
                    .environmentObject(appSettingsManager)
                    .environmentObject(store)
                    .environmentObject(simpleStudioStore)
                    .environment(\.studioEnhancedTint, true)
            }
            .navigationDestination(isPresented: $navigateToReceipts) {
                StudioReceiptsListView()
                    .environmentObject(themeManager)
                    .environmentObject(appSettingsManager)
                    .environmentObject(store)
                    .environment(\.studioEnhancedTint, true)
            }
            .navigationDestination(isPresented: $navigateToTax) {
                TaxStudioHubView(initialTab: taxHubInitialTab)
                    .environmentObject(themeManager)
                    .environmentObject(appSettingsManager)
                    .environmentObject(appDataManager)
                    .environmentObject(store)
                    .environmentObject(studioBrain)
                    .environment(\.studioEnhancedTint, true)
            }
            .navigationDestination(isPresented: $navigateToCashflow) {
                StudioCashflowView()
                    .environmentObject(themeManager)
                    .environmentObject(appSettingsManager)
                    .environment(\.studioEnhancedTint, true)
            }
            .navigationDestination(isPresented: $navigateToDeductions) {
                StudioDeductionsView()
                    .environmentObject(themeManager)
                    .environmentObject(appSettingsManager)
                    .environmentObject(store)
                    .environmentObject(studioBrain)
                    .environment(\.studioEnhancedTint, true)
            }
            .navigationDestination(isPresented: $navigateToMileage) {
                StudioMileageLogView()
                    .environmentObject(themeManager)
                    .environmentObject(appSettingsManager)
                    .environmentObject(store)
                    .environmentObject(studioBrain)
                    .environment(\.studioEnhancedTint, true)
            }
            .navigationDestination(isPresented: $navigateToInvoiceArchive) {
                StudioInvoiceArchiveView()
                    .environmentObject(themeManager)
                    .environmentObject(appSettingsManager)
                    .environmentObject(store)
                    .environmentObject(simpleStudioStore)
                    .environment(\.studioEnhancedTint, true)
            }
            .navigationDestination(isPresented: $showBusinessCardStudio) {
                ProBusinessCardStudioView()
                    .environmentObject(themeManager)
                    .environmentObject(store)
                    .environmentObject(simpleStudioStore)
                    .environment(\.studioEnhancedTint, true)
            }
            .environment(\.studioEnhancedTint, true)
    }

    private func openTaxHub(_ tab: TaxStudioTab) {
        taxHubInitialTab = tab
        navigateToTax = true
    }

    private func presentLogTimeIfRequested() {
        guard navigationCoordinator.consumeStudioLogTimeRequest() else { return }
        showTimeTracker = true
    }

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: BuxTokens.tight) {
            BuxSectionHeader(title: "Quick Actions")

            HStack(spacing: BuxTokens.tight) {
                BuxQuickActionButton(
                    title: "New Invoice",
                    systemImage: "plus.rectangle.fill.on.folder.fill",
                    role: .primary
                ) { showNewInvoice = true }

                TimelineView(.periodic(from: .now, by: 1.0)) { _ in
                    BuxQuickActionButton(
                        title: studioTimer.hasActiveSession
                            ? StudioTimerSession.formattedElapsed(studioTimer.displayElapsed, style: .hub)
                            : "Log Time",
                        systemImage: studioTimer.isRunning
                            ? "stopwatch.fill"
                            : (studioTimer.hasActiveSession ? "pause.circle.fill" : "stopwatch.fill"),
                        role: .primary
                    ) { showTimeTracker = true }
                }

                BuxQuickActionButton(
                    title: "Scan Receipt",
                    systemImage: "doc.text.viewfinder",
                    role: .primary
                ) { showScanReceipt = true }
            }
            .fixedSize(horizontal: false, vertical: true)
            .buxNativeGlassButtonRowContainer(spacing: BuxTokens.tight)
            .tint(themeManager.contrastAccentColor(for: colorScheme))
        }
    }

    private var toolsSection: some View {
        VStack(alignment: .leading, spacing: BuxTokens.tight) {
            BuxSectionHeader(title: "Tools")

            BuxCard(elevation: .card, cornerRadius: BuxTokens.Radius.card, padding: 0) {
                VStack(spacing: 0) {
                    navRow(title: "Invoices", icon: "doc.text.fill", color: .green) { navigateToInvoices = true }
                    studioRowDivider
                    navRow(title: "Clients", icon: "person.2.fill", color: .blue) { navigateToClients = true }
                    studioRowDivider
                    navRow(title: "Expenses", icon: "doc.plaintext.fill", color: .teal) { navigateToReceipts = true }
                    studioRowDivider
                    navRow(title: "Projects", icon: "folder.fill", color: .purple) { navigateToProjects = true }
                    studioRowDivider
                    navRow(title: "Agreements", icon: "signature", color: .indigo) { navigateToAgreements = true }
                    studioRowDivider
                    navRow(title: "Studio Insights", icon: "chart.bar.xaxis", color: .mint) { navigateToInsights = true }
                    studioRowDivider
                    navRow(title: "Tax studio", icon: "percent", color: .red) { openTaxHub(.overview) }
                    studioRowDivider
                    navRow(title: "Cashflow", icon: "chart.line.uptrend.xyaxis", color: .orange) { navigateToCashflow = true }
                    studioRowDivider
                    navRow(title: "Business Card Studio", icon: "person.crop.rectangle.fill", color: .pink) {
                        showBusinessCardStudio = true
                    }
                    studioRowDivider
                    navRow(title: "Mileage Log", icon: "car.fill", color: .cyan) { navigateToMileage = true }
                    studioRowDivider
                    navRow(title: "Deductions", icon: "lightbulb.fill", color: .yellow) { navigateToDeductions = true }
                    studioRowDivider
                    navRow(title: "Backup invoices", icon: "doc.text.image.fill", color: .brown) {
                        navigateToInvoiceArchive = true
                    }
                }
            }
        }
    }

    private var studioRowDivider: some View {
        Divider().padding(.leading, 44)
    }

    private func navRow(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        BuxCardButton(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: BuxTokens.tight, style: .continuous)
                        .fill(color.opacity(0.12))
                        .frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(color)
                }
                BuxCatalogText.text(title)
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

// MARK: - New Client Sheet

struct NewClientSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var store: StudioStore
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    @State private var name = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var party = InvoicePartyDetails()
    @State private var rate = ""
    @State private var terms = "14"

    private var locale: Locale { appSettingsManager.interfaceLocale }

    private func loc(_ key: String) -> String {
        BuxCatalogLabel.string(key, locale: locale)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.screenBackground(for: colorScheme).ignoresSafeArea()

                BuxThemedCardForm {
                    BuxFormSection(title: "Client Info") {
                        TextField(loc("Display name"), text: $name)
                            .buxFormFieldPadding()
                        BuxFormRowDivider()
                        TextField(loc("Email"), text: $email)
                            .keyboardType(.emailAddress)
                            .onChange(of: email) { _, v in party.email = v }
                            .buxFormFieldPadding()
                        BuxFormRowDivider()
                        TextField(loc("Phone"), text: $phone)
                            .keyboardType(.phonePad)
                            .onChange(of: phone) { _, v in party.phone = v }
                            .buxFormFieldPadding()
                    }

                    BuxFormSection(title: "Invoice Bill-To Details") {
                        InvoicePartyEditorFields(
                            party: $party,
                            showRegistrationFields: true
                        )
                    }

                    BuxFormSection(title: "Contract settings") {
                        TextField(loc("Default Hourly Rate"), text: $rate)
                            .keyboardType(.decimalPad)
                            .buxFormFieldPadding()
                        BuxFormRowDivider()
                        Picker(loc("Payment Terms (Days)"), selection: $terms) {
                            BuxCatalogDynamicText(key: "Due on Receipt").tag("0")
                            BuxCatalogDynamicText(key: "7 Days").tag("7")
                            BuxCatalogDynamicText(key: "14 Days").tag("14")
                            BuxCatalogDynamicText(key: "30 Days").tag("30")
                            BuxCatalogDynamicText(key: "60 Days").tag("60")
                        }
                        .buxFormFieldPadding()
                    }
                }
            }
            .buxCatalogNavigationTitle("New Client")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    BuxToolbarCancelButton { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    BuxToolbarSaveButton(isDirty: !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
                        var client = StudioClient(
                            name: name.isEmpty ? party.primaryTitle : name,
                            email: party.email.isEmpty ? email : party.email,
                            phone: party.phone.isEmpty ? phone : party.phone,
                            defaultRate: Decimal(string: rate),
                            paymentTermsDays: Int(terms),
                            hustleId: SettingsStore.shared.sideHustleMatrixEnabled
                                ? HustleManager.shared.selectedHustleId
                                : nil
                        )
                        if party.countryCode.isEmpty {
                            party.countryCode = appSettingsManager.selectedCountry.id
                        }
                        client.applyPartyDetails(party)
                        store.addClient(client)
                        BuxSaveFeedback.success()
                        dismiss()
                    }
                }
            }
            .buxStudioSheetContent()
        }
    }
}
