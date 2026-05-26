//
//  FreelanceProjectViews.swift
//  BuxMuse
//
//  Project organizers outfitted with stopwatch indicators and live margins calculations.
//

import SwiftUI

struct FreelanceProjectsListView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    
    @EnvironmentObject private var store: FreelanceStore
    @State private var showCreateProject = false
    
    var body: some View {
        ZStack {
            themeManager.screenBackground(for: colorScheme)
                .ignoresSafeArea()
            
            if store.projects.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(store.projects) { project in
                        let client = store.clients.first { $0.id == project.clientId }
                        let analysis = FreelanceProjectEngine.analyzeProject(project: project, receipts: store.receipts)
                        
                        NavigationLink(destination: FreelanceProjectDetailView(project: project).environmentObject(themeManager).environmentObject(appSettingsManager)) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(project.name)
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(colorScheme == .dark ? .white : .black)
                                    
                                    Text(client?.name ?? "Independent Project")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(.gray)
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text(appSettingsManager.format(analysis.projectedRevenue))
                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                        .foregroundColor(colorScheme == .dark ? .white : .black)
                                    
                                    Text(String(format: "%.1f hrs", analysis.totalTime / 3600))
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.gray)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .listRowBackground(colorScheme == .dark ? Color(red: 24/255, green: 26/255, blue: 32/255) : Color.white)
                    }
                    .onDelete(perform: deleteProject)
                }
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("Projects & Tasks")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showCreateProject = true }) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(themeManager.current.accentColor)
                }
            }
        }
        .sheet(isPresented: $showCreateProject) {
            NewProjectSheet()
                .environmentObject(themeManager)
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: BuxLayout.section) {
            Image(systemName: "folder.fill")
                .font(.system(size: 32))
                .foregroundColor(.gray)
            
            Text("No projects registered yet")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.gray)
            
            Button("Add Project") {
                showCreateProject = true
            }
            .buttonStyle(BuxMicroShrinkStyle())
        }
    }
    
    private func deleteProject(at offsets: IndexSet) {
        let ids = offsets.map { store.projects[$0].id }
        ids.forEach { store.deleteProject(id: $0) }
    }
}

// MARK: - Project Detail View

struct FreelanceProjectDetailView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    
    @EnvironmentObject private var store: FreelanceStore
    
    var project: FreelanceProject
    
    var body: some View {
        let analysis = FreelanceProjectEngine.analyzeProject(project: project, receipts: store.receipts)
        
        ZStack {
            themeManager.screenBackground(for: colorScheme)
                .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: BuxLayout.section) {
                    
                    // Overrun Risk banner
                    if analysis.isOverrunRisk {
                        HStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text("Budget Overrun Risk. Hours spent exceed contract benchmarks.")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.red)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.red.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    
                    // 1. Margin & Financials Cards
                    financialMarginsSection(analysis: analysis)
                    
                    // 2. Time entries list
                    timeEntriesSection
                    
                    // 3. Project Expenses
                    expensesSection(projectExpenses: analysis.projectedExpenses)
                }
                .padding(.horizontal, BuxLayout.marginHorizontal)
                .padding(.top, BuxLayout.tight)
            }
        }
        .navigationTitle(project.name)
    }
    
    // MARK: - Subviews
    
    private func financialMarginsSection(analysis: (totalTime: TimeInterval, billableTime: TimeInterval, projectedRevenue: Decimal, projectedExpenses: Decimal, projectedProfit: Decimal, effectiveHourlyRate: Decimal, isOverrunRisk: Bool)) -> some View {
        VStack(alignment: .leading, spacing: BuxLayout.tight) {
            Text("FINANCIAL MATRIX")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.gray)
            
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("REVENUE")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.gray)
                    Text(appSettingsManager.format(analysis.projectedRevenue))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.green)
                }
                Spacer()
                VStack(alignment: .leading, spacing: 4) {
                    Text("EXPENSES")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.gray)
                    Text(appSettingsManager.format(analysis.projectedExpenses))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.red)
                }
                Spacer()
                VStack(alignment: .leading, spacing: 4) {
                    Text("PROFIT")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.gray)
                    Text(appSettingsManager.format(analysis.projectedProfit))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(themeManager.current.accentColor)
                }
            }
            .padding(.vertical, 8)
            
            Divider()
            
            HStack {
                Text("Effective hourly rate:")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                Spacer()
                Text("\(appSettingsManager.format(analysis.effectiveHourlyRate))/hr")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(colorScheme == .dark ? .white : .black)
            }
        }
        .padding(BuxLayout.section)
        .background(colorScheme == .dark ? Color(red: 24/255, green: 26/255, blue: 32/255) : .white)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .buxCardOutline(themeManager: themeManager, colorScheme: colorScheme, cornerRadius: 24)
    }
    
    private var timeEntriesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("TIME ENTRIES LOG")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.gray)
            
            if project.timeEntries.isEmpty {
                Text("No time entries logged yet.")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            } else {
                ForEach(project.timeEntries) { entry in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.notes.isEmpty ? "Consulting work" : entry.notes)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(colorScheme == .dark ? .white : .black)
                            Text(formattedDate(entry.startTime))
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        Text(String(format: "%.1f hrs", entry.duration / 3600))
                            .font(.system(size: 13, weight: .semibold))
                        
                        Text(entry.isBillable ? "Billable" : "Admin")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(entry.isBillable ? .green : .gray)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background((entry.isBillable ? Color.green : Color.gray).opacity(0.12))
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
    
    private func expensesSection(projectExpenses: Decimal) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("LINKED EXPENSES")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.gray)
            
            HStack {
                Text("Total project direct cost:")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                Spacer()
                Text(appSettingsManager.format(projectExpenses))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.red)
            }
        }
        .padding(BuxLayout.section)
        .background(colorScheme == .dark ? Color(red: 24/255, green: 26/255, blue: 32/255) : .white)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .buxCardOutline(themeManager: themeManager, colorScheme: colorScheme, cornerRadius: 24)
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - stopwatch active tracking

