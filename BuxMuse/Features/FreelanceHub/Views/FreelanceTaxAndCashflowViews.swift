//
//  FreelanceTaxAndCashflowViews.swift
//  BuxMuse
//
//  Self-employed tax calculators — all numbers from FreelanceBrain snapshots.
//

import SwiftUI

struct FreelanceTaxOverviewView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @EnvironmentObject private var store: FreelanceStore
    @EnvironmentObject private var freelanceBrain: FreelanceBrain

    var body: some View {
        let snapshot = freelanceBrain.taxSandboxDisplay

        ZStack {
            themeManager.screenBackground(for: colorScheme)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: BuxLayout.section) {
                    primaryRulesCard(snapshot)
                    estimatesCard(snapshot)
                    simulatorSandboxCard(snapshot)

                    TaxReferenceDisclaimerNote()

                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, BuxLayout.marginHorizontal)
                .padding(.top, BuxLayout.tight)
            }
        }
        .navigationTitle("Tax Sandbox")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            NavigationLink {
                FreelanceTaxReferenceView()
                    .environmentObject(themeManager)
                    .environmentObject(appSettingsManager)
            } label: {
                Text("Tax Profile")
                    .font(.system(size: 14, weight: .semibold))
            }
        }
        .onAppear {
            var params = freelanceBrain.taxSandboxParams
            params.indirectTaxRegistered = store.taxProfile.vatRegistered
            freelanceBrain.setTaxSandboxParams(params)
        }
    }

    // MARK: - Subviews

    private func primaryRulesCard(_ snapshot: TaxSandboxDisplay) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("YOUR TAX PROFILE")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.gray)
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
                .foregroundColor(colorScheme == .dark ? .white : .black)

            if snapshot.primaryRulesPreview.isEmpty {
                Text("Open Tax Profile to choose a country preset or enter your rules.")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            } else {
                Text(snapshot.primaryRulesPreview)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.85) : Color(red: 26/255, green: 28/255, blue: 32/255))
                    .fixedSize(horizontal: false, vertical: true)

                if !snapshot.indirectTaxNotes.isEmpty {
                    Divider()
                    Text(IndirectTaxLabelResolver.indirectTaxFieldLabel(for: store.taxProfile))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.gray)
                    Text(snapshot.indirectTaxNotes)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(BuxLayout.section)
        .background(colorScheme == .dark ? Color(red: 24/255, green: 26/255, blue: 32/255) : .white)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .buxCardOutline(themeManager: themeManager, colorScheme: colorScheme, cornerRadius: 24)
    }

    private func estimatesCard(_ snapshot: TaxSandboxDisplay) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("INCOME & DEDUCTIONS (\(snapshot.currencyCode))")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.gray)

            HStack {
                metricColumn(title: "GROSS INCOME", value: snapshot.base.grossIncomeFormatted, color: colorScheme == .dark ? .white : .black)
                Spacer()
                metricColumn(title: "DEDUCTIONS", value: snapshot.base.deductionsFormatted, color: themeManager.current.accentColor)
                Spacer()
                metricColumn(title: "AFTER DEDUCTIONS", value: snapshot.base.netIncomeFormatted, color: .green)
            }
            .padding(.vertical, 6)

            Divider()

            HStack {
                metricColumn(title: "EST. TAX", value: snapshot.base.estimatedTaxFormatted, color: .orange)
                Spacer()
                metricColumn(title: "EFFECTIVE", value: "\(snapshot.base.effectiveRatePercent)%", color: themeManager.current.accentColor)
            }

            HStack {
                Text("\(snapshot.indirectTaxRegistrationLabel):")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                Spacer()
                Text(snapshot.base.indirectTaxFormatted)
                    .font(.system(size: 13, weight: .semibold))
            }
        }
        .padding(BuxLayout.section)
        .background(colorScheme == .dark ? Color(red: 24/255, green: 26/255, blue: 32/255) : .white)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .buxCardOutline(themeManager: themeManager, colorScheme: colorScheme, cornerRadius: 24)
    }

    private func metricColumn(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.gray)
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(color)
        }
    }

    private func simulatorSandboxCard(_ snapshot: TaxSandboxDisplay) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("INTERACTIVE TAX SIMULATOR")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.gray)

            VStack(spacing: 12) {
                Toggle(snapshot.indirectTaxRegistrationLabel, isOn: Binding(
                    get: { freelanceBrain.taxSandboxParams.indirectTaxRegistered },
                    set: { newValue in
                        var params = freelanceBrain.taxSandboxParams
                        params.indirectTaxRegistered = newValue
                        freelanceBrain.setTaxSandboxParams(params)
                    }
                ))
                .font(.system(size: 13, weight: .semibold))

                Divider()

                sliderRow(
                    title: "Simulated Billing Rate Increase:",
                    valueLabel: "+\(appSettingsManager.format(Decimal(freelanceBrain.taxSandboxParams.rateIncrease)))/hr",
                    value: Binding(
                        get: { freelanceBrain.taxSandboxParams.rateIncrease },
                        set: { newValue in
                            var params = freelanceBrain.taxSandboxParams
                            params.rateIncrease = newValue
                            freelanceBrain.setTaxSandboxParams(params)
                        }
                    ),
                    range: 0...100,
                    step: 5
                )

                sliderRow(
                    title: "Simulated Monthly Billable Hours:",
                    valueLabel: "\(Int(freelanceBrain.taxSandboxParams.billableHours)) hrs",
                    value: Binding(
                        get: { freelanceBrain.taxSandboxParams.billableHours },
                        set: { newValue in
                            var params = freelanceBrain.taxSandboxParams
                            params.billableHours = newValue
                            freelanceBrain.setTaxSandboxParams(params)
                        }
                    ),
                    range: 0...160,
                    step: 10
                )

                sliderRow(
                    title: "Simulated Workspace Equipment purchases:",
                    valueLabel: appSettingsManager.format(Decimal(freelanceBrain.taxSandboxParams.newPurchases)),
                    value: Binding(
                        get: { freelanceBrain.taxSandboxParams.newPurchases },
                        set: { newValue in
                            var params = freelanceBrain.taxSandboxParams
                            params.newPurchases = newValue
                            freelanceBrain.setTaxSandboxParams(params)
                        }
                    ),
                    range: 0...5000,
                    step: 250
                )
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("PROJECTIONS OUTPUT")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.gray)

                projectionRow(title: "Gross Projected Revenue:", value: snapshot.simulated.grossIncomeFormatted)
                projectionRow(title: "Total Deducted Write-offs:", value: snapshot.simulated.deductionsFormatted, color: .green)
                projectionRow(title: "Estimated income tax:", value: snapshot.simulated.estimatedTaxFormatted, color: .orange)
                projectionRow(title: "Projected Net Profit:", value: snapshot.simulated.netIncomeFormatted, color: .green, bold: true)
            }
            .padding(12)
            .background(colorScheme == .dark ? Color.white.opacity(0.04) : Color.black.opacity(0.02))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .padding(BuxLayout.section)
        .background(colorScheme == .dark ? Color(red: 24/255, green: 26/255, blue: 32/255) : .white)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .buxCardOutline(themeManager: themeManager, colorScheme: colorScheme, cornerRadius: 24)
    }

    private func sliderRow(title: String, valueLabel: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
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
            Text(title)
                .font(.system(size: bold ? 13 : 12, weight: bold ? .bold : .regular))
            Spacer()
            Text(value)
                .font(.system(size: bold ? 14 : 13, weight: bold ? .bold : .regular, design: bold ? .rounded : .default))
                .foregroundColor(color)
        }
    }
}

