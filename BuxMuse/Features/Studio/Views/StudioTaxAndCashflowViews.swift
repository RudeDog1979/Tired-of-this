//
//  StudioTaxAndCashflowViews.swift
//  BuxMuse
//
//  Self-employed tax calculators — all numbers from StudioBrain snapshots.
//

import SwiftUI

struct StudioTaxOverviewView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.studioHubEmbedded) private var studioHubEmbedded
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @EnvironmentObject private var store: StudioStore
    @EnvironmentObject private var studioBrain: StudioBrain

    var body: some View {
        let snapshot = studioBrain.taxSandboxDisplay

        Group {
            if studioHubEmbedded {
                taxOverviewContent(snapshot)
            } else {
                ZStack {
                    themeManager.screenBackground(for: colorScheme)
                        .ignoresSafeArea()

                    ScrollView(showsIndicators: false) {
                        taxOverviewContent(snapshot)
                    }
                }
                .buxCatalogNavigationTitle("Tax overview")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
        .onAppear {
            var params = studioBrain.taxSandboxParams
            params.indirectTaxRegistered = store.taxProfile.vatRegistered
            studioBrain.setTaxSandboxParams(params)
        }
    }

    // MARK: - Subviews

    private func taxOverviewContent(_ snapshot: TaxSandboxDisplay) -> some View {
        VStack(alignment: .leading, spacing: BuxLayout.section) {
            primaryRulesCard(snapshot)
            estimatesCard(snapshot)
            simulatorSandboxCard(snapshot)

            TaxReferenceDisclaimerNote()

            Spacer().frame(height: 40)
        }
        .studioHubEmbeddedHorizontalPadding()
        .padding(.top, BuxLayout.tight)
        .environment(\.studioEnhancedTint, true)
    }

    private func primaryRulesCard(_ snapshot: TaxSandboxDisplay) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                BuxCatalogDynamicText(key: "Your tax profile")
                    .font(.system(size: 11, weight: .bold))
                    .buxLabelSecondary()
                Spacer()
                Text(snapshot.currencyCode)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(themeManager.current.accentColor)
            }

            Text(snapshot.incomeTypeLabel)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(themeManager.current.accentColor)

            Text(snapshot.countryLabel)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(themeManager.labelPrimary(for: colorScheme))

            if snapshot.primaryRulesPreview.isEmpty {
                BuxCatalogDynamicText(key: "Open Tax profile to choose a country preset or enter your rules.")
                    .font(.system(size: 12))
                    .buxLabelSecondary()
            } else {
                Text(snapshot.primaryRulesPreview)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.85) : Color(red: 26/255, green: 28/255, blue: 32/255))
                    .fixedSize(horizontal: false, vertical: true)

                if !snapshot.indirectTaxNotes.isEmpty {
                    Divider()
                    Text(IndirectTaxLabelResolver.indirectTaxFieldLabel(for: store.taxProfile, locale: appSettingsManager.interfaceLocale))
                        .font(.system(size: 10, weight: .bold))
                        .buxLabelSecondary()
                    Text(snapshot.indirectTaxNotes)
                        .font(.system(size: 12, weight: .medium))
                        .buxLabelSecondary()
                }
            }
        }
        .padding(BuxLayout.section)
        .studioThemedCardChrome(cornerRadius: 24)
    }

    private func estimatesCard(_ snapshot: TaxSandboxDisplay) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(
                BuxLocalizedString.format(
                    "Income & deductions (%@)",
                    locale: appSettingsManager.interfaceLocale,
                    snapshot.currencyCode
                )
            )
                .font(.system(size: 11, weight: .bold))
                .buxLabelSecondary()

            HStack {
                metricColumn(title: "Gross income", value: snapshot.base.grossIncomeFormatted, color: themeManager.labelPrimary(for: colorScheme))
                Spacer()
                metricColumn(title: "Deductions", value: snapshot.base.deductionsFormatted, color: themeManager.current.accentColor)
                Spacer()
                metricColumn(title: "After deductions", value: snapshot.base.netIncomeFormatted, color: .green)
            }
            .padding(.vertical, 6)

            Divider()

            HStack {
                metricColumn(title: "Est. tax", value: snapshot.base.estimatedTaxFormatted, color: .orange)
                Spacer()
                metricColumn(
                    title: "Effective rate",
                    value: BuxLocalizedString.format(
                        "%lld%%",
                        locale: appSettingsManager.interfaceLocale,
                        Int64(snapshot.base.effectiveRatePercent)
                    ),
                    color: themeManager.current.accentColor
                )
            }

            HStack {
                Text(
                    BuxLocalizedString.format(
                        "%@:",
                        locale: appSettingsManager.interfaceLocale,
                        snapshot.indirectTaxRegistrationLabel
                    )
                )
                    .font(.system(size: 12))
                    .buxLabelSecondary()
                Spacer()
                Text(snapshot.base.indirectTaxFormatted)
                    .font(.system(size: 13, weight: .semibold))
            }
        }
        .padding(BuxLayout.section)
        .studioThemedCardChrome(cornerRadius: 24)
    }

    private func metricColumn(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(BuxCatalogLabel.string(title, locale: appSettingsManager.interfaceLocale))
                .font(.system(size: 9, weight: .semibold))
                .buxLabelSecondary()
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(color)
        }
    }

    private func simulatorSandboxCard(_ snapshot: TaxSandboxDisplay) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            BuxCatalogDynamicText(key: "Interactive tax simulator")
                .font(.system(size: 11, weight: .bold))
                .buxLabelSecondary()

            VStack(spacing: 12) {
                Toggle(snapshot.indirectTaxRegistrationLabel, isOn: Binding(
                    get: { studioBrain.taxSandboxParams.indirectTaxRegistered },
                    set: { newValue in
                        var params = studioBrain.taxSandboxParams
                        params.indirectTaxRegistered = newValue
                        studioBrain.setTaxSandboxParams(params)
                    }
                ))
                .font(.system(size: 13, weight: .semibold))

                Divider()

                sliderRow(
                    title: "Simulated Billing Rate Increase:",
                    valueLabel: "+\(appSettingsManager.format(Decimal(studioBrain.taxSandboxParams.rateIncrease)))/hr",
                    value: Binding(
                        get: { studioBrain.taxSandboxParams.rateIncrease },
                        set: { newValue in
                            var params = studioBrain.taxSandboxParams
                            params.rateIncrease = newValue
                            studioBrain.setTaxSandboxParams(params)
                        }
                    ),
                    range: 0...100,
                    step: 5
                )

                sliderRow(
                    title: "Simulated Monthly Billable Hours:",
                    valueLabel: "\(Int(studioBrain.taxSandboxParams.billableHours)) hrs",
                    value: Binding(
                        get: { studioBrain.taxSandboxParams.billableHours },
                        set: { newValue in
                            var params = studioBrain.taxSandboxParams
                            params.billableHours = newValue
                            studioBrain.setTaxSandboxParams(params)
                        }
                    ),
                    range: 0...160,
                    step: 10
                )

                sliderRow(
                    title: "Simulated Workspace Equipment purchases:",
                    valueLabel: appSettingsManager.format(Decimal(studioBrain.taxSandboxParams.newPurchases)),
                    value: Binding(
                        get: { studioBrain.taxSandboxParams.newPurchases },
                        set: { newValue in
                            var params = studioBrain.taxSandboxParams
                            params.newPurchases = newValue
                            studioBrain.setTaxSandboxParams(params)
                        }
                    ),
                    range: 0...5000,
                    step: 250
                )
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                BuxCatalogDynamicText(key: "PROJECTIONS OUTPUT")
                    .font(.system(size: 10, weight: .bold))
                    .buxLabelSecondary()

                projectionRow(title: "Gross Projected Revenue:", value: snapshot.simulated.grossIncomeFormatted)
                projectionRow(title: "Total Deducted Write-offs:", value: snapshot.simulated.deductionsFormatted, color: .green)
                projectionRow(title: "Estimated income tax:", value: snapshot.simulated.estimatedTaxFormatted, color: .orange)
                projectionRow(title: "Projected Net Profit:", value: snapshot.simulated.netIncomeFormatted, color: .green, bold: true)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(themeManager.themedCardFill(for: colorScheme))
            )
        }
        .padding(BuxLayout.section)
        .studioThemedCardChrome(cornerRadius: 24)
    }

    private func sliderRow(title: String, valueLabel: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(BuxCatalogLabel.string(title, locale: appSettingsManager.interfaceLocale))
                    .font(.system(size: 12))
                    .buxLabelSecondary()
                Spacer()
                Text(valueLabel)
                    .font(.system(size: 12, weight: .bold))
            }
            Slider(value: value, in: range, step: step)
                .tint(themeManager.current.accentColor)
        }
    }

    private func projectionRow(title: String, value: String, color: Color = .primary, bold: Bool = false) -> some View {
        HStack {
            Text(BuxCatalogLabel.string(title, locale: appSettingsManager.interfaceLocale))
                .font(.system(size: bold ? 13 : 12, weight: bold ? .bold : .regular))
            Spacer()
            Text(value)
                .font(.system(size: bold ? 14 : 13, weight: bold ? .bold : .regular, design: bold ? .rounded : .default))
                .foregroundColor(color)
        }
    }
}

