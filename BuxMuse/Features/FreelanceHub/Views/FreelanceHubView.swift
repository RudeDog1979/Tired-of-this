//
//  FreelanceHubView.swift
//  BuxMuse
//
//  Premium on-device command cockpit for self-employed professionals.
//

import SwiftUI

struct FreelanceHubView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @EnvironmentObject private var store: FreelanceStore
    @EnvironmentObject private var freelanceBrain: FreelanceBrain
    @EnvironmentObject private var appDataManager: AppDataManager
    @ObservedObject private var settingsStore = SettingsStore.shared

    @State private var navigateToProfile = false
    @State private var navigateToClients = false
    @State private var navigateToInvoices = false
    @State private var navigateToProjects = false
    @State private var navigateToReceipts = false
    @State private var navigateToTax = false
    @State private var navigateToCashflow = false
    @State private var navigateToDeductions = false
    @State private var navigateToTaxProfile = false
    @State private var navigateToExpenses = false
    @State private var navigateToIncomeTax = false
    @State private var navigateToQuarterly = false
    @State private var navigateToCompliance = false
    @State private var navigateToInvoiceSettings = false

    @State private var showNewInvoice = false
    @State private var showNewClient = false
    @State private var showScanReceipt = false
    @State private var showTimeTracker = false

    private var display: FreelanceHubDisplay {
        freelanceBrain.hubDisplay
    }

    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.screenBackground(for: colorScheme)
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: BuxLayout.section) {
                        FreelanceHeroCard(display: display.hero)

                        if display.isEmpty {
                            FreelanceHubEmptyState()
                        }

                        FreelanceMetricsGrid(display: display.hero)

                        quickActionsSection

                        FreelanceInvoicesSection(display: display.invoicesSummary) { navigateToInvoices = true }
                        FreelanceClientsSection(clients: display.topClients) { navigateToClients = true }
                        FreelanceTaxSection(display: display.taxSummary) { navigateToTax = true }
                        FreelanceCashflowSection(display: display.cashflow) { navigateToCashflow = true }
                        FreelanceProjectsSection(display: display.projectsSummary) { navigateToProjects = true }
                        FreelanceReceiptsSection(display: display.receiptsSummary) { navigateToReceipts = true }
                        FreelanceDeductionsSection(items: display.deductionOpportunities) { navigateToDeductions = true }
                        FreelanceAlertsSection(alerts: display.alerts)

                        navigationListSection

                        Spacer().frame(height: 80)
                    }
                    .padding(.horizontal, BuxLayout.marginHorizontal)
                    .padding(.top, BuxLayout.tight)
                }
            }
            .navigationTitle("Freelance Hub")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Business Profile") { navigateToProfile = true }
                        Button("Tax Profile") { navigateToTaxProfile = true }
                    } label: {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(themeManager.current.accentColor)
                    }
                }
            }
            .sheet(isPresented: $showNewInvoice) {
                FreelanceInvoiceEditorView(invoiceToEdit: nil)
                    .environmentObject(themeManager)
                    .environmentObject(appSettingsManager)
            }
            .sheet(isPresented: $showNewClient) {
                NewClientSheet()
                    .environmentObject(themeManager)
            }
            .sheet(isPresented: $showScanReceipt) {
                FreelanceReceiptScannerView()
                    .environmentObject(themeManager)
                    .environmentObject(appSettingsManager)
            }
            .sheet(isPresented: $showTimeTracker) {
                ActiveTimeTrackerView()
                    .environmentObject(themeManager)
            }
            .navigationDestination(isPresented: $navigateToProfile) {
                FreelanceProfileView()
                    .environmentObject(themeManager)
                    .environmentObject(appSettingsManager)
            }
            .navigationDestination(isPresented: $navigateToTaxProfile) {
                FreelanceTaxReferenceView()
                    .environmentObject(themeManager)
                    .environmentObject(appSettingsManager)
                    .environmentObject(appDataManager)
            }
            .navigationDestination(isPresented: $navigateToClients) {
                FreelanceClientsListView()
                    .environmentObject(themeManager)
                    .environmentObject(appSettingsManager)
            }
            .navigationDestination(isPresented: $navigateToInvoices) {
                FreelanceInvoicesListView()
                    .environmentObject(themeManager)
                    .environmentObject(appSettingsManager)
            }
            .navigationDestination(isPresented: $navigateToProjects) {
                FreelanceProjectsListView()
                    .environmentObject(themeManager)
                    .environmentObject(appSettingsManager)
            }
            .navigationDestination(isPresented: $navigateToReceipts) {
                FreelanceReceiptsListView()
                    .environmentObject(themeManager)
                    .environmentObject(appSettingsManager)
            }
            .navigationDestination(isPresented: $navigateToTax) {
                FreelanceTaxOverviewView()
                    .environmentObject(themeManager)
                    .environmentObject(appSettingsManager)
            }
            .navigationDestination(isPresented: $navigateToCashflow) {
                FreelanceCashflowView()
                    .environmentObject(themeManager)
                    .environmentObject(appSettingsManager)
            }
            .navigationDestination(isPresented: $navigateToDeductions) {
                FreelanceDeductionsView()
                    .environmentObject(themeManager)
                    .environmentObject(appSettingsManager)
            }
            .navigationDestination(isPresented: $navigateToExpenses) {
                FreelanceReceiptsListView()
                    .environmentObject(themeManager)
                    .environmentObject(appSettingsManager)
            }
            .navigationDestination(isPresented: $navigateToIncomeTax) {
                FreelanceIncomeTaxCalculatorView()
                    .environmentObject(themeManager)
                    .environmentObject(appSettingsManager)
            }
            .navigationDestination(isPresented: $navigateToQuarterly) {
                FreelanceQuarterlyTaxView()
                    .environmentObject(themeManager)
                    .environmentObject(appSettingsManager)
            }
            .navigationDestination(isPresented: $navigateToCompliance) {
                FreelanceComplianceAssistantView()
                    .environmentObject(themeManager)
                    .environmentObject(appSettingsManager)
            }
            .navigationDestination(isPresented: $navigateToInvoiceSettings) {
                FreelanceInvoiceSettingsView()
                    .environmentObject(themeManager)
                    .environmentObject(appSettingsManager)
            }
        }
    }

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("QUICK ACTIONS")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.gray)

            HStack(spacing: 8) {
                quickActionButton(title: "New Invoice", icon: "plus.rectangle.fill.on.folder.fill", filled: true) { showNewInvoice = true }
                quickActionButton(title: "Log Time", icon: "stopwatch.fill", filled: false) { showTimeTracker = true }
                quickActionButton(title: "Scan Receipt", icon: "doc.text.viewfinder", filled: false) { showScanReceipt = true }
            }
        }
    }

    private func quickActionButton(title: String, icon: String, filled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 16))
                Text(title).font(.system(size: 10, weight: .bold))
            }
            .foregroundColor(filled ? .white : themeManager.current.accentColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(filled ? themeManager.current.accentColor : themeManager.current.accentColor.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(BuxMicroShrinkStyle())
    }

    private var navigationListSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("MODULE COCKPITS")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.gray)

            VStack(spacing: 0) {
                navRow(title: "Clients CRM", icon: "person.2.fill", color: .blue) { navigateToClients = true }
                Divider().padding(.leading, 44)
                navRow(title: "Invoices Ledger", icon: "doc.text.fill", color: .green) { navigateToInvoices = true }
                Divider().padding(.leading, 44)
                navRow(title: "Projects & Tasks", icon: "folder.fill", color: .purple) { navigateToProjects = true }
                Divider().padding(.leading, 44)
                navRow(title: "Receipts & Expenses", icon: "doc.plaintext.fill", color: .teal) { navigateToExpenses = true }
                Divider().padding(.leading, 44)
                navRow(title: "Income Tax Calculator", icon: "function", color: .mint) { navigateToIncomeTax = true }
                Divider().padding(.leading, 44)
                navRow(title: "Quarterly Tax", icon: "calendar.badge.clock", color: .pink) { navigateToQuarterly = true }
                Divider().padding(.leading, 44)
                navRow(title: "Compliance Assistant", icon: "checkmark.shield.fill", color: .cyan) { navigateToCompliance = true }
                Divider().padding(.leading, 44)
                navRow(title: "Tax Overview", icon: "percent", color: .red) { navigateToTax = true }
                Divider().padding(.leading, 44)
                navRow(title: "Tax Profile", icon: "doc.text.fill", color: .indigo) { navigateToTaxProfile = true }
                Divider().padding(.leading, 44)
                navRow(title: "Invoice Settings", icon: "gearshape.fill", color: .gray) { navigateToInvoiceSettings = true }
                Divider().padding(.leading, 44)
                navRow(title: "Cashflow Runway", icon: "chart.line.uptrend.xyaxis", color: .orange) { navigateToCashflow = true }
                Divider().padding(.leading, 44)
                navRow(title: "Deductions", icon: "lightbulb.fill", color: .yellow) { navigateToDeductions = true }
            }
            .background(colorScheme == .dark ? Color(red: 24/255, green: 26/255, blue: 32/255) : .white)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .buxCardOutline(themeManager: themeManager, colorScheme: colorScheme, cornerRadius: 20)
        }
    }

    private func navRow(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(color.opacity(0.12))
                        .frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(color)
                }
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(colorScheme == .dark ? .white : Color(red: 26/255, green: 28/255, blue: 32/255))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.gray.opacity(0.6))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(BuxmationPressCardStyle())
    }
}

// MARK: - New Client Sheet

struct NewClientSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var store: FreelanceStore

    @State private var name = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var address = ""
    @State private var rate = ""
    @State private var terms = "14"

    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.screenBackground(for: colorScheme).ignoresSafeArea()
                Form {
                    Section("Client Info") {
                        TextField("Name", text: $name)
                        TextField("Email", text: $email).keyboardType(.emailAddress)
                        TextField("Phone", text: $phone).keyboardType(.phonePad)
                        TextField("Address", text: $address)
                    }
                    Section("Contract settings") {
                        TextField("Default Hourly Rate", text: $rate).keyboardType(.decimalPad)
                        Picker("Payment Terms (Days)", selection: $terms) {
                            Text("Due on Receipt").tag("0")
                            Text("7 Days").tag("7")
                            Text("14 Days").tag("14")
                            Text("30 Days").tag("30")
                            Text("60 Days").tag("60")
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("New Client")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        store.addClient(FreelanceClient(
                            name: name,
                            email: email,
                            phone: phone,
                            address: address,
                            defaultRate: Decimal(string: rate),
                            paymentTermsDays: Int(terms)
                        ))
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}
