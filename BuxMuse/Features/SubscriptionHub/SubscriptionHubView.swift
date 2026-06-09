//
//  SubscriptionHubView.swift
//  BuxMuse
//  Features/SubscriptionHub/
//
//  Premium Subscription Hub view transforming and replacing ExchangeView.
//

import SwiftUI

struct SubscriptionHubView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.buxLayoutMode) private var layoutMode
    @Environment(\.buxPadInspectorColumn) private var isPadInspectorColumn
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var appSettingsManager: AppSettingsManager
    @EnvironmentObject var brain: BuxMuseBrain

    @Binding var isPresented: Bool

    @StateObject private var viewModel: SubscriptionHubViewModel
    @State private var showDetailSheet = false

    private let hubSnapshot: SubscriptionHubSnapshot

    init(
        isPresented: Binding<Bool>,
        engine: FinancialIntelligenceEngine,
        settingsManager: AppSettingsManager,
        hubSnapshot: SubscriptionHubSnapshot
    ) {
        self._isPresented = isPresented
        self.hubSnapshot = hubSnapshot
        self._viewModel = StateObject(wrappedValue: SubscriptionHubViewModel(engine: engine, settingsManager: settingsManager))
    }

    var body: some View {
        ZStack {
            NavigationStack {
                ZStack {
                    Group {
                        if isPadInspectorColumn {
                            Color.clear
                        } else {
                            themeManager.screenBackground(for: colorScheme)
                        }
                    }
                    .ignoresSafeArea()

                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: BuxLayout.section) {
                            overviewCard

                            SubscriptionRenewalTimelineView(renewals: viewModel.upcomingRenewals) { name in
                                triggerDetail(for: name)
                            }

                            SubscriptionBurnRateView(
                                daily: viewModel.dailyBurnRate,
                                weekly: viewModel.weeklyBurnRate,
                                monthly: viewModel.monthlyBurnRate,
                                yearly: viewModel.yearlyBurnRate,
                                projectionText: viewModel.burnRateCancellationProjection,
                                quarterlyIncrease: viewModel.burnRateQuarterlyIncrease
                            )

                            SubscriptionRiskAnalyzerView(subscriptions: viewModel.subscriptions) { name in
                                triggerDetail(for: name)
                            }

                            SubscriptionOpportunitiesView(subscriptions: viewModel.subscriptions) { name in
                                triggerDetail(for: name)
                            }

                            SubscriptionCategoryDetailView(subscriptions: viewModel.subscriptions)
                        }
                        .padding(.vertical, BuxLayout.section)
                        .padding(.bottom, BuxOverlayMetrics.scrollBottomInset)
                        .modifier(SubscriptionHubContentMarginsModifier(
                            isPadInspectorColumn: isPadInspectorColumn,
                            layoutMode: layoutMode
                        ))
                    }
                    .buxDetailScrollChrome()
                }
                .buxCatalogNavigationTitle("Subscription Hub")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        BuxToolbarBackButton {
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                                isPresented = false
                            }
                        }
                    }
                }
                .buxDetailNavigationChrome()
            }

            if showDetailSheet {
                Color.black.opacity(colorScheme == .dark ? 0.55 : 0.35)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
                            showDetailSheet = false
                        }
                    }
                    .zIndex(5)
            }

            if showDetailSheet, let detail = viewModel.selectedDetail {
                SubscriptionDetailView(
                    detail: detail,
                    onCancelTriggered: { name in
                        withAnimation {
                            try? brain.cancelSubscription(merchantName: name)
                            viewModel.refreshData()
                        }
                    },
                    isPresented: $showDetailSheet
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .move(edge: .bottom).combined(with: .opacity)
                ))
                .zIndex(10)
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.78), value: showDetailSheet)
        .onAppear {
            viewModel.applySnapshot(hubSnapshot, settingsManager: appSettingsManager)
        }
        .onChange(of: brain.subscriptionHubSnapshot) { _, newSnapshot in
            viewModel.applySnapshot(newSnapshot, settingsManager: appSettingsManager)
        }
        .buxThemedPresentation()
        .buxInterfaceLocale()
        .ignoresSafeArea(.keyboard)
    }

    // MARK: - Overview hero (compact vs old 38pt slab)

    private var overviewCard: some View {
        Button(action: {
            if let firstSub = viewModel.subscriptions.first {
                triggerDetail(for: firstSub.merchantName)
            }
        }) {
            VStack(alignment: .leading, spacing: BuxLayout.section) {
                HStack {
                    SubscriptionHubSectionHeader(title: "Active subscriptions")

                    Spacer(minLength: 8)

                    HStack(spacing: 4) {
                        Image(systemName: "waveform.path.ecg")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.green)
                        Text(
                            BuxLocalizedString.format(
                                "Health: %lld%%",
                                locale: appSettingsManager.interfaceLocale,
                                viewModel.healthScore
                            )
                        )
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.green)
                    }
                }

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(appSettingsManager.format(viewModel.totalMonthlyCost.value))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    BuxCatalogText.text("/month")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(themeManager.labelSecondary(for: colorScheme))

                    Spacer(minLength: 0)
                }

                Text(viewModel.monthlyChangeDescription)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : Color(red: 100/255, green: 110/255, blue: 130/255))
                    .lineLimit(2)

                if viewModel.totalWeeklyCost.value > 0 || viewModel.totalIrregularCost.value > 0 {
                    HStack(spacing: 12) {
                        if viewModel.totalWeeklyCost.value > 0 {
                            Text(
                                BuxLocalizedString.format(
                                    "Weekly subs: %@",
                                    locale: appSettingsManager.interfaceLocale,
                                    appSettingsManager.format(viewModel.totalWeeklyCost.value)
                                )
                            )
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.gray)
                        }
                        if viewModel.totalIrregularCost.value > 0 {
                            Text(
                                BuxLocalizedString.format(
                                    "Irregular: %@",
                                    locale: appSettingsManager.interfaceLocale,
                                    appSettingsManager.format(viewModel.totalIrregularCost.value)
                                )
                            )
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.gray)
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
            .padding(SubscriptionHubStyle.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .subscriptionHubCard()
        }
        .buttonStyle(BuxMicroShrinkStyle())
    }

    private func triggerDetail(for name: String) {
        viewModel.loadDetail(for: name)
        if viewModel.selectedDetail != nil {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
                showDetailSheet = true
            }
        }
    }
}