// MARK: - Cashflow forecasting

struct StudioCashflowView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @EnvironmentObject private var studioBrain: StudioBrain

    var body: some View {
        let forecast = studioBrain.cashflowDisplay

        ZStack {
            themeManager.screenBackground(for: colorScheme)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: BuxLayout.section) {
                    VStack(alignment: .leading, spacing: 12) {
                        BuxCatalogDynamicText(key: "CASH RUNWAY TRAJECTORY")
                            .font(.system(size: 11, weight: .bold))
                            .buxLabelSecondary()

                        Text(forecast.runwayMonthsFormatted)
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.orange)

                        Text(
                            BuxLocalizedString.format(
                                "Estimated runway based on your %@ monthly burn rate.",
                                locale: appSettingsManager.interfaceLocale,
                                forecast.burnRateFormatted
                            )
                        )
                            .font(.system(size: 12))
                            .buxLabelSecondary()
                    }
                    .padding(BuxLayout.section)
                    .studioThemedCardChrome(cornerRadius: 24)

                    VStack(alignment: .leading, spacing: 12) {
                        BuxCatalogDynamicText(key: "SURVIVAL MODE TARGET")
                            .font(.system(size: 11, weight: .bold))
                            .buxLabelSecondary()

                        Text(forecast.survivalIncomeFormatted)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(themeManager.current.accentColor)

                        BuxCatalogDynamicText(key: "Minimum monthly inflow needed to comfortably clear direct costs, tax obligations, and hit standard savings cushions.")
                            .font(.system(size: 12))
                            .buxLabelSecondary()
                    }
                    .padding(BuxLayout.section)
                    .studioThemedCardChrome(cornerRadius: 24)
                }
                .padding(.horizontal, BuxLayout.marginHorizontal)
                .padding(.top, BuxLayout.tight)
                .environment(\.studioEnhancedTint, true)
            }
        }
        .buxCatalogNavigationTitle("Cashflow forecaster")
    }
}