struct ActiveTimeTrackerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var store: FreelanceStore
    
    @State private var selectedProjectId: UUID = UUID()
    @State private var isRunning = false
    @State private var elapsedTime = 0.0
    @State private var timer: Timer? = nil
    @State private var notes = ""
    @State private var isBillable = true
    
    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.screenBackground(for: colorScheme)
                    .ignoresSafeArea()
                
                VStack(spacing: 30) {
                    Picker("Project", selection: $selectedProjectId) {
                        if store.projects.isEmpty {
                            Text("Add Projects first").tag(UUID())
                        } else {
                            ForEach(store.projects) { p in
                                Text(p.name).tag(p.id)
                            }
                        }
                    }
                    .pickerStyle(.menu)
                    .padding()
                    .background(colorScheme == .dark ? Color(red: 24/255, green: 26/255, blue: 32/255) : .white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)
                    
                    // Big stopwatch timer
                    VStack(spacing: 10) {
                        Text(timeString(from: elapsedTime))
                            .font(.system(size: 64, weight: .bold, design: .monospaced))
                            .foregroundColor(isRunning ? themeManager.current.accentColor : .gray)
                        
                        Text("ACTIVE STOPWATCH")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.gray)
                    }
                    .padding(40)
                    .background(Circle().fill(colorScheme == .dark ? Color(red: 24/255, green: 26/255, blue: 32/255) : .white).shadow(radius: 10))
                    
                    // Form fields
                    VStack(alignment: .leading, spacing: 12) {
                        TextField("What are you working on?", text: $notes)
                            .padding()
                            .background(colorScheme == .dark ? Color(red: 24/255, green: 26/255, blue: 32/255) : .white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        Toggle("Billable Hours", isOn: $isBillable)
                            .padding()
                            .background(colorScheme == .dark ? Color(red: 24/255, green: 26/255, blue: 32/255) : .white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal)
                    
                    // Buttons
                    HStack(spacing: 16) {
                        Button(action: toggleTimer) {
                            Text(isRunning ? "Stop" : "Start")
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(isRunning ? Color.red : themeManager.current.accentColor)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        .buttonStyle(BuxMicroShrinkStyle())
                        
                        if elapsedTime > 0 && !isRunning {
                            Button(action: saveTimeLog) {
                                Text("Log Hours")
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.green)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                            }
                            .buttonStyle(BuxMicroShrinkStyle())
                        }
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                }
            }
            .navigationTitle("Time Tracker")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        timer?.invalidate()
                        dismiss()
                    }
                }
            }
            .onAppear {
                selectedProjectId = store.projects.first?.id ?? UUID()
            }
        }
    }
    
    private func toggleTimer() {
        if isRunning {
            timer?.invalidate()
            isRunning = false
        } else {
            isRunning = true
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                elapsedTime += 1.0
            }
        }
    }
    
    private func saveTimeLog() {
        guard var project = store.projects.first(where: { $0.id == selectedProjectId }) else { return }
        let now = Date()
        let start = now.addingTimeInterval(-elapsedTime)
        let entry = FreelanceTimeEntry(projectId: selectedProjectId, startTime: start, endTime: now, notes: notes, isBillable: isBillable)
        project.timeEntries.append(entry)
        store.updateProject(project)
        dismiss()
    }
    
    private func timeString(from interval: TimeInterval) -> String {
        let hrs = Int(interval) / 3600
        let mins = (Int(interval) % 3600) / 60
        let secs = Int(interval) % 60
        return String(format: "%02d:%02d:%02d", hrs, mins, secs)
    }
}

// MARK: - Supporting Sheets

struct NewProjectSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var store: FreelanceStore
    
    @State private var name = ""
    @State private var clientId: UUID = UUID()
    @State private var hourlyRate = ""
    @State private var fixedFee = ""
    @State private var notes = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.screenBackground(for: colorScheme)
                    .ignoresSafeArea()
                
                Form {
                    Section("Project Details") {
                        TextField("Project Name", text: $name)
                        Picker("Client", selection: $clientId) {
                            if store.clients.isEmpty {
                                Text("Independent Project").tag(UUID())
                            } else {
                                ForEach(store.clients) { c in
                                    Text(c.name).tag(c.id)
                                }
                            }
                        }
                    }
                    
                    Section("Contract details") {
                        TextField("Hourly Rate", text: $hourlyRate)
                            .keyboardType(.decimalPad)
                        TextField("Fixed Fee Arrangement (optional)", text: $fixedFee)
                            .keyboardType(.decimalPad)
                    }
                    
                    Section("Internal Notes") {
                        TextField("Notes", text: $notes)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("New Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        let proj = FreelanceProject(
                            name: name,
                            clientId: clientId == UUID() ? nil : clientId,
                            hourlyRate: Decimal(string: hourlyRate),
                            fixedFee: Decimal(string: fixedFee),
                            notes: notes
                        )
                        store.addProject(proj)
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
            .onAppear {
                clientId = store.clients.first?.id ?? UUID()
            }
        }
    }
}
