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
            themeManager.screenBackground(for: colorScheme)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                hubHeader

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
                    .padding(.bottom, 60)
                    .buxScreenContentMargins()
                }
                .buxReportsContainerWidth()
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
                            viewModel.simulateCancel(merchantName: name)
                        }
                    },
                    isPresented: $showDetailSheet
                )
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
        .ignoresSafeArea(.keyboard)
    }

    // MARK: - Header (true center title)

    private var hubHeader: some View {
        ZStack {
            Text("Subscription Hub")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(colorScheme == .dark ? .white : Color(red: 26/255, green: 28/255, blue: 32/255))

            HStack {
                Button(action: {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                        isPresented = false
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(colorScheme == .dark ? Color.white.opacity(0.08) : .white)
                            .frame(width: 44, height: 44)
                            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)

                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(colorScheme == .dark ? .white : .black)
                    }
                }
                .buttonStyle(BuxMicroShrinkStyle())

                Spacer()

                ZStack {
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 44, height: 44)

                    Image(systemName: "cpu")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(themeManager.current.accentColor)
                }
                .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, BuxLayout.marginHorizontal)
        .padding(.top, 64)
        .padding(.bottom, BuxLayout.section)
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
                    SubscriptionHubSectionHeader(title: "ACTIVE SUBSCRIPTIONS")

                    Spacer(minLength: 8)

                    HStack(spacing: 4) {
                        Image(systemName: "waveform.path.ecg")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.green)
                        Text("Health: \(viewModel.healthScore)%")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.green)
                    }
                }

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(appSettingsManager.format(viewModel.totalMonthlyCost.value))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Text("/month")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.gray)

                    Spacer(minLength: 0)
                }

                Text(viewModel.monthlyChangeDescription)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : Color(red: 100/255, green: 110/255, blue: 130/255))
                    .lineLimit(2)
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
