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
    @EnvironmentObject private var simpleStudioStore: SimpleStudioStore
    @State private var showCreateProject = false
    
    var body: some View {
        StudioThemedListBackdrop {
            projectsList
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .buxRootNavigationChrome()
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                BuxToolbarButton(
                    systemName: "plus",
                    accessibilityLabel: "Create project",
                    action: { showCreateProject = true }
                )
            }
        }
        .sheet(isPresented: $showCreateProject) {
            StudioProjectEditorSheet()
                .environmentObject(themeManager)
                .environmentObject(appSettingsManager)
                .environmentObject(store)
                .buxStudioSheetContent()
        }
    }

    private var projectsList: some View {
        List {
            Section {
                StudioProToolScreenHeader(titleKey: "Projects")
                    .studioProToolScreenHeaderRow()
            }

            if store.projects.isEmpty {
                Section {
                    emptyState
                        .frame(maxWidth: .infinity)
                        .listRowInsets(EdgeInsets(top: 12, leading: 0, bottom: 12, trailing: 0))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
            } else {
                ForEach(store.projects) { project in
                let client = store.clients.first { $0.id == project.clientId }
                let analysis = StudioProjectEngine.analyzeProject(project: project, receipts: store.receipts)

                NavigationLink(
                    destination: StudioProjectDetailView(projectId: project.id)
                        .environmentObject(themeManager)
                        .environmentObject(appSettingsManager)
                        .environmentObject(store)
                        .environmentObject(simpleStudioStore)
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
        }
        .studioProToolScrollTopInset()
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
                HStack(spacing: 6) {
                    Text(project.name)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(themeManager.labelPrimary(for: colorScheme))
                    if project.resolvedStatus != .active {
                        Text(project.resolvedStatus.catalogLabel(locale: appSettingsManager.interfaceLocale))
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(statusTint(project.resolvedStatus).opacity(0.15))
                            .foregroundStyle(statusTint(project.resolvedStatus))
                            .clipShape(Capsule())
                    }
                }

                Group {
                    if clientName != nil {
                        Text(clientName!)
                    } else {
                        BuxCatalogDynamicText(key: "Independent Project")
                    }
                }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(themeManager.labelSecondary(for: colorScheme))

                Text(
                    BuxLocalizedString.format(
                        "%@ · %@",
                        locale: appSettingsManager.interfaceLocale,
                        project.billingModeLabel,
                        project.billingAmountLabel(format: appSettingsManager.format)
                    )
                )
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(themeManager.labelSecondary(for: colorScheme))
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 6) {
                Text(appSettingsManager.format(projectedRevenue))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(themeManager.labelPrimary(for: colorScheme))

                Text(
                    BuxLocalizedString.format(
                        "%.1f hrs",
                        locale: appSettingsManager.interfaceLocale,
                        totalTime / 3600
                    )
                )
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(themeManager.labelSecondary(for: colorScheme))
            }
        }
        .studioThemedListRowCard()
    }

    private func statusTint(_ status: StudioProjectStatus) -> Color {
        switch status {
        case .active: return themeManager.contrastAccentColor(for: colorScheme)
        case .onHold: return .orange
        case .completed: return .green
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: BuxLayout.section) {
            Image(systemName: "folder.fill")
                .font(.system(size: 32))
                .buxLabelSecondary()
            
            BuxCatalogDynamicText(key: "No projects yet")
                .font(.system(size: 14, weight: .semibold))
                .buxLabelSecondary()
            BuxCatalogDynamicText(key: "A project is the job you track — fixed price or hourly, time log, expenses, and invoices.")
                .font(.system(size: 12, weight: .medium))
                .buxLabelSecondary()
                .multilineTextAlignment(.center)
                .padding(.horizontal, BuxTokens.marginRegular)
            
            BuxButton(
                title: "Add Project",
                systemImage: "folder.badge.plus",
                role: .primary,
                size: .regular
            ) {
                showCreateProject = true
            }
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
    @EnvironmentObject private var simpleStudioStore: SimpleStudioStore
    @ObservedObject private var settingsStore = SettingsStore.shared
    
    let projectId: UUID

    @State private var showAgreementEditor = false
    @State private var showProjectEditor = false
    @State private var invoicePrefill: StudioInvoiceSuggestion?
    @State private var editingTimeEntry: StudioTimeEntry?
    @State private var timeEntryPendingDelete: StudioTimeEntry?
    @State private var showMilestonesEditor = false

    private var project: StudioProject? {
        store.project(id: projectId)
    }

    private var loggedHours: Double {
        project?.timeEntries.reduce(0.0) { $0 + $1.duration / 3600.0 } ?? 0
    }
    
    private var scopeAnalysis: ScopeRadarAnalysis? {
        guard let project,
              settingsStore.antiScopeCreepEnabled,
              settingsStore.studioMode == .pro,
              project.budgetedHours > 0 || project.allowedRevisions > 0 else { return nil }
        return ScopeRadarBrain.shared.analyze(
            budgetedHours: project.budgetedHours,
            loggedHours: loggedHours,
            allowedRevisions: project.allowedRevisions,
            currentRevisions: project.currentRevisions
        )
    }
    
    var body: some View {
        Group {
            if let project {
                projectDetailContent(project: project)
            } else {
                ContentUnavailableView("Project not found", systemImage: "folder")
            }
        }
    }

    private func projectDetailContent(project: StudioProject) -> some View {
        let analysis = StudioProjectEngine.analyzeProject(project: project, receipts: store.receipts)

        return ZStack {
            themeManager.screenBackground(for: colorScheme)
                .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: BuxLayout.section) {

                    projectOverviewSection(project: project, analysis: analysis)
                    projectPlannerSection(project: project)
                    projectActionsSection(project: project)
                    
                    if let scope = scopeAnalysis, scope.isAnyAlertActive {
                        scopeAlertBanner(scope, project: project)
                    }
                    
                    if let scope = scopeAnalysis {
                        scopeRadarSection(scope, project: project)
                    }

                    if settingsStore.agreementScratchpadEnabled, settingsStore.studioMode == .pro {
                        agreementScratchpadSection(project: project)
                    }
                    
                    // Overrun Risk banner
                    if analysis.isOverrunRisk {
                        HStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            BuxCatalogDynamicText(key: "Budget Overrun Risk. Hours spent exceed contract benchmarks.")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.red)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.red.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    
                    projectInvoiceSuggestionSection(project: project)

                    // 1. Margin & Financials Cards
                    financialMarginsSection(analysis: analysis)
                    
                    // 2. Time entries list
                    timeEntriesSection(project: project)
                    
                    // 3. Project Expenses
                    expensesSection(projectExpenses: analysis.projectedExpenses)
                }
                .padding(.horizontal, BuxLayout.marginHorizontal)
                .padding(.top, BuxLayout.tight)
            }
        }
        .navigationTitle(project.name)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(BuxCatalogLabel.string("Edit", locale: appSettingsManager.interfaceLocale)) {
                    showProjectEditor = true
                }
                .font(.system(size: 15, weight: .semibold))
            }
        }
        .sheet(isPresented: $showProjectEditor) {
            StudioProjectEditorSheet(existingProject: project)
                .environmentObject(themeManager)
                .environmentObject(appSettingsManager)
                .environmentObject(store)
                .buxStudioSheetContent()
        }
        .sheet(isPresented: $showMilestonesEditor) {
            StudioProjectMilestonesEditorSheet(projectId: projectId)
                .environmentObject(themeManager)
                .environmentObject(store)
                .buxStudioSheetContent()
        }
        .fullScreenCover(item: $invoicePrefill) { suggestion in
            StudioInvoiceEditorView(invoiceToEdit: nil, prefillSuggestion: suggestion)
                .environmentObject(themeManager)
                .environmentObject(appSettingsManager)
                .environmentObject(store)
        }
    }

    private func projectOverviewSection(
        project: StudioProject,
        analysis: (totalTime: TimeInterval, billableTime: TimeInterval, projectedRevenue: Decimal, projectedExpenses: Decimal, projectedProfit: Decimal, effectiveHourlyRate: Decimal, isOverrunRisk: Bool)
    ) -> some View {
        let clientName = store.clients.first(where: { $0.id == project.clientId })?.name ?? "No client linked"
        return VStack(alignment: .leading, spacing: BuxTokens.tight) {
            BuxCatalogDynamicText(key: "PROJECT OVERVIEW")
                .font(.system(size: 11, weight: .bold))
                .buxLabelSecondary()

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: project.resolvedStatus.systemImage)
                        .foregroundStyle(statusColor(project.resolvedStatus))
                    Text(project.resolvedStatus.catalogLabel(locale: appSettingsManager.interfaceLocale))
                        .font(.system(size: 14, weight: .bold))
                    Spacer()
                    if let end = project.endDate, project.resolvedStatus == .completed {
                        Text(
                            BuxLocalizedString.format(
                                "Ended %@",
                                locale: appSettingsManager.interfaceLocale,
                                formattedDate(end)
                            )
                        )
                            .font(.system(size: 11, weight: .medium))
                            .buxLabelSecondary()
                    }
                }

                overviewRow("Client", clientName)
                overviewRow("How you charge", project.billingModeLabel)
                overviewRow("Contract value", project.billingAmountLabel(format: appSettingsManager.format))

                if let fixed = project.fixedFee, fixed > 0 {
                    overviewRow(
                        "Revenue model",
                        BuxLocalizedString.format(
                            "Fixed %@ — time is tracked for margin & scope, not to recalculate the price.",
                            locale: appSettingsManager.interfaceLocale,
                            appSettingsManager.format(fixed)
                        )
                    )
                } else if let rate = project.hourlyRate, rate > 0 {
                    overviewRow(
                        "Revenue model",
                        BuxLocalizedString.format(
                            "%@/hr × %@ billable hrs logged",
                            locale: appSettingsManager.interfaceLocale,
                            appSettingsManager.format(rate),
                            String(format: "%.1f", analysis.billableTime / 3600)
                        )
                    )
                }

                overviewRow("Started", formattedDate(project.startDate))
                if project.budgetedHours > 0 {
                    overviewRow(
                        "Budgeted hours",
                        BuxLocalizedString.format(
                            "%@ h",
                            locale: appSettingsManager.interfaceLocale,
                            String(format: "%.1f", project.budgetedHours)
                        )
                    )
                }
                if project.allowedRevisions > 0 {
                    overviewRow(
                        "Revisions",
                        BuxLocalizedString.format(
                            "%lld of %lld used",
                            locale: appSettingsManager.interfaceLocale,
                            project.currentRevisions,
                            project.allowedRevisions
                        )
                    )
                }
                if !project.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    overviewRow("Notes", project.notes)
                }

                BuxCatalogText.text("Time entries below are your task log for this project.")
                    .font(.system(size: 11, weight: .medium))
                    .buxLabelSecondary()
            }
            .padding(BuxLayout.section)
            .studioThemedCardChrome(cornerRadius: 20)
        }
    }

    private func projectActionsSection(project: StudioProject) -> some View {
        VStack(spacing: BuxTokens.tight) {
            if project.resolvedStatus == .completed {
                BuxButton(
                    title: "Reopen project",
                    systemImage: "arrow.uturn.backward.circle",
                    role: .secondary,
                    expands: true
                ) {
                    reopenProject(project)
                }
            } else {
                BuxButton(
                    title: "Mark project complete",
                    systemImage: "checkmark.seal.fill",
                    role: .primary,
                    expands: true
                ) {
                    markProjectComplete(project)
                }
            }
        }
    }

    private func overviewRow(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            BuxCatalogText.text(label)
                .font(.system(size: 10, weight: .semibold))
                .buxLabelSecondary()
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(themeManager.labelPrimary(for: colorScheme))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func statusColor(_ status: StudioProjectStatus) -> Color {
        switch status {
        case .active: return themeManager.contrastAccentColor(for: colorScheme)
        case .onHold: return .orange
        case .completed: return .green
        }
    }

    private func markProjectComplete(_ project: StudioProject) {
        var updated = project
        updated.status = .completed
        updated.endDate = Date()
        store.updateProject(updated)
        BuxSaveFeedback.success()
    }

    private func reopenProject(_ project: StudioProject) {
        var updated = project
        updated.status = .active
        updated.endDate = nil
        store.updateProject(updated)
        BuxSaveFeedback.success()
    }

    private func rescheduleMilestone(milestoneId: UUID, date: Date, project: StudioProject) {
        guard var latest = store.project(id: project.id),
              let index = latest.plannerMilestones.firstIndex(where: { $0.id == milestoneId }) else { return }
        latest.plannerMilestones[index].dueDate = date
        latest.plannerMilestones.sort { $0.dueDate < $1.dueDate }
        store.updateProject(latest)
    }

    private func projectPlannerSnapshot(for project: StudioProject) -> StudioProjectPlannerSnapshot {
        StudioProjectPlannerEngine.snapshot(
            project: project,
            receipts: store.receipts,
            agreement: store.agreementDraft(forProjectId: project.id),
            profile: store.profile,
            locale: appSettingsManager.interfaceLocale
        )
    }

    @ViewBuilder
    private func projectPlannerSection(project: StudioProject) -> some View {
        if settingsStore.studioMode == .pro {
            StudioProjectPlannerSection(
                snapshot: projectPlannerSnapshot(for: project),
                projectMilestones: project.plannerMilestones,
                customMilestoneCount: project.plannerMilestones.count,
                onEditMilestones: { showMilestonesEditor = true },
                onRescheduleMilestone: { milestoneId, date in
                    rescheduleMilestone(milestoneId: milestoneId, date: date, project: project)
                }
            )
        }
    }

    private func projectInvoiceSuggestion(for project: StudioProject) -> StudioInvoiceSuggestion? {
        StudioInvoiceSuggestionEngine.proSuggestions(store: store)
            .first { $0.projectId == project.id }
    }

    @ViewBuilder
    private func projectInvoiceSuggestionSection(project: StudioProject) -> some View {
        if let suggestion = projectInvoiceSuggestion(for: project) {
            VStack(alignment: .leading, spacing: BuxTokens.tight) {
                BuxCatalogDynamicText(key: "INVOICE SUGGESTION")
                    .font(.system(size: 11, weight: .bold))
                    .buxLabelSecondary()
                Button {
                    invoicePrefill = suggestion
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            BuxCatalogDynamicText(key: "Create invoice from this project")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(themeManager.labelPrimary(for: colorScheme))
                            Text(suggestion.subtitle)
                                .font(.system(size: 12, weight: .medium))
                                .buxLabelSecondary()
                        }
                        Spacer()
                        Text(appSettingsManager.format(suggestion.amount))
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(themeManager.contrastAccentColor(for: colorScheme))
                    }
                    .padding(BuxLayout.section)
                    .studioThemedCardChrome(cornerRadius: 16)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private func scopeAlertBanner(_ scope: ScopeRadarAnalysis, project: StudioProject) -> some View {
        HStack(spacing: 12) {
            Image(systemName: scope.overallRisk.systemIcon)
                .foregroundColor(Color(hex: scope.overallRisk.color))
            Text(scope.warningBannerText(projectName: project.name))
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color(hex: scope.overallRisk.color))
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: scope.overallRisk.color).opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func scopeRadarSection(_ scope: ScopeRadarAnalysis, project: StudioProject) -> some View {
        VStack(alignment: .leading, spacing: BuxLayout.tight) {
            HStack(spacing: 6) {
                BuxCatalogDynamicText(key: "SCOPE RADAR")
                    .font(.system(size: 11, weight: .bold))
                    .buxLabelSecondary()
                ProFeatureBadge(compact: true)
            }
            
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label(
                        scope.overallRisk.catalogLabel(locale: appSettingsManager.interfaceLocale),
                        systemImage: scope.overallRisk.systemIcon
                    )
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color(hex: scope.overallRisk.color))
                    Spacer()
                    if project.budgetedHours > 0 {
                        Text(
                            BuxLocalizedString.format(
                                "%@/%@h",
                                locale: appSettingsManager.interfaceLocale,
                                String(format: "%.1f", scope.loggedHours),
                                String(format: "%.1f", scope.budgetedHours)
                            )
                        )
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .buxLabelSecondary()
                    }
                }
                
                if project.allowedRevisions > 0 {
                    Text(
                        BuxLocalizedString.format(
                            "Revisions: %lld/%lld",
                            locale: appSettingsManager.interfaceLocale,
                            project.currentRevisions,
                            project.allowedRevisions
                        )
                    )
                        .font(.system(size: 12, weight: .medium))
                        .buxLabelSecondary()
                }
                
                if scope.isAnyAlertActive {
                    ShareLink(item: scope.scopeChangeEmail(
                        projectName: project.name,
                        clientName: store.clients.first(where: { $0.id == project.clientId })?.name ?? "Client"
                    )) {
                        Label(
                            BuxCatalogLabel.string("Copy scope-change email", locale: appSettingsManager.interfaceLocale),
                            systemImage: "envelope.fill"
                        )
                            .font(.system(size: 12, weight: .bold))
                    }
                }
            }
            .padding(BuxLayout.section)
            .studioThemedCardChrome(cornerRadius: 20)
        }
    }

    private func agreementScratchpadSection(project: StudioProject) -> some View {
        let existing = store.agreementDraft(forProjectId: project.id)
        return VStack(alignment: .leading, spacing: BuxLayout.tight) {
            HStack(spacing: 6) {
                BuxCatalogDynamicText(key: "AGREEMENT")
                    .font(.system(size: 11, weight: .bold))
                    .buxLabelSecondary()
                ProFeatureBadge(compact: true)
            }

            VStack(alignment: .leading, spacing: 10) {
                Group {
                    if existing == nil {
                        BuxCatalogDynamicText(key: "No agreement yet for this project.")
                    } else {
                        Text(
                            BuxLocalizedString.format(
                                "%@ · %@",
                                locale: appSettingsManager.interfaceLocale,
                                StudioAgreementL10n.line(existing!.statusDisplayLabel, locale: appSettingsManager.interfaceLocale),
                                existing!.title
                            )
                        )
                    }
                }
                    .font(.system(size: 12, weight: .medium))
                    .buxLabelSecondary()

                Button {
                    showAgreementEditor = true
                } label: {
                    Label {
                        BuxCatalogText.text(existing == nil ? "Create agreement draft" : "Edit agreement draft")
                    } icon: {
                        Image(systemName: "doc.text.fill")
                    }
                        .font(.system(size: 12, weight: .bold))
                }
            }
            .padding(BuxLayout.section)
            .studioThemedCardChrome(cornerRadius: 20)
        }
        .sheet(isPresented: $showAgreementEditor) {
            NavigationStack {
                AgreementScratchpadEditorView(
                    project: project,
                    existingDraft: existing
                )
                .environmentObject(store)
                .environmentObject(themeManager)
                .environmentObject(simpleStudioStore)
            }
            .buxStudioSheetContent()
        }
    }
    
    // MARK: - Subviews
    
    private func financialMarginsSection(analysis: (totalTime: TimeInterval, billableTime: TimeInterval, projectedRevenue: Decimal, projectedExpenses: Decimal, projectedProfit: Decimal, effectiveHourlyRate: Decimal, isOverrunRisk: Bool)) -> some View {
        VStack(alignment: .leading, spacing: BuxLayout.tight) {
            BuxCatalogDynamicText(key: "FINANCIAL MATRIX")
                .font(.system(size: 11, weight: .bold))
                .buxLabelSecondary()
            
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    BuxCatalogDynamicText(key: "REVENUE")
                        .font(.system(size: 9, weight: .semibold))
                        .buxLabelSecondary()
                    Text(appSettingsManager.format(analysis.projectedRevenue))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.green)
                }
                Spacer()
                VStack(alignment: .leading, spacing: 4) {
                    BuxCatalogDynamicText(key: "EXPENSES")
                        .font(.system(size: 9, weight: .semibold))
                        .buxLabelSecondary()
                    Text(appSettingsManager.format(analysis.projectedExpenses))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.red)
                }
                Spacer()
                VStack(alignment: .leading, spacing: 4) {
                    BuxCatalogDynamicText(key: "PROFIT")
                        .font(.system(size: 9, weight: .semibold))
                        .buxLabelSecondary()
                    Text(appSettingsManager.format(analysis.projectedProfit))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                }
            }
            .padding(.vertical, 8)
            
            Divider()
            
            HStack {
                BuxCatalogDynamicText(key: "Effective hourly rate:")
                    .font(.system(size: 12))
                    .buxLabelSecondary()
                Spacer()
                Text(
                    BuxLocalizedString.format(
                        "%@/hr",
                        locale: appSettingsManager.interfaceLocale,
                        appSettingsManager.format(analysis.effectiveHourlyRate)
                    )
                )
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(themeManager.labelPrimary(for: colorScheme))
            }
        }
        .padding(BuxLayout.section)
        .studioThemedCardChrome(cornerRadius: 24)
    }
    
    private func timeEntriesSection(project: StudioProject) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            BuxCatalogDynamicText(key: "TIME ENTRIES LOG")
                .font(.system(size: 11, weight: .bold))
                .buxLabelSecondary()
            
            if project.timeEntries.isEmpty {
                BuxCatalogDynamicText(key: "No time entries logged yet.")
                    .font(.system(size: 12))
                    .buxLabelSecondary()
            } else {
                ForEach(project.timeEntries) { entry in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Group {
                                if entry.notes.isEmpty {
                                    BuxCatalogDynamicText(key: "Consulting work")
                                } else {
                                    Text(entry.notes)
                                }
                            }
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                            Text(formattedDate(entry.startTime))
                                .font(.system(size: 11))
                                .buxLabelSecondary()
                        }
                        Spacer()
                        Text(
                            BuxLocalizedString.format(
                                "%.1f hrs",
                                locale: appSettingsManager.interfaceLocale,
                                entry.duration / 3600
                            )
                        )
                            .font(.system(size: 13, weight: .semibold))
                        
                        BuxCatalogDynamicText(key: entry.isBillable ? "Billable" : "Admin")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(entry.isBillable ? .green : .gray)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background((entry.isBillable ? Color.green : Color.gray).opacity(0.12))
                            .clipShape(Capsule())
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                    .onTapGesture { editingTimeEntry = entry }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            timeEntryPendingDelete = entry
                        } label: {
                            Label(
                                BuxCatalogLabel.string("Delete", locale: appSettingsManager.interfaceLocale),
                                systemImage: "trash"
                            )
                        }
                    }
                }
            }
        }
        .padding(BuxLayout.section)
        .frame(maxWidth: .infinity, alignment: .leading)
        .studioThemedCardChrome(cornerRadius: 24)
        .sheet(item: $editingTimeEntry) { entry in
            StudioTimeEntryEditorSheet(projectId: projectId, entry: entry)
                .environmentObject(store)
                .environmentObject(themeManager)
                .environmentObject(appSettingsManager)
        }
        .alert(
            BuxCatalogLabel.string("Delete time entry?", locale: appSettingsManager.interfaceLocale),
            isPresented: Binding(
                get: { timeEntryPendingDelete != nil },
                set: { if !$0 { timeEntryPendingDelete = nil } }
            )
        ) {
            Button(BuxCatalogLabel.string("Delete", locale: appSettingsManager.interfaceLocale), role: .destructive) {
                if let entry = timeEntryPendingDelete {
                    deleteTimeEntry(entry)
                }
                timeEntryPendingDelete = nil
            }
            Button(BuxCatalogLabel.string("Cancel", locale: appSettingsManager.interfaceLocale), role: .cancel) {
                timeEntryPendingDelete = nil
            }
        } message: {
            BuxCatalogDynamicText(key: "This removes the entry from the project log.")
        }
    }

    private func deleteTimeEntry(_ entry: StudioTimeEntry) {
        guard var project = store.project(id: projectId) else { return }
        project.timeEntries.removeAll { $0.id == entry.id }
        store.updateProject(project)
        BuxSaveFeedback.success()
    }
    
    private func expensesSection(projectExpenses: Decimal) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            BuxCatalogDynamicText(key: "LINKED EXPENSES")
                .font(.system(size: 11, weight: .bold))
                .buxLabelSecondary()
            
            HStack {
                BuxCatalogDynamicText(key: "Total project direct cost:")
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
        BuxDisplayDate.monthDayYear(from: date, locale: appSettingsManager.interfaceLocale)
    }
}

