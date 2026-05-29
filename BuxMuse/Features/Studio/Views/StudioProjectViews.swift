//
//  StudioProjectViews.swift
//  BuxMuse
//
//  Project organizers outfitted with stopwatch indicators and live margins calculations.
//

import Combine
import SwiftUI

struct StudioProjectsListView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    
    @EnvironmentObject private var store: StudioStore
    @State private var showCreateProject = false
    
    var body: some View {
        StudioThemedListBackdrop {
            if store.projects.isEmpty {
                emptyState
            } else {
                projectList
            }
        }
        .navigationTitle("Projects & Tasks")
        .navigationBarTitleDisplayMode(.large)
        .buxRootNavigationChrome()
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
                .buxThemedSheetContent()
        }
    }

    private var projectList: some View {
        List {
            ForEach(store.projects) { project in
                let client = store.clients.first { $0.id == project.clientId }
                let analysis = StudioProjectEngine.analyzeProject(project: project, receipts: store.receipts)

                NavigationLink(
                    destination: StudioProjectDetailView(project: project)
                        .environmentObject(themeManager)
                        .environmentObject(appSettingsManager)
                ) {
                    projectRowCard(
                        project: project,
                        clientName: client?.name,
                        projectedRevenue: analysis.projectedRevenue,
                        totalTime: analysis.totalTime
                    )
                }
                .studioThemedListRowChrome()
            }
            .onDelete(perform: deleteProject)
        }
        .studioThemedListRows()
    }

    private func projectRowCard(
        project: StudioProject,
        clientName: String?,
        projectedRevenue: Decimal,
        totalTime: TimeInterval
    ) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(project.name)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(themeManager.labelPrimary(for: colorScheme))

                Text(clientName ?? "Independent Project")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(themeManager.labelSecondary(for: colorScheme))
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 6) {
                Text(appSettingsManager.format(projectedRevenue))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(themeManager.labelPrimary(for: colorScheme))

                Text(String(format: "%.1f hrs", totalTime / 3600))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(themeManager.labelSecondary(for: colorScheme))
            }
        }
        .studioThemedListRowCard()
    }
    
    private var emptyState: some View {
        VStack(spacing: BuxLayout.section) {
            Image(systemName: "folder.fill")
                .font(.system(size: 32))
                .buxLabelSecondary()
            
            Text("No projects registered yet")
                .font(.system(size: 14, weight: .semibold))
                .buxLabelSecondary()
            
            Button("Add Project") {
                showCreateProject = true
            }
            .buttonStyle(BuxPressFeedbackStyle())
        }
    }
    
    private func deleteProject(at offsets: IndexSet) {
        let ids = offsets.map { store.projects[$0].id }
        ids.forEach { store.deleteProject(id: $0) }
    }
}

// MARK: - Project Detail View

struct StudioProjectDetailView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    
    @EnvironmentObject private var store: StudioStore
    
    var project: StudioProject
    
    var body: some View {
        let analysis = StudioProjectEngine.analyzeProject(project: project, receipts: store.receipts)
        
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
                .buxLabelSecondary()
            
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("REVENUE")
                        .font(.system(size: 9, weight: .semibold))
                        .buxLabelSecondary()
                    Text(appSettingsManager.format(analysis.projectedRevenue))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.green)
                }
                Spacer()
                VStack(alignment: .leading, spacing: 4) {
                    Text("EXPENSES")
                        .font(.system(size: 9, weight: .semibold))
                        .buxLabelSecondary()
                    Text(appSettingsManager.format(analysis.projectedExpenses))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.red)
                }
                Spacer()
                VStack(alignment: .leading, spacing: 4) {
                    Text("PROFIT")
                        .font(.system(size: 9, weight: .semibold))
                        .buxLabelSecondary()
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
                    .buxLabelSecondary()
                Spacer()
                Text("\(appSettingsManager.format(analysis.effectiveHourlyRate))/hr")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(themeManager.labelPrimary(for: colorScheme))
            }
        }
        .padding(BuxLayout.section)
        .studioThemedCardChrome(cornerRadius: 24)
    }
    
    private var timeEntriesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("TIME ENTRIES LOG")
                .font(.system(size: 11, weight: .bold))
                .buxLabelSecondary()
            
            if project.timeEntries.isEmpty {
                Text("No time entries logged yet.")
                    .font(.system(size: 12))
                    .buxLabelSecondary()
            } else {
                ForEach(project.timeEntries) { entry in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.notes.isEmpty ? "Consulting work" : entry.notes)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                            Text(formattedDate(entry.startTime))
                                .font(.system(size: 11))
                                .buxLabelSecondary()
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
        .studioThemedCardChrome(cornerRadius: 24)
    }
    
    private func expensesSection(projectExpenses: Decimal) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("LINKED EXPENSES")
                .font(.system(size: 11, weight: .bold))
                .buxLabelSecondary()
            
            HStack {
                Text("Total project direct cost:")
                    .font(.system(size: 12))
                    .buxLabelSecondary()
                Spacer()
                Text(appSettingsManager.format(projectExpenses))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.red)
            }
        }
        .padding(BuxLayout.section)
        .studioThemedCardChrome(cornerRadius: 24)
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Stopwatch time tracker (Studio quick action)

