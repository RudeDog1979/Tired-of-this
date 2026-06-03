//
//  StudioClientViews.swift
//  BuxMuse
//
//  Premium CRM sandboxes for Client management & calculated health matrices.
//

import SwiftUI

struct StudioClientsListView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    
    @EnvironmentObject private var store: StudioStore
    @State private var showAddClient = false
    
    var body: some View {
        StudioThemedListBackdrop {
            if store.clients.isEmpty {
                emptyState
            } else {
                clientList
            }
        }
        .buxCatalogNavigationTitle("Clients CRM")
        .navigationBarTitleDisplayMode(.large)
        .buxRootNavigationChrome()
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                BuxToolbarButton(
                    systemName: "plus",
                    accessibilityLabel: "Add client",
                    action: { showAddClient = true }
                )
            }
        }
        .sheet(isPresented: $showAddClient) {
            NewClientSheet()
                .environmentObject(themeManager)
                .environmentObject(appSettingsManager)
                .buxStudioSheetContent()
        }
    }

    private var clientList: some View {
        List {
            ForEach(store.clients) { client in
                let analysis = StudioClientEngine.analyze(
                    client: client,
                    invoices: store.invoices,
                    projects: store.projects,
                    receipts: store.receipts
                )

                NavigationLink(
                    destination: StudioClientDetailView(client: client)
                        .environmentObject(themeManager)
                        .environmentObject(appSettingsManager)
                ) {
                    clientRowCard(client: client, lifetimeValue: analysis.lifetimeValue, health: analysis.health)
                }
                .studioThemedListRowChrome()
            }
            .onDelete(perform: deleteClient)
        }
        .studioThemedListRows()
    }

    private func clientRowCard(
        client: StudioClient,
        lifetimeValue: Decimal,
        health: ClientHealthScore
    ) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(healthColor(health.overallScore))
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 4) {
                Text(client.name)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(themeManager.labelPrimary(for: colorScheme))

                HStack(spacing: 6) {
                    Text(
                        BuxLocalizedString.format(
                            "LTV: %@",
                            locale: appSettingsManager.interfaceLocale,
                            appSettingsManager.format(lifetimeValue)
                        )
                    )
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(themeManager.labelSecondary(for: colorScheme))

                    Text("•")
                        .font(.system(size: 10))
                        .foregroundStyle(themeManager.labelTertiary(for: colorScheme))

                    Text(
                        BuxLocalizedString.format(
                            "Reliability: %lld%%",
                            locale: appSettingsManager.interfaceLocale,
                            Int(health.reliabilityScore)
                        )
                    )
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(themeManager.labelSecondary(for: colorScheme))
                }
            }

            Spacer()

            if client.isFlaggedForStress {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.orange)
            }
        }
        .studioThemedListRowCard()
    }
    
    private var emptyState: some View {
        VStack(spacing: BuxLayout.section) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 32))
                .buxLabelSecondary()
            
            BuxCatalogDynamicText(key: "No Clients registered yet")
                .font(.system(size: 14, weight: .semibold))
                .buxLabelSecondary()
            
            BuxButton(
                title: "Add Client",
                systemImage: "plus.circle.fill",
                role: .primary,
                expands: false,
                action: { showAddClient = true }
            )
        }
    }
    
    private func deleteClient(at offsets: IndexSet) {
        let ids = offsets.map { store.clients[$0].id }
        ids.forEach { store.deleteClient(id: $0) }
    }
    
    private func healthColor(_ score: Double) -> Color {
        if score >= 80 { return .green }
        if score >= 50 { return .orange }
        return .red
    }
}

// MARK: - Client Detail View