// MARK: - Stopwatch time tracker (Studio quick action)

struct ActiveTimeTrackerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
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
    @State private var autoPauseAtPlanEnd = true
    @State private var showFinishEarlyConfirm = false
    @FocusState private var notesFieldFocused: Bool

    private var accent: Color { themeManager.contrastAccentColor(for: colorScheme) }
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

    @ViewBuilder
    private var workDealApprovalBanner: some View {
        if let projectId = resolvedProjectId,
           StudioWorkDealHelpers.needsClientApproval(projectId: projectId, studioStore: store) {
            StudioWorkDealApprovalBanner(
                message: BuxCatalogLabel.string(
                    "No client approval on file for this project. Logging time is allowed — capture agreement when you can.",
                    locale: appSettingsManager.interfaceLocale
                )
            )
            .padding(.horizontal, BuxTokens.marginRegular)
        }
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
                        workDealApprovalBanner
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
            .buxCatalogNavigationTitle("Work clock")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    BuxToolbarCancelButton {
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
                timer.setJobEstimate(enabled: enabled, duration: estimateDuration, autoPauseAtEnd: autoPauseAtPlanEnd)
            }
            .onChange(of: estimateHours) { _, _ in
                guard !estimateLocked else { return }
                timer.setJobEstimate(enabled: hasJobEstimate, duration: estimateDuration, autoPauseAtEnd: autoPauseAtPlanEnd)
            }
            .onChange(of: estimateMinutes) { _, _ in
                guard !estimateLocked else { return }
                timer.setJobEstimate(enabled: hasJobEstimate, duration: estimateDuration, autoPauseAtEnd: autoPauseAtPlanEnd)
            }
            .onChange(of: autoPauseAtPlanEnd) { _, value in
                guard !estimateLocked else { return }
                timer.setJobEstimate(enabled: hasJobEstimate, duration: estimateDuration, autoPauseAtEnd: value)
            }
            .confirmationDialog(
                BuxCatalogLabel.string("Finished early?", locale: appSettingsManager.interfaceLocale),
                isPresented: $showFinishEarlyConfirm,
                titleVisibility: .visible
            ) {
                Button {
                    finishEarlyAndDismiss()
                } label: {
                    Text(
                        BuxLocalizedString.format(
                            "Log %@ and stop",
                            locale: appSettingsManager.interfaceLocale,
                            StudioTimerSession.formattedElapsed(displayElapsed, style: .hub)
                        )
                    )
                }
                Button(BuxCatalogLabel.string("Cancel", locale: appSettingsManager.interfaceLocale), role: .cancel) {}
            } message: {
                BuxCatalogDynamicText(key: "Save your time entry and end the Live Activity.")
            }
        }
        .tint(accent)
    }

    private var projectPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            BuxCatalogDynamicText(key: "PROJECT")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(themeManager.labelSecondary(for: colorScheme))
                .kerning(1)

            if store.projects.isEmpty {
                BuxCatalogDynamicText(key: "Add a project in Studio first")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(themeManager.labelSecondary(for: colorScheme))
            } else {
                Picker(BuxCatalogLabel.string("Project", locale: appSettingsManager.interfaceLocale), selection: projectSelectionBinding) {
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
            BuxCatalogDynamicText(key: "JOB NAME")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(themeManager.labelSecondary(for: colorScheme))
                .kerning(1)

            TextField(BuxCatalogLabel.string("What are you working on?", locale: appSettingsManager.interfaceLocale), text: $notes, axis: .vertical)
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
            BuxCatalogDynamicText(key: "LAPS")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(themeManager.labelSecondary(for: colorScheme))
                .kerning(1)

            ForEach(Array(laps.enumerated().reversed()), id: \.offset) { index, lap in
                HStack {
                    Text(
                        BuxLocalizedString.format(
                            "Lap %lld",
                            locale: appSettingsManager.interfaceLocale,
                            laps.count - index
                        )
                    )
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
        StudioWorkClockPlanSection(
            copy: .pro,
            accent: accent,
            hasPlan: $hasJobEstimate,
            planHours: $estimateHours,
            planMinutes: $estimateMinutes,
            autoPauseAtEnd: $autoPauseAtPlanEnd,
            planLocked: estimateLocked,
            timerRunning: isRunning,
            lockedPlanLabel: lockedGoalLabel,
            showStartHint: showEstimateStartHint,
            showExtendControls: shouldShowExtendTime,
            jobAlert: timer.jobAlert,
            alertTitle: proWorkClockAlertTitle,
            alertMessage: proWorkClockAlertMessage,
            onUnlockPlan: { timer.unlockEstimateForEditing() },
            onExtend30m: { timer.extendEstimate(by: 30 * 60) },
            onExtend1h: { timer.extendEstimate(by: 3600) },
            budgetShortcutLabel: budgetedHoursShortcutLabel,
            onApplyBudgetShortcut: applyBudgetedHoursShortcut
        )
    }

    private var budgetedHoursShortcutLabel: String? {
        guard let project = store.projects.first(where: { $0.id == resolvedProjectId }),
              project.budgetedHours > 0 else { return nil }
        let duration = StudioTimerSession.formattedDuration(project.budgetedHours * 3600)
        return BuxLocalizedString.format(
            "Use project budget (%@)",
            locale: appSettingsManager.interfaceLocale,
            duration
        )
    }

    private func applyBudgetedHoursShortcut() {
        guard let project = store.projects.first(where: { $0.id == resolvedProjectId }),
              project.budgetedHours > 0 else { return }
        hasJobEstimate = true
        let split = StudioWorkClockPlanEngine.split(project.budgetedHours * 3600)
        estimateHours = split.hours
        estimateMinutes = split.minutes
        timer.setJobEstimate(enabled: true, duration: estimateDuration, autoPauseAtEnd: autoPauseAtPlanEnd)
    }

    private func proWorkClockAlertTitle(_ alert: StudioTimerJobAlert) -> String {
        let locale = appSettingsManager.interfaceLocale
        switch alert {
        case .none: return ""
        case .approaching: return BuxCatalogLabel.string("Almost at your estimate", locale: locale)
        case .atGoal: return BuxCatalogLabel.string("Estimate reached", locale: locale)
        case .overtime: return BuxCatalogLabel.string("Overtime", locale: locale)
        }
    }

    private func proWorkClockAlertMessage(_ alert: StudioTimerJobAlert) -> String {
        let locale = appSettingsManager.interfaceLocale
        switch alert {
        case .none: return ""
        case .approaching(let minutesLeft):
            return BuxLocalizedString.format(
                "About %lld min left on this job.",
                locale: locale,
                minutesLeft
            )
        case .atGoal:
            return BuxLocalizedString.string(
                "Still working? Add time below or finish when done.",
                locale: locale
            )
        case .overtime:
            return BuxLocalizedString.string(
                "You're past the goal — extend or finish when done.",
                locale: locale
            )
        }
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
            BuxCatalogDynamicText(key: "Billable hours")
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
            let split = StudioWorkClockPlanEngine.split(existing.estimatedDuration)
            estimateHours = split.hours
            estimateMinutes = split.minutes
            autoPauseAtPlanEnd = existing.autoPauseAtPlanEnd
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
        autoPauseAtPlanEnd = true
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

private enum StudioProjectBillingChoice: String, CaseIterable, Identifiable {
    case hourly = "Hourly"
    case fixedPrice = "Fixed price"
    case both = "Both (reference)"

    var id: String { rawValue }
}

/// Create or edit a Pro Studio project (contract, status, scope budgets).
struct StudioProjectEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var store: StudioStore
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    @ObservedObject private var settingsStore = SettingsStore.shared

    var existingProject: StudioProject?

    @State private var name = ""
    @State private var clientId: UUID = UUID()
    @State private var status: StudioProjectStatus = .active
    @State private var billingChoice: StudioProjectBillingChoice = .hourly
    @State private var hourlyRate = ""
    @State private var fixedFee = ""
    @State private var notes = ""
    @State private var plannedScope = ""
    @State private var plannedDeliverables = ""
    @State private var budgetedHours = ""
    @State private var allowedRevisions = ""
    @State private var currentRevisions = ""
    @State private var startDate = Date()
    @State private var hasEndDate = false
    @State private var endDate = Date()
    @State private var plannerMilestones: [StudioProjectMilestone] = []
    @State private var showMilestonesEditor = false

    private var isEditing: Bool { existingProject != nil }

    private var canSave: Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        switch billingChoice {
        case .hourly:
            return Decimal(string: hourlyRate) != nil
        case .fixedPrice:
            return Decimal(string: fixedFee) != nil
        case .both:
            return Decimal(string: hourlyRate) != nil && Decimal(string: fixedFee) != nil
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.screenBackground(for: colorScheme)
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    BuxThemedCardForm {
                        BuxFormSection(title: "Project") {
                            TextField(BuxCatalogLabel.string("Project name", locale: appSettingsManager.interfaceLocale), text: $name)
                                .buxFormFieldPadding()
                            BuxFormRowDivider()
                            Picker(BuxCatalogLabel.string("Client", locale: appSettingsManager.interfaceLocale), selection: $clientId) {
                                if store.clients.isEmpty {
                                    BuxCatalogDynamicText(key: "No client").tag(UUID())
                                } else {
                                    ForEach(store.clients) { c in
                                        Text(c.name).tag(c.id)
                                    }
                                }
                            }
                            .buxFormFieldPadding()
                            BuxFormRowDivider()
                            Picker(BuxCatalogLabel.string("Status", locale: appSettingsManager.interfaceLocale), selection: $status) {
                                ForEach(StudioProjectStatus.allCases) { s in
                                    Text(s.catalogLabel(locale: appSettingsManager.interfaceLocale)).tag(s)
                                }
                            }
                            .buxFormFieldPadding()
                        }

                        BuxFormSection(title: "How you charge") {
                            Picker(BuxCatalogLabel.string("Billing", locale: appSettingsManager.interfaceLocale), selection: $billingChoice) {
                                ForEach(StudioProjectBillingChoice.allCases) { choice in
                                    Text(choice.catalogLabel(locale: appSettingsManager.interfaceLocale)).tag(choice)
                                }
                            }
                            .buxThemedSegmentedPicker()
                            .padding(.horizontal, BuxTokens.section)
                            .padding(.vertical, 10)

                            Text(billingHelpText)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(themeManager.labelSecondary(for: colorScheme))
                                .padding(.horizontal, BuxTokens.section)
                                .padding(.bottom, 6)

                            if billingChoice == .hourly || billingChoice == .both {
                                BuxFormRowDivider()
                                TextField(BuxCatalogLabel.string("Hourly rate", locale: appSettingsManager.interfaceLocale), text: $hourlyRate)
                                    .keyboardType(.decimalPad)
                                    .buxFormFieldPadding()
                            }
                            if billingChoice == .fixedPrice || billingChoice == .both {
                                BuxFormRowDivider()
                                TextField(BuxCatalogLabel.string("Fixed price for whole project", locale: appSettingsManager.interfaceLocale), text: $fixedFee)
                                    .keyboardType(.decimalPad)
                                    .buxFormFieldPadding()
                            }
                        }

                        BuxFormSection(title: "Dates") {
                            DatePicker(BuxCatalogLabel.string("Started", locale: appSettingsManager.interfaceLocale), selection: $startDate, displayedComponents: .date)
                                .buxFormFieldPadding()
                            BuxFormRowDivider()
                            Toggle(BuxCatalogLabel.string("Set end date", locale: appSettingsManager.interfaceLocale), isOn: $hasEndDate)
                                .padding(.horizontal, BuxTokens.section)
                                .padding(.vertical, 10)
                            if hasEndDate {
                                BuxFormRowDivider()
                                DatePicker(BuxCatalogLabel.string("Ended", locale: appSettingsManager.interfaceLocale), selection: $endDate, displayedComponents: .date)
                                    .buxFormFieldPadding()
                            }
                        }

                        BuxFormSection(title: "Project plan") {
                            BuxCatalogDynamicText(key: "Used when you fill an agreement from this project.")
                                .font(.system(size: 11, weight: .medium))
                                .buxLabelSecondary()
                                .padding(.horizontal, BuxTokens.section)
                                .padding(.top, 8)
                            BuxFormRowDivider()
                            TextField(BuxCatalogLabel.string("Scope (for agreements)", locale: appSettingsManager.interfaceLocale), text: $plannedScope, axis: .vertical)
                                .lineLimit(2...6)
                                .buxFormFieldPadding()
                            BuxFormRowDivider()
                            TextField(BuxCatalogLabel.string("Deliverables", locale: appSettingsManager.interfaceLocale), text: $plannedDeliverables, axis: .vertical)
                                .lineLimit(2...6)
                                .buxFormFieldPadding()
                        }

                        if settingsStore.studioMode == .pro {
                            BuxFormSection(title: "Planner milestones") {
                                HStack {
                                    Text(plannerMilestones.isEmpty
                                        ? "None — planner uses auto dates"
                                        : "\(plannerMilestones.count) milestone(s)")
                                        .font(.system(size: 14, weight: .medium))
                                    Spacer()
                                    Button(BuxCatalogLabel.string("Manage", locale: appSettingsManager.interfaceLocale)) { showMilestonesEditor = true }
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                                }
                                .buxFormFieldPadding()
                            }
                        }

                        BuxFormSection(title: "Internal notes") {
                            TextField(BuxCatalogLabel.string("Reminders, links, private notes…", locale: appSettingsManager.interfaceLocale), text: $notes, axis: .vertical)
                                .lineLimit(2...5)
                                .buxFormFieldPadding()
                        }

                        if settingsStore.studioMode == .pro, settingsStore.antiScopeCreepEnabled {
                            BuxFormSection(title: "Scope Radar") {
                                TextField(BuxCatalogLabel.string("Budgeted hours", locale: appSettingsManager.interfaceLocale), text: $budgetedHours)
                                    .keyboardType(.decimalPad)
                                    .buxFormFieldPadding()
                                BuxFormRowDivider()
                                TextField(BuxCatalogLabel.string("Included revisions", locale: appSettingsManager.interfaceLocale), text: $allowedRevisions)
                                    .keyboardType(.numberPad)
                                    .buxFormFieldPadding()
                                if isEditing {
                                    BuxFormRowDivider()
                                    TextField(BuxCatalogLabel.string("Revisions used so far", locale: appSettingsManager.interfaceLocale), text: $currentRevisions)
                                        .keyboardType(.numberPad)
                                        .buxFormFieldPadding()
                                }
                            }
                        }
                    }
                    .padding(.bottom, BuxTokens.sheetBottomClearance)
                }
            }
            .buxCatalogNavigationTitle(isEditing ? "Edit Project" : "New Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    BuxToolbarCancelButton { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    BuxToolbarSaveButton(isDirty: canSave) {
                        saveProject()
                    }
                }
            }
            .onAppear(perform: loadExisting)
            .sheet(isPresented: $showMilestonesEditor) {
                if let projectId = existingProject?.id {
                    StudioProjectMilestonesEditorSheet(projectId: projectId)
                        .environmentObject(themeManager)
                        .environmentObject(store)
                } else {
                    StudioProjectMilestonesDraftEditorSheet(milestones: $plannerMilestones)
                        .environmentObject(themeManager)
                }
            }
            .buxStudioSheetContent()
        }
    }

    private var billingHelpText: String {
        let locale = appSettingsManager.interfaceLocale
        switch billingChoice {
        case .hourly:
            return BuxLocalizedString.string(
                "Revenue = hourly rate × billable hours logged on this project.",
                locale: locale
            )
        case .fixedPrice:
            return BuxLocalizedString.string(
                "Revenue stays the fixed price — still log time to track margin and scope.",
                locale: locale
            )
        case .both:
            return BuxLocalizedString.string(
                "Revenue uses the fixed price; hourly rate is kept for reference and invoices.",
                locale: locale
            )
        }
    }

    private func loadExisting() {
        guard let project = existingProject else {
            if let first = store.clients.first?.id { clientId = first }
            return
        }
        name = project.name
        clientId = project.clientId ?? (store.clients.first?.id ?? UUID())
        status = project.resolvedStatus
        notes = project.notes
        plannedScope = project.plannedScope
        plannedDeliverables = project.plannedDeliverables
        plannerMilestones = project.plannerMilestones
        hourlyRate = project.hourlyRate.map { "\($0)" } ?? ""
        fixedFee = project.fixedFee.map { "\($0)" } ?? ""
        budgetedHours = project.budgetedHours > 0 ? "\(project.budgetedHours)" : ""
        allowedRevisions = project.allowedRevisions > 0 ? "\(project.allowedRevisions)" : ""
        currentRevisions = project.currentRevisions > 0 ? "\(project.currentRevisions)" : ""
        startDate = project.startDate
        if let end = project.endDate {
            hasEndDate = true
            endDate = end
        }
        if let fixed = project.fixedFee, fixed > 0, let hourly = project.hourlyRate, hourly > 0 {
            billingChoice = .both
        } else if let fixed = project.fixedFee, fixed > 0 {
            billingChoice = .fixedPrice
        } else {
            billingChoice = .hourly
        }
    }

    private func saveProject() {
        let hourly: Decimal? = {
            switch billingChoice {
            case .hourly, .both: return Decimal(string: hourlyRate)
            case .fixedPrice: return nil
            }
        }()
        let fixed: Decimal? = {
            switch billingChoice {
            case .fixedPrice, .both: return Decimal(string: fixedFee)
            case .hourly: return nil
            }
        }()

        var resolvedEnd: Date? = hasEndDate ? endDate : nil
        if status == .completed, resolvedEnd == nil {
            resolvedEnd = Date()
        }

        if var existing = existingProject {
            existing.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
            existing.clientId = clientId == UUID() || !store.clients.contains(where: { $0.id == clientId }) ? nil : clientId
            existing.status = status
            existing.hourlyRate = hourly
            existing.fixedFee = fixed
            existing.notes = notes
            existing.plannedScope = plannedScope
            existing.plannedDeliverables = plannedDeliverables
            existing.plannerMilestones = plannerMilestones
            existing.startDate = startDate
            existing.endDate = resolvedEnd
            existing.budgetedHours = Double(budgetedHours) ?? existing.budgetedHours
            existing.allowedRevisions = Int(allowedRevisions) ?? existing.allowedRevisions
            existing.currentRevisions = Int(currentRevisions) ?? existing.currentRevisions
            store.updateProject(existing)
        } else {
            let proj = StudioProject(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                clientId: clientId == UUID() || !store.clients.contains(where: { $0.id == clientId }) ? nil : clientId,
                startDate: startDate,
                endDate: resolvedEnd,
                hourlyRate: hourly,
                fixedFee: fixed,
                notes: notes,
                plannedScope: plannedScope,
                plannedDeliverables: plannedDeliverables,
                hustleId: settingsStore.sideHustleMatrixEnabled
                    ? HustleManager.shared.selectedHustleId
                    : nil,
                budgetedHours: Double(budgetedHours) ?? 0,
                allowedRevisions: Int(allowedRevisions) ?? 0,
                currentRevisions: Int(currentRevisions) ?? 0,
                status: status,
                plannerMilestones: plannerMilestones
            )
            store.addProject(proj)
        }
        BuxSaveFeedback.success()
        dismiss()
    }
}