struct ActiveTimeTrackerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var store: StudioStore
    @ObservedObject private var timer = StudioTimerController.shared

    @State private var selectedProjectId: UUID?
    @State private var displayElapsed: TimeInterval = 0
    @State private var notes = ""
    @State private var isBillable = true
    @State private var laps: [TimeInterval] = []
    @State private var hasJobEstimate = false
    @State private var estimateHours = 1
    @State private var estimateMinutes = 0
    @State private var showFinishEarlyConfirm = false
    @FocusState private var notesFieldFocused: Bool

    private var accent: Color { themeManager.current.accentColor }
    private var isRunning: Bool { timer.isRunning }
    private var estimateLocked: Bool { timer.estimateLocked }
    private var sessionProgress: Double { timer.session?.progress() ?? 0 }
    private var resolvedProjectId: UUID? {
        guard !store.projects.isEmpty else { return nil }
        if let selectedProjectId, store.projects.contains(where: { $0.id == selectedProjectId }) {
            return selectedProjectId
        }
        return store.projects.first?.id
    }

    private var canLog: Bool {
        displayElapsed > 0 && resolvedProjectId != nil
    }

    private var showEstimateStartHint: Bool {
        hasJobEstimate && !estimateLocked && displayElapsed == 0
    }

    private var canFinishEarly: Bool {
        guard estimateLocked, hasJobEstimate, displayElapsed > 0, resolvedProjectId != nil else { return false }
        return sessionProgress < 1.0
    }

    private var shouldShowExtendTime: Bool {
        guard estimateLocked, hasJobEstimate else { return false }
        return sessionProgress >= 1.0 || timer.session?.isOvertime == true
    }

    private var estimateDuration: TimeInterval {
        TimeInterval(estimateHours * 3600 + estimateMinutes * 60)
    }

    private var lockedGoalLabel: String {
        let duration = timer.session?.estimatedDuration ?? estimateDuration
        return StudioTimerSession.formattedDuration(duration)
    }

    private var stopwatchTimerAnchor: Date? {
        guard let session = timer.session, session.isRunning, let segmentStart = session.segmentStart else {
            return nil
        }
        return segmentStart.addingTimeInterval(-session.accumulated)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.screenBackground(for: colorScheme)
                    .ignoresSafeArea()
                BuxThemedBackdrop()
                    .ignoresSafeArea()
                    .opacity(0.55)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: BuxLayout.section) {
                        projectPicker
                        jobNameSection

                        BuxStopwatchFace(
                            elapsed: displayElapsed,
                            isRunning: isRunning,
                            timerAnchor: stopwatchTimerAnchor,
                            accent: accent
                        )
                        .padding(.vertical, 8)

                        controlRow

                        jobEstimateSection

                        finishActionsSection

                        if !laps.isEmpty {
                            lapsList
                        }

                        billableSection

                        Spacer().frame(height: BuxTokens.block)
                    }
                    .padding(.top, BuxLayout.tight)
                }
                .buxScrollContentMargins()
                .scrollDismissesKeyboard(.interactively)
            }
            .contentShape(Rectangle())
            .simultaneousGesture(
                TapGesture().onEnded {
                    dismissNotesKeyboard()
                }
            )
            .navigationTitle("Log Time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismissNotesKeyboard()
                        syncDraftToController()
                        dismiss()
                    }
                }
            }
            .onAppear {
                timer.attach(store: store)
                hydrateFromController()
                if scenePhase == .active {
                    timer.syncLiveActivityOnForeground()
                }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    refreshDisplayElapsed()
                    timer.syncLiveActivityOnForeground()
                }
            }
            .task(id: scenePhase) {
                guard scenePhase == .active else { return }
                refreshDisplayElapsed()
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(1))
                    guard !Task.isCancelled else { return }
                    refreshDisplayElapsed()
                    if timer.session?.isRunning == true {
                        timer.evaluateJobMilestones()
                    }
                }
            }
            .onChange(of: selectedProjectId) { _, id in
                guard let id, store.projects.contains(where: { $0.id == id }) else { return }
                timer.updateProjectId(id)
            }
            .onChange(of: store.projects.map(\.id)) { _, _ in
                reconcileProjectSelection()
            }
            .onChange(of: notes) { _, value in
                timer.updateNotes(value)
            }
            .onChange(of: isBillable) { _, value in
                timer.updateBillable(value)
            }
            .onChange(of: hasJobEstimate) { _, enabled in
                guard !estimateLocked else { return }
                timer.setJobEstimate(enabled: enabled, duration: estimateDuration)
            }
            .onChange(of: estimateHours) { _, _ in
                guard !estimateLocked else { return }
                timer.setJobEstimate(enabled: hasJobEstimate, duration: estimateDuration)
            }
            .onChange(of: estimateMinutes) { _, _ in
                guard !estimateLocked else { return }
                timer.setJobEstimate(enabled: hasJobEstimate, duration: estimateDuration)
            }
            .confirmationDialog(
                "Finished early?",
                isPresented: $showFinishEarlyConfirm,
                titleVisibility: .visible
            ) {
                Button("Log \(StudioTimerSession.formattedElapsed(displayElapsed, style: .hub)) and stop") {
                    finishEarlyAndDismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Save your time entry and end the Live Activity.")
            }
        }
        .tint(accent)
    }

    private var projectPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("PROJECT")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(themeManager.labelSecondary(for: colorScheme))
                .kerning(1)

            if store.projects.isEmpty {
                Text("Add a project in Studio first")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(themeManager.labelSecondary(for: colorScheme))
            } else {
                Picker("Project", selection: projectSelectionBinding) {
                    ForEach(store.projects) { project in
                        Text(project.name).tag(project.id)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(BuxLayout.section)
        .studioThemedCardChrome(cornerRadius: 16)
        .padding(.horizontal, BuxLayout.marginHorizontal)
    }

    private var jobNameSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("JOB NAME")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(themeManager.labelSecondary(for: colorScheme))
                .kerning(1)

            TextField("What are you working on?", text: $notes, axis: .vertical)
                .lineLimit(1...3)
                .focused($notesFieldFocused)
                .submitLabel(.done)
                .onSubmit { dismissNotesKeyboard() }
                .font(.system(size: 15, weight: .medium))
        }
        .padding(BuxLayout.section)
        .studioThemedCardChrome(cornerRadius: 16)
        .padding(.horizontal, BuxLayout.marginHorizontal)
    }

    private var controlRow: some View {
        HStack(spacing: BuxTokens.tight) {
            BuxActionButton(
                title: "Reset",
                systemImage: "arrow.counterclockwise",
                role: .secondary,
                accent: accent,
                expands: true,
                isEnabled: displayElapsed > 0 || isRunning || !laps.isEmpty,
                action: resetStopwatch
            )

            BuxActionButton(
                title: isRunning ? "Pause" : "Start",
                systemImage: isRunning ? "pause.fill" : "play.fill",
                role: .primary,
                accent: isRunning ? .red : accent,
                expands: true,
                isEnabled: !store.projects.isEmpty,
                action: toggleTimer
            )

            BuxActionButton(
                title: "Lap",
                systemImage: "flag.fill",
                role: .tinted(accent),
                accent: accent,
                expands: true,
                isEnabled: isRunning && displayElapsed > 0,
                action: recordLap
            )
        }
        .padding(.horizontal, BuxLayout.marginHorizontal)
    }

    private var lapsList: some View {
        VStack(alignment: .leading, spacing: BuxTokens.tight) {
            Text("LAPS")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(themeManager.labelSecondary(for: colorScheme))
                .kerning(1)

            ForEach(Array(laps.enumerated().reversed()), id: \.offset) { index, lap in
                HStack {
                    Text("Lap \(laps.count - index)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(themeManager.labelPrimary(for: colorScheme))
                    Spacer()
                    Text(lapTimeString(lap))
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundStyle(accent)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .studioThemedCardChrome(cornerRadius: 12)
            }
        }
        .padding(.horizontal, BuxLayout.marginHorizontal)
    }

    private var jobEstimateSection: some View {
        VStack(alignment: .leading, spacing: BuxTokens.tight) {
            Toggle(isOn: $hasJobEstimate) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Estimated job time")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(themeManager.labelPrimary(for: colorScheme))
                    Text("Shows progress on Lock Screen and Dynamic Island")
                        .font(.system(size: 11))
                        .foregroundStyle(themeManager.labelSecondary(for: colorScheme))
                }
            }
            .disabled(estimateLocked)

            if !StudioTimerLiveActivityManager.isSupported {
                Text("Turn on Live Activities for BuxMuse in Settings → BuxMuse.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.orange)
            }

            if showEstimateStartHint {
                Text("Press Start to lock your estimate and show progress on the Lock Screen and Dynamic Island.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(themeManager.labelSecondary(for: colorScheme))
            }

            if hasJobEstimate {
                if estimateLocked {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Goal")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(themeManager.labelSecondary(for: colorScheme))
                            Text(lockedGoalLabel)
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(themeManager.labelPrimary(for: colorScheme))
                        }
                        Spacer()
                        if !isRunning {
                            Button("Edit estimate") {
                                timer.unlockEstimateForEditing()
                            }
                            .font(.system(size: 12, weight: .semibold))
                        }
                    }
                    .foregroundStyle(themeManager.labelSecondary(for: colorScheme))
                } else {
                    HStack(spacing: BuxTokens.tight) {
                        Picker("Hours", selection: $estimateHours) {
                            ForEach(0..<13, id: \.self) { Text("\($0)h").tag($0) }
                        }
                        .pickerStyle(.menu)

                        Picker("Minutes", selection: $estimateMinutes) {
                            ForEach(Array(stride(from: 0, through: 55, by: 5)), id: \.self) { m in
                                Text("\(m)m").tag(m)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    .disabled(estimateLocked)
                    .opacity(estimateLocked ? 0.45 : 1)
                }

                jobAlertBanner

                if shouldShowExtendTime {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Need more time?")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(themeManager.labelPrimary(for: colorScheme))
                        HStack(spacing: BuxTokens.tight) {
                            BuxActionButton(
                                title: "+30m",
                                systemImage: "plus",
                                role: .secondary,
                                accent: accent,
                                expands: true,
                                action: { timer.extendEstimate(by: 30 * 60) }
                            )
                            BuxActionButton(
                                title: "+1h",
                                systemImage: "plus",
                                role: .secondary,
                                accent: accent,
                                expands: true,
                                action: { timer.extendEstimate(by: 3600) }
                            )
                        }
                    }
                }
            }
        }
        .padding(BuxLayout.section)
        .studioThemedCardChrome(cornerRadius: 14)
        .padding(.horizontal, BuxLayout.marginHorizontal)
    }

    @ViewBuilder
    private var jobAlertBanner: some View {
        switch timer.jobAlert {
        case .none:
            EmptyView()
        case .approaching(let minutesLeft):
            jobAlertChip(
                title: "Almost at your estimate",
                message: "About \(minutesLeft) min left on this job.",
                tint: .orange
            )
        case .atGoal:
            jobAlertChip(
                title: "Estimate reached",
                message: "Still working? Add time below or finish when done.",
                tint: accent
            )
        case .overtime:
            jobAlertChip(
                title: "Overtime",
                message: "You're past the goal — extend or finish when done.",
                tint: .red
            )
        }
    }

    private func jobAlertChip(title: String, message: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(tint)
            Text(message)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(themeManager.labelSecondary(for: colorScheme))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    @ViewBuilder
    private var finishActionsSection: some View {
        VStack(alignment: .leading, spacing: BuxTokens.tight) {
            if canFinishEarly {
                BuxButton(
                    title: "Finished early",
                    systemImage: "checkmark.seal.fill",
                    role: .primary,
                    expands: true,
                    action: { showFinishEarlyConfirm = true }
                )
            }

            if canLog {
                if isRunning {
                    BuxButton(
                        title: "Save & stop",
                        systemImage: "checkmark.circle.fill",
                        role: .primary,
                        expands: true,
                        action: saveTimeLog
                    )
                } else {
                    BuxButton(
                        title: "Log to Project",
                        systemImage: "checkmark.circle.fill",
                        role: canFinishEarly ? .secondary : .primary,
                        expands: true,
                        action: saveTimeLog
                    )
                }
            }
        }
        .padding(.horizontal, BuxLayout.marginHorizontal)
    }

    private var billableSection: some View {
        Toggle(isOn: $isBillable) {
            Text("Billable hours")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(themeManager.labelPrimary(for: colorScheme))
        }
        .padding(BuxLayout.section)
        .studioThemedCardChrome(cornerRadius: 14)
        .padding(.horizontal, BuxLayout.marginHorizontal)
    }

    private func dismissNotesKeyboard() {
        notesFieldFocused = false
    }

    private var projectSelectionBinding: Binding<UUID> {
        Binding(
            get: { resolvedProjectId ?? UUID() },
            set: { newValue in
                guard store.projects.contains(where: { $0.id == newValue }) else { return }
                selectedProjectId = newValue
            }
        )
    }

    private func reconcileProjectSelection() {
        guard !store.projects.isEmpty else {
            selectedProjectId = nil
            return
        }
        if let selectedProjectId, store.projects.contains(where: { $0.id == selectedProjectId }) {
            return
        }
        if let session = timer.session, store.projects.contains(where: { $0.id == session.projectId }) {
            selectedProjectId = session.projectId
        } else {
            selectedProjectId = store.projects.first?.id
        }
        if let selectedProjectId {
            timer.updateProjectId(selectedProjectId)
        }
    }

    private func hydrateFromController() {
        timer.attach(store: store)
        if let existing = timer.session {
            notes = existing.notes
            isBillable = existing.isBillable
            laps = existing.laps
            hasJobEstimate = existing.hasJobEstimate
            let totalMins = Int(existing.estimatedDuration / 60)
            estimateHours = max(0, totalMins / 60)
            estimateMinutes = totalMins % 60
            if store.projects.contains(where: { $0.id == existing.projectId }) {
                selectedProjectId = existing.projectId
            }
        }
        reconcileProjectSelection()
        refreshDisplayElapsed()
        timer.lockEstimateIfRunning()
    }

    private func syncDraftToController() {
        guard let projectId = resolvedProjectId else { return }
        timer.applyFromSheet(
            projectId: projectId,
            notes: notes,
            isBillable: isBillable,
            hasJobEstimate: hasJobEstimate,
            estimatedDuration: estimateDuration,
            laps: laps
        )
    }

    private func refreshDisplayElapsed() {
        displayElapsed = timer.session?.elapsed() ?? 0
    }

    private func toggleTimer() {
        guard resolvedProjectId != nil else { return }
        syncDraftToController()
        if timer.session == nil {
            guard let projectId = resolvedProjectId else { return }
            timer.startOrResume(projectId: projectId, store: store)
        } else {
            guard let projectId = resolvedProjectId else { return }
            timer.toggleRunning(projectId: projectId, store: store)
        }
        syncDraftToController()
        timer.lockEstimateIfRunning()
        refreshDisplayElapsed()
    }

    private func resetStopwatch() {
        timer.reset()
        laps = []
        notes = ""
        isBillable = true
        hasJobEstimate = false
        estimateHours = 1
        estimateMinutes = 0
        displayElapsed = 0
    }

    private func recordLap() {
        refreshDisplayElapsed()
        timer.recordLap()
        laps = timer.session?.laps ?? laps
    }

    private func saveTimeLog() {
        syncDraftToController()
        if timer.isRunning {
            timer.pause()
        }
        refreshDisplayElapsed()
        guard timer.logToProject(store: store) else { return }
        dismiss()
    }

    private func finishEarlyAndDismiss() {
        syncDraftToController()
        if timer.isRunning {
            timer.pause()
        }
        refreshDisplayElapsed()
        guard timer.finishEarly(store: store) else { return }
        dismiss()
    }

    private func lapTimeString(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval))
        let mins = (total % 3600) / 60
        let secs = total % 60
        let cs = Int((interval.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: "%02d:%02d.%02d", mins, secs, cs)
    }
}

// MARK: - Supporting Sheets

struct NewProjectSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var store: StudioStore
    
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
                    BuxToolbarSaveButton(isDirty: !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
                        let proj = StudioProject(
                            name: name,
                            clientId: clientId == UUID() ? nil : clientId,
                            hourlyRate: Decimal(string: hourlyRate),
                            fixedFee: Decimal(string: fixedFee),
                            notes: notes
                        )
                        store.addProject(proj)
                        BuxSaveFeedback.success()
                        dismiss()
                    }
                }
            }
            .onAppear {
                clientId = store.clients.first?.id ?? UUID()
            }
        }
    }
}