struct StudioClientDetailView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    
    @EnvironmentObject private var store: StudioStore
    
    var client: StudioClient
    
    var body: some View {
        let analysis = StudioClientEngine.analyze(client: client, invoices: store.invoices, projects: store.projects, receipts: store.receipts)
        
        ZStack {
            themeManager.screenBackground(for: colorScheme)
                .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: BuxLayout.section) {
                    
                    // 1. Health Cockpit Header
                    healthCockpitHeader(analysis: analysis)
                    
                    // 2. Client Details Section
                    contactDetailsCard
                    
                    // 3. Client Invoices Section
                    clientInvoicesCard
                    
                    // 4. Client Projects Section
                    clientProjectsCard
                }
                .padding(.horizontal, BuxLayout.marginHorizontal)
                .padding(.top, BuxLayout.tight)
            }
        }
        .navigationTitle(client.name)
    }
    
    // MARK: - Subviews
    
    private func healthCockpitHeader(analysis: (lifetimeValue: Decimal, averagePaymentDelay: TimeInterval, health: ClientHealthScore)) -> some View {
        VStack(alignment: .leading, spacing: BuxLayout.tight) {
            HStack {
                BuxCatalogDynamicText(key: "CLIENT HEALTH SCORE")
                    .font(.system(size: 11, weight: .bold))
                    .buxLabelSecondary()
                
                Spacer()
                
                Text(
                    BuxLocalizedString.format(
                        "%lld/100",
                        locale: appSettingsManager.interfaceLocale,
                        Int(analysis.health.overallScore)
                    )
                )
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(healthColor(analysis.health.overallScore))
            }
            
            // Progress Bar
            ProgressView(value: analysis.health.overallScore, total: 100.0)
                .tint(healthColor(analysis.health.overallScore))
                .scaleEffect(x: 1, y: 1.5, anchor: .center)
            
            HStack(spacing: BuxLayout.section) {
                VStack(alignment: .leading, spacing: 2) {
                    BuxCatalogDynamicText(key: "Profitability")
                        .font(.system(size: 11))
                        .buxLabelSecondary()
                    Text(
                        BuxLocalizedString.format(
                            "%lld%%",
                            locale: appSettingsManager.interfaceLocale,
                            Int(analysis.health.profitabilityScore)
                        )
                    )
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                }
                Spacer()
                VStack(alignment: .leading, spacing: 2) {
                    BuxCatalogDynamicText(key: "Payment Speed")
                        .font(.system(size: 11))
                        .buxLabelSecondary()
                    Text(
                        BuxLocalizedString.format(
                            "%lld days",
                            locale: appSettingsManager.interfaceLocale,
                            Int(analysis.averagePaymentDelay / 86400)
                        )
                    )
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                }
                Spacer()
                VStack(alignment: .leading, spacing: 2) {
                    BuxCatalogDynamicText(key: "Stress Indicator")
                        .font(.system(size: 11))
                        .buxLabelSecondary()
                    Text(analysis.health.stressScore > 50 ? "High Risk" : "Normal")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(analysis.health.stressScore > 50 ? .orange : .green)
                }
            }
            .padding(.top, 4)
        }
        .padding(BuxLayout.section)
        .studioThemedCardChrome(cornerRadius: 24)
    }
    
    private var contactDetailsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            BuxCatalogDynamicText(key: "CONTACT DETAILS")
                .font(.system(size: 11, weight: .bold))
                .buxLabelSecondary()
            
            VStack(alignment: .leading, spacing: 8) {
                if !client.email.isEmpty {
                    infoRow(icon: "envelope.fill", label: client.email)
                }
                if !client.phone.isEmpty {
                    infoRow(icon: "phone.fill", label: client.phone)
                }
                ForEach(client.resolvedPartyDetails().formattedContactLines, id: \.self) { line in
                    infoRow(icon: "mappin.and.ellipse", label: line)
                }
                if !client.notes.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        BuxCatalogDynamicText(key: "Notes")
                            .font(.system(size: 10, weight: .bold))
                            .buxLabelSecondary()
                        Text(client.notes)
                            .font(.system(size: 13))
                            .foregroundColor(colorScheme == .dark ? .white.opacity(0.8) : .black.opacity(0.8))
                    }
                    .padding(.top, 4)
                }
            }
        }
        .padding(BuxLayout.section)
        .frame(maxWidth: .infinity, alignment: .leading)
        .studioThemedCardChrome(cornerRadius: 24)
    }
    
    private var clientInvoicesCard: some View {
        let clientInvoices = store.invoices.filter { $0.clientId == client.id }
        
        return VStack(alignment: .leading, spacing: 10) {
            BuxCatalogDynamicText(key: "INVOICES")
                .font(.system(size: 11, weight: .bold))
                .buxLabelSecondary()
            
            if clientInvoices.isEmpty {
                BuxCatalogDynamicText(key: "No invoices generated yet.")
                    .font(.system(size: 12))
                    .buxLabelSecondary()
            } else {
                ForEach(clientInvoices) { inv in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(inv.invoiceNumber)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                            Text(formattedDate(inv.issueDate))
                                .font(.system(size: 11))
                                .buxLabelSecondary()
                        }
                        Spacer()
                        Text(appSettingsManager.format(inv.total))
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                        
                        Text(inv.status.catalogLabel(locale: appSettingsManager.interfaceLocale))
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(statusColor(inv.status))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(statusColor(inv.status).opacity(0.12))
                            .clipShape(Capsule())
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(BuxLayout.section)
        .frame(maxWidth: .infinity, alignment: .leading)
        .studioThemedCardChrome(cornerRadius: 24)
    }
    
    private var clientProjectsCard: some View {
        let clientProjects = store.projects.filter { $0.clientId == client.id }
        
        return VStack(alignment: .leading, spacing: 10) {
            Text("PROJECTS")
                .font(.system(size: 11, weight: .bold))
                .buxLabelSecondary()
            
            if clientProjects.isEmpty {
                BuxCatalogDynamicText(key: "No projects logged yet.")
                    .font(.system(size: 12))
                    .buxLabelSecondary()
            } else {
                ForEach(clientProjects) { proj in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(proj.name)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                            Text(
                                BuxLocalizedString.format(
                                    "%lld time entries logged",
                                    locale: appSettingsManager.interfaceLocale,
                                    proj.timeEntries.count
                                )
                            )
                                .font(.system(size: 11))
                                .buxLabelSecondary()
                        }
                        Spacer()
                        if let rate = proj.hourlyRate {
                            Text(
                                BuxLocalizedString.format(
                                    "%@/hr",
                                    locale: appSettingsManager.interfaceLocale,
                                    appSettingsManager.format(rate)
                                )
                            )
                                .font(.system(size: 11, weight: .semibold))
                                .buxLabelSecondary()
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(BuxLayout.section)
        .frame(maxWidth: .infinity, alignment: .leading)
        .studioThemedCardChrome(cornerRadius: 24)
    }
    
    private func infoRow(icon: String, label: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(themeManager.current.accentColor)
                .frame(width: 16)
            
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(themeManager.labelPrimary(for: colorScheme))
        }
    }
    
    private func healthColor(_ score: Double) -> Color {
        if score >= 80 { return .green }
        if score >= 50 { return .orange }
        return .red
    }
    
    private func statusColor(_ status: InvoiceStatus) -> Color {
        switch status {
        case .paid: return .green
        case .sent: return .blue
        case .overdue: return .red
        case .cancelled: return .gray
        case .draft: return .orange
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}
