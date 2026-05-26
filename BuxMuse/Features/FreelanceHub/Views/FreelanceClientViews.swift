//
//  FreelanceClientViews.swift
//  BuxMuse
//
//  Premium CRM sandboxes for Client management & calculated health matrices.
//

import SwiftUI

struct FreelanceClientsListView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    
    @EnvironmentObject private var store: FreelanceStore
    @State private var showAddClient = false
    
    var body: some View {
        ZStack {
            themeManager.screenBackground(for: colorScheme)
                .ignoresSafeArea()
            
            if store.clients.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(store.clients) { client in
                        let analysis = FreelanceClientEngine.analyze(client: client, invoices: store.invoices, projects: store.projects, receipts: store.receipts)
                        
                        NavigationLink(destination: FreelanceClientDetailView(client: client).environmentObject(themeManager).environmentObject(appSettingsManager)) {
                            HStack(spacing: 12) {
                                // Health Indicator Dot
                                Circle()
                                    .fill(healthColor(analysis.health.overallScore))
                                    .frame(width: 10, height: 10)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(client.name)
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(colorScheme == .dark ? .white : .black)
                                    
                                    HStack(spacing: 6) {
                                        Text("LTV: \(appSettingsManager.format(analysis.lifetimeValue))")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundColor(.gray)
                                        
                                        Text("•")
                                            .font(.system(size: 10))
                                            .foregroundColor(.gray)
                                        
                                        Text("Reliability: \(Int(analysis.health.reliabilityScore))%")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundColor(.gray)
                                    }
                                }
                                Spacer()
                                
                                if client.isFlaggedForStress {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(.orange)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .listRowBackground(colorScheme == .dark ? Color(red: 24/255, green: 26/255, blue: 32/255) : Color.white)
                    }
                    .onDelete(perform: deleteClient)
                }
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("Clients CRM")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showAddClient = true }) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(themeManager.current.accentColor)
                }
            }
        }
        .sheet(isPresented: $showAddClient) {
            NewClientSheet()
                .environmentObject(themeManager)
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: BuxLayout.section) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 32))
                .foregroundColor(.gray)
            
            Text("No Clients registered yet")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.gray)
            
            Button("Add Client") {
                showAddClient = true
            }
            .buttonStyle(BuxMicroShrinkStyle())
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

struct FreelanceClientDetailView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    
    @EnvironmentObject private var store: FreelanceStore
    
    var client: FreelanceClient
    
    var body: some View {
        let analysis = FreelanceClientEngine.analyze(client: client, invoices: store.invoices, projects: store.projects, receipts: store.receipts)
        
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
                Text("CLIENT HEALTH SCORE")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.gray)
                
                Spacer()
                
                Text("\(Int(analysis.health.overallScore))/100")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(healthColor(analysis.health.overallScore))
            }
            
            // Progress Bar
            ProgressView(value: analysis.health.overallScore, total: 100.0)
                .tint(healthColor(analysis.health.overallScore))
                .scaleEffect(x: 1, y: 1.5, anchor: .center)
            
            HStack(spacing: BuxLayout.section) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Profitability")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                    Text("\(Int(analysis.health.profitabilityScore))%")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                }
                Spacer()
                VStack(alignment: .leading, spacing: 2) {
                    Text("Payment Speed")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                    Text("\(Int(analysis.averagePaymentDelay / 86400)) days")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                }
                Spacer()
                VStack(alignment: .leading, spacing: 2) {
                    Text("Stress Indicator")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                    Text(analysis.health.stressScore > 50 ? "High Risk" : "Normal")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(analysis.health.stressScore > 50 ? .orange : .green)
                }
            }
            .padding(.top, 4)
        }
        .padding(BuxLayout.section)
        .background(colorScheme == .dark ? Color(red: 24/255, green: 26/255, blue: 32/255) : .white)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .buxCardOutline(themeManager: themeManager, colorScheme: colorScheme, cornerRadius: 24)
    }
    
    private var contactDetailsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CONTACT DETAILS")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.gray)
            
            VStack(alignment: .leading, spacing: 8) {
                if !client.email.isEmpty {
                    infoRow(icon: "envelope.fill", label: client.email)
                }
                if !client.phone.isEmpty {
                    infoRow(icon: "phone.fill", label: client.phone)
                }
                if !client.address.isEmpty {
                    infoRow(icon: "mappin.and.ellipse", label: client.address)
                }
                if !client.notes.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Notes")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.gray)
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
        .background(colorScheme == .dark ? Color(red: 24/255, green: 26/255, blue: 32/255) : .white)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .buxCardOutline(themeManager: themeManager, colorScheme: colorScheme, cornerRadius: 24)
    }
    
    private var clientInvoicesCard: some View {
        let clientInvoices = store.invoices.filter { $0.clientId == client.id }
        
        return VStack(alignment: .leading, spacing: 10) {
            Text("INVOICES")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.gray)
            
            if clientInvoices.isEmpty {
                Text("No invoices generated yet.")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            } else {
                ForEach(clientInvoices) { inv in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(inv.invoiceNumber)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(colorScheme == .dark ? .white : .black)
                            Text(formattedDate(inv.issueDate))
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        Text(appSettingsManager.format(inv.total))
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(colorScheme == .dark ? .white : .black)
                        
                        Text(inv.status.rawValue)
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
        .background(colorScheme == .dark ? Color(red: 24/255, green: 26/255, blue: 32/255) : .white)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .buxCardOutline(themeManager: themeManager, colorScheme: colorScheme, cornerRadius: 24)
    }
    
    private var clientProjectsCard: some View {
        let clientProjects = store.projects.filter { $0.clientId == client.id }
        
        return VStack(alignment: .leading, spacing: 10) {
            Text("PROJECTS")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.gray)
            
            if clientProjects.isEmpty {
                Text("No projects logged yet.")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            } else {
                ForEach(clientProjects) { proj in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(proj.name)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(colorScheme == .dark ? .white : .black)
                            Text("\(proj.timeEntries.count) time entries logged")
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        if let rate = proj.hourlyRate {
                            Text("\(appSettingsManager.format(rate))/hr")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(BuxLayout.section)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(colorScheme == .dark ? Color(red: 24/255, green: 26/255, blue: 32/255) : .white)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .buxCardOutline(themeManager: themeManager, colorScheme: colorScheme, cornerRadius: 24)
    }
    
    private func infoRow(icon: String, label: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(themeManager.current.accentColor)
                .frame(width: 16)
            
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(colorScheme == .dark ? .white : .black)
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