// MARK: - Cashflow forecasting

struct FreelanceCashflowView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @EnvironmentObject private var freelanceBrain: FreelanceBrain

    var body: some View {
        let forecast = freelanceBrain.cashflowDisplay

        ZStack {
            themeManager.screenBackground(for: colorScheme)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: BuxLayout.section) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("CASH RUNWAY TRAJECTORY")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.gray)

                        Text(forecast.runwayMonthsFormatted)
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.orange)

                        Text("Estimated runway based on your \(forecast.burnRateFormatted) monthly burn rate.")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                    .padding(BuxLayout.section)
                    .background(colorScheme == .dark ? Color(red: 24/255, green: 26/255, blue: 32/255) : .white)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .buxCardOutline(themeManager: themeManager, colorScheme: colorScheme, cornerRadius: 24)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("SURVIVAL MODE TARGET")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.gray)

                        Text(forecast.survivalIncomeFormatted)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(themeManager.current.accentColor)

                        Text("Minimum monthly inflow needed to comfortably clear direct costs, tax obligations, and hit standard savings cushions.")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                    .padding(BuxLayout.section)
                    .background(colorScheme == .dark ? Color(red: 24/255, green: 26/255, blue: 32/255) : .white)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .buxCardOutline(themeManager: themeManager, colorScheme: colorScheme, cornerRadius: 24)
                }
                .padding(.horizontal, BuxLayout.marginHorizontal)
                .padding(.top, BuxLayout.tight)
            }
        }
        .navigationTitle("Cashflow forecaster")
    }
}

// MARK: - Deductions optimization

struct FreelanceDeductionsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var freelanceBrain: FreelanceBrain

    var body: some View {
        let snapshot = freelanceBrain.deductionsDisplay

        ZStack {
            themeManager.screenBackground(for: colorScheme)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: BuxLayout.section) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("TOTAL ACTIVE WRITE-OFF DEDUCTIONS")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.gray)

                        Text(snapshot.totalFormatted)
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.green)
                    }
                    .padding(BuxLayout.section)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(colorScheme == .dark ? Color(red: 24/255, green: 26/255, blue: 32/255) : .white)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .buxCardOutline(themeManager: themeManager, colorScheme: colorScheme, cornerRadius: 24)

                    Text("OPTIMIZATION OPPORTUNITIES")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.gray)

                    if snapshot.opportunities.isEmpty {
                        Text("No deduction opportunities right now.")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.gray)
                            .padding()
                    } else {
                        ForEach(snapshot.opportunities) { opp in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(opp.title)
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(colorScheme == .dark ? .white : .black)
                                    Spacer()
                                    Text("Save \(opp.savingsFormatted)")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.green)
                                }
                                Text(opp.description)
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                            }
                            .padding(BuxLayout.section)
                            .background(colorScheme == .dark ? Color(red: 24/255, green: 26/255, blue: 32/255) : .white)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .buxCardOutline(themeManager: themeManager, colorScheme: colorScheme, cornerRadius: 20)
                        }
                    }
                }
                .padding(.horizontal, BuxLayout.marginHorizontal)
                .padding(.top, BuxLayout.tight)
            }
        }
        .navigationTitle("Deductions Sandbox")
    }
}