// MARK: - Deductions optimization

struct StudioDeductionsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @EnvironmentObject private var store: StudioStore
    @EnvironmentObject private var studioBrain: StudioBrain

    var body: some View {
        let snapshot = studioBrain.deductionsDisplay

        ZStack {
            themeManager.screenBackground(for: colorScheme)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: BuxLayout.section) {
                    VStack(alignment: .leading, spacing: 12) {
                        BuxCatalogDynamicText(key: "TOTAL ACTIVE WRITE-OFF DEDUCTIONS")
                            .font(.system(size: 11, weight: .bold))
                            .buxLabelSecondary()

                        Text(snapshot.totalFormatted)
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.green)

                        if let mileageLine = snapshot.mileageSummaryFormatted {
                            Text(mileageLine)
                                .font(.system(size: 13, weight: .medium))
                                .buxLabelSecondary()
                        }

                        NavigationLink {
                            StudioMileageLogView()
                                .environmentObject(themeManager)
                                .environmentObject(appSettingsManager)
                                .environmentObject(store)
                                .environmentObject(studioBrain)
                        } label: {
                            Label("Open mileage log", systemImage: "car.fill")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .padding(.top, 4)
                    }
                    .padding(BuxLayout.section)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .studioThemedCardChrome(cornerRadius: 24)

                    BuxCatalogDynamicText(key: "OPTIMIZATION OPPORTUNITIES")
                        .font(.system(size: 11, weight: .bold))
                        .buxLabelSecondary()

                    if snapshot.opportunities.isEmpty {
                        BuxCatalogDynamicText(key: "No deduction opportunities right now.")
                            .font(.system(size: 13, weight: .semibold))
                            .buxLabelSecondary()
                            .padding()
                    } else {
                        ForEach(snapshot.opportunities) { opp in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(opp.title)
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                                    Spacer()
                                    Text(
                                        BuxLocalizedString.format(
                                            "Save %@",
                                            locale: appSettingsManager.interfaceLocale,
                                            opp.savingsFormatted
                                        )
                                    )
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.green)
                                }
                                Text(opp.description)
                                    .font(.system(size: 12))
                                    .buxLabelSecondary()
                            }
                            .padding(BuxLayout.section)
                            .studioThemedCardChrome(cornerRadius: 20)
                        }
                    }
                }
                .padding(.horizontal, BuxLayout.marginHorizontal)
                .padding(.top, BuxLayout.tight)
                .environment(\.studioEnhancedTint, true)
            }
        }
        .buxCatalogNavigationTitle("Deductions Sandbox")
    }
}
