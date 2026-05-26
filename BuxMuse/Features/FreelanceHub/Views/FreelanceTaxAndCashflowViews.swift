//
//  FreelanceTaxAndCashflowViews.swift
//  BuxMuse
//
//  Self-employed tax calculators accompanied by interactive rate simulators and runways.
//

import SwiftUI

struct FreelanceTaxOverviewView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    
    @EnvironmentObject private var store: FreelanceStore
    
    // Interactive Simulator States
    @State private var vatToggled = false
    @State private var rateIncrease = 0.0
    @State private var billableHours = 0.0
    @State private var newPurchases = 0.0
    
    var body: some View {
        let baseResult = FreelanceTaxEngine.computeEstimatedTax(profile: store.profile, taxProfile: store.taxProfile, invoices: store.invoices, receipts: store.receipts)
        let simResult = FreelanceTaxEngine.simulate(
            profile: store.profile,
            taxProfile: store.taxProfile,
            baseResult: baseResult,
            vatToggled: vatToggled,
            hypotheticalRateIncrease: Decimal(rateIncrease),
            hypotheticalHoursCount: billableHours,
            newPurchasesAmount: Decimal(newPurchases)
        )
        
        ZStack {
            themeManager.screenBackground(for: colorScheme)
                .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: BuxLayout.section) {
                    
                    // 1. Core Estimates
                    estimatesCard(base: baseResult)
                    
                    // 2. Interactive Simulation Sandbox
                    simulatorSandboxCard(base: baseResult, sim: simResult)
                    
                    Spacer()
                        .frame(height: 40)
                }
                .padding(.horizontal, BuxLayout.marginHorizontal)
                .padding(.top, BuxLayout.tight)
            }
        }
        .navigationTitle("Tax Sandbox")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            NavigationLink {
                FreelanceTaxProfileEditorView()
                    .environmentObject(themeManager)
            } label: {
                Text("Tax Profile")
                    .font(.system(size: 14, weight: .semibold))
            }
        }
        .onAppear {
            vatToggled = store.profile.vatRegistered
        }
    }
    
    // MARK: - Subviews
    
    private func estimatesCard(base: TaxSimulationResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ESTIMATED CURRENT TAX BURDEN")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.gray)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("GROSS INCOME")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.gray)
                    Text(appSettingsManager.format(base.totalGrossIncome))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                }
                Spacer()
                VStack(alignment: .leading, spacing: 4) {
                    Text("ESTIMATED TAX")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.gray)
                    Text(appSettingsManager.format(base.estimatedTax))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(themeManager.current.accentColor)
                }
                Spacer()
                VStack(alignment: .leading, spacing: 4) {
                    Text("NET EARNINGS")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.gray)
                    Text(appSettingsManager.format(base.netIncome))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.green)
                }
            }
            .padding(.vertical, 6)
            
            Divider()
            
            HStack {
                Text("Estimated VAT/GST Owed:")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                Spacer()
                Text(appSettingsManager.format(base.estimatedVat))
                    .font(.system(size: 13, weight: .semibold))
            }
        }
        .padding(BuxLayout.section)
        .background(colorScheme == .dark ? Color(red: 24/255, green: 26/255, blue: 32/255) : .white)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .buxCardOutline(themeManager: themeManager, colorScheme: colorScheme, cornerRadius: 24)
    }
    
    private func simulatorSandboxCard(base: TaxSimulationResult, sim: TaxSimulationResult) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("INTERACTIVE TAX SIMULATOR")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.gray)
            
            VStack(spacing: 12) {
                // VAT Toggle
                Toggle("VAT/GST Registration Mode", isOn: $vatToggled)
                    .font(.system(size: 13, weight: .semibold))
                
                Divider()
                
                // Hourly rate bump
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Simulated Billing Rate Increase:")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                        Spacer()
                        Text("+\(appSettingsManager.format(Decimal(rateIncrease)))/hr")
                            .font(.system(size: 12, weight: .bold))
                    }
                    Slider(value: $rateIncrease, in: 0...100, step: 5)
                        .tint(themeManager.current.accentColor)
                }
                
                // Simulated Hours
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Simulated Monthly Billable Hours:")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                        Spacer()
                        Text("\(Int(billableHours)) hrs")
                            .font(.system(size: 12, weight: .bold))
                    }
                    Slider(value: $billableHours, in: 0...160, step: 10)
                        .tint(themeManager.current.accentColor)
                }
                
                // New Purchases
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Simulated Workspace Equipment purchases:")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                        Spacer()
                        Text(appSettingsManager.format(Decimal(newPurchases)))
                            .font(.system(size: 12, weight: .bold))
                    }
                    Slider(value: $newPurchases, in: 0...5000, step: 250)
                        .tint(themeManager.current.accentColor)
                }
            }
            
            Divider()
            
            // Simulation Output Comparing
            VStack(alignment: .leading, spacing: 8) {
                Text("PROJECTIONS OUTPUT")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.gray)
                
                HStack {
                    Text("Gross Projected Revenue:")
                        .font(.system(size: 12))
                    Spacer()
                    Text(appSettingsManager.format(sim.totalGrossIncome))
                        .fontWeight(.bold)
                }
                HStack {
                    Text("Total Deducted Write-offs:")
                        .font(.system(size: 12))
                    Spacer()
                    Text(appSettingsManager.format(sim.totalDeductions))
                        .foregroundColor(.green)
                }
                HStack {
                    Text("Projected Net Profit:")
                        .font(.system(size: 13, weight: .bold))
                    Spacer()
                    Text(appSettingsManager.format(sim.netIncome))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.green)
                }
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
}

// MARK: - Cashflow forecasting

struct FreelanceCashflowView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    
    @EnvironmentObject private var store: FreelanceStore
    
    var body: some View {
        let taxRes = FreelanceTaxEngine.computeEstimatedTax(profile: store.profile, taxProfile: store.taxProfile, invoices: store.invoices, receipts: store.receipts)
        let forecast = FreelanceCashflowEngine.computeForecast(invoices: store.invoices, receipts: store.receipts, estimatedTax: taxRes.estimatedTax)
        
        ZStack {
            themeManager.screenBackground(for: colorScheme)
                .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: BuxLayout.section) {
                    
                    // 1. Runway Card
                    VStack(alignment: .leading, spacing: 12) {
                        Text("CASH RUNWAY TRAJECTORY")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.gray)
                        
                        Text(String(format: "%.1f Months", forecast.runwayMonths))
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.orange)
                        
                        Text("Estimated months until zero liquidity based on your \(appSettingsManager.format(forecast.historicalBurnRate)) monthly burn rate.")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                    .padding(BuxLayout.section)
                    .background(colorScheme == .dark ? Color(red: 24/255, green: 26/255, blue: 32/255) : .white)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .buxCardOutline(themeManager: themeManager, colorScheme: colorScheme, cornerRadius: 24)
                    
                    // 2. Survival Mode Required Income
                    VStack(alignment: .leading, spacing: 12) {
                        Text("SURVIVAL MODE TARGET")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.gray)
                        
                        Text(appSettingsManager.format(forecast.survivalMonthlyIncomeNeeded))
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
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    
    @EnvironmentObject private var store: FreelanceStore
    
    var body: some View {
        let (total, opps) = FreelanceDeductionEngine.computeDeductions(receipts: store.receipts, taxProfile: store.taxProfile)
        
        ZStack {
            themeManager.screenBackground(for: colorScheme)
                .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: BuxLayout.section) {
                    
                    // 1. Total deductions card
                    VStack(alignment: .leading, spacing: 12) {
                        Text("TOTAL ACTIVE WRITE-OFF DEDUCTIONS")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.gray)
                        
                        Text(appSettingsManager.format(total))
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.green)
                    }
                    .padding(BuxLayout.section)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(colorScheme == .dark ? Color(red: 24/255, green: 26/255, blue: 32/255) : .white)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .buxCardOutline(themeManager: themeManager, colorScheme: colorScheme, cornerRadius: 24)
                    
                    // 2. Missed Opportunities Alerts
                    Text("OPTIMIZATION OPPORTUNITIES")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.gray)
                    
                    if opps.isEmpty {
                        Text("No deduction opportunities right now.")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.gray)
                            .padding()
                    } else {
                        ForEach(opps) { opp in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(opp.title)
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(colorScheme == .dark ? .white : .black)
                                    Spacer()
                                    Text("Save \(appSettingsManager.format(opp.estimatedTaxSaving))")
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
