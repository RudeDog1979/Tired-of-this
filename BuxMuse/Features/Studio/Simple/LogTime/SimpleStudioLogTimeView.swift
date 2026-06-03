//
//  SimpleStudioLogTimeView.swift
//  BuxMuse
//
//  Work clock for Simple Studio — one price vs by-the-hour, plain language.
//

import SwiftUI

struct SimpleStudioLogTimeView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @EnvironmentObject private var simpleStore: SimpleStudioStore
    @EnvironmentObject private var studioStore: StudioStore

    @ObservedObject private var timer = StudioTimerController.shared

    @State private var selectedJobId: UUID?
    @State private var notes = ""
    @State private var displayElapsed: TimeInterval = 0
    @State private var showFinishConfirm = false

    private var accent: Color { themeManager.current.accentColor }

    private var jobs: [SimpleStudioEntry] {
        simpleStore.activeJobEntries
    }

    private var selectedJob: SimpleStudioEntry? {
        guard let id = selectedJobId ?? jobs.first?.id else { return nil }
        return simpleStore.entry(id: id)
    }

    @ViewBuilder
    private var approvalBanner: some View {
        if let job = selectedJob,
           StudioWorkDealHelpers.needsClientApproval(job: job, studioStore: studioStore) {
            StudioWorkDealApprovalBanner(
                message: "No client approval recorded yet. You can still log time — set up the agreement when you can."
            )
            .padding(.horizontal, BuxTokens.marginRegular)
        }
    }

    private var paySnapshot: SimpleStudioTimePayEngine.WorkClockSnapshot? {
        guard let job = selectedJob else { return nil }
        return SimpleStudioTimePayEngine.workClockSnapshot(
            for: job,
            sessionSeconds: displayElapsed,
            formatMoney: { appSettingsManager.format($0) }
        )
    }

    private var isRunning: Bool {
        timer.session?.isSimpleJobSession == true && timer.isRunning
    }

    private var sessionProgress: Double {
        timer.session?.isSimpleJobSession == true ? (timer.session?.progress() ?? 0) : 0
    }

    private var shouldShowPlanExtend: Bool {
        guard timer.session?.isSimpleJobSession == true,
              timer.session?.hasJobEstimate == true else { return false }
        return sessionProgress >= 1.0 || timer.session?.isOvertime == true
    }

    private var stopwatchTimerAnchor: Date? {
        guard let session = timer.session,
              session.isSimpleJobSession,
              session.isRunning,
              let segmentStart = session.segmentStart else { return nil }
        return segmentStart.addingTimeInterval(-session.accumulated)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.screenBackground(for: colorScheme).ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: BuxLayout.section) {
                        introCard
                        approvalBanner
                        jobPicker
                        if let snapshot = paySnapshot {
                            payContextCard(snapshot)
                        }
                        simplePlanSection
                        notesSection

                        BuxStopwatchFace(
                            elapsed: displayElapsed,
                            isRunning: isRunning,
                            timerAnchor: stopwatchTimerAnchor,
                            accent: accent
                        )
                        .padding(.vertical, 8)

                        controlRow
                        finishSection
                        Spacer().frame(height: BuxTokens.block)
                    }
                    .padding(.top, BuxLayout.tight)
                }
                .buxScrollContentMargins()
            }
            .buxCatalogNavigationTitle("Work clock")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    BuxToolbarCancelButton {
                        syncNotesToController()
                        dismiss()
                    }
                }
            }
            .onAppear {
                timer.attach(simpleStore: simpleStore)
                hydrateFromSession()
                if scenePhase == .active {
                    timer.syncLiveActivityOnForeground()
                }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    refreshElapsed()
                    timer.syncLiveActivityOnForeground()
                }
            }
            .task(id: scenePhase) {
                guard scenePhase == .active else { return }
                refreshElapsed()
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(1))
                    guard !Task.isCancelled else { return }
                    refreshElapsed()
                    if timer.session?.isRunning == true {
                        timer.evaluateJobMilestones()
                    }
                }
            }
            .onChange(of: selectedJobId) { _, id in
                guard let id else { return }
                timer.updateSimpleJobId(id)
            }
            .onChange(of: notes) { _, value in
                timer.updateNotes(value)
            }
            .confirmationDialog(
                finishDialogTitle,
                isPresented: $showFinishConfirm,
                titleVisibility: .visible
            ) {
                Button(finishDialogAction) {
                    if timer.finishEarly(simpleStore: simpleStore) {
                        dismiss()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(finishDialogMessage)
            }
        }
        .tint(accent)
    }

    private var introCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            BuxCatalogDynamicText(key: "Two ways people get paid")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(themeManager.labelPrimary(for: colorScheme))
            BuxCatalogDynamicText(key: "Pick the job below. We'll show whether the clock is just for your records, or whether it counts toward what they owe.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(themeManager.labelSecondary(for: colorScheme))
        }
        .padding(BuxLayout.section)
        .studioThemedCardChrome(cornerRadius: 16)
        .padding(.horizontal, BuxLayout.marginHorizontal)
    }

    private var jobPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            BuxCatalogDynamicText(key: "WHICH JOB?")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(themeManager.labelSecondary(for: colorScheme))
                .kerning(1)

            if jobs.isEmpty {
                BuxCatalogDynamicText(key: "Quote a job first — say if it's one price or paid by the hour.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(themeManager.labelSecondary(for: colorScheme))
            } else {
                Picker("Job", selection: jobSelectionBinding) {
                    ForEach(jobs) { job in
                        Text(jobPickerLabel(job)).tag(job.id)
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

    private func payContextCard(_ snapshot: SimpleStudioTimePayEngine.WorkClockSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: snapshot.style == .byTheHour ? "clock.badge.checkmark" : "seal.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(accent)
                Text(snapshot.style.plainTitle)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(accent)
            }

            Text(snapshot.headline)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(themeManager.labelPrimary(for: colorScheme))

            Text(snapshot.style == .byTheHour ? "Owed from hours so far" : "Agreed price for the job")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(themeManager.labelSecondary(for: colorScheme))

            Text(snapshot.detail)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(themeManager.labelSecondary(for: colorScheme))
                .fixedSize(horizontal: false, vertical: true)

            if snapshot.stillWaiting > 0 {
                HStack {
                    BuxCatalogDynamicText(key: "Still waiting")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(themeManager.labelSecondary(for: colorScheme))
                    Spacer()
                    Text(appSettingsManager.format(snapshot.stillWaiting))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.orange)
                }
            }

            if snapshot.loggedSeconds > 0, displayElapsed == 0 {
                Text(
                    BuxLocalizedString.format(
                        "Already logged: %@",
                        locale: appSettingsManager.interfaceLocale,
                        SimpleStudioTimePayEngine.formattedHours(snapshot.loggedSeconds)
                    )
                )
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(themeManager.labelSecondary(for: colorScheme))
            }
        }
        .padding(BuxLayout.section)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(snapshot.style == .byTheHour
                      ? accent.opacity(0.08)
                      : themeManager.cardFill(for: colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(accent.opacity(0.25), lineWidth: 1)
        )
        .padding(.horizontal, BuxLayout.marginHorizontal)
    }

    @ViewBuilder
    private var simplePlanSection: some View {
        if let job = selectedJob, job.hasWorkPlan, let label = job.plannedTimeLabel {
            VStack(alignment: .leading, spacing: BuxTokens.tight) {
                HStack(spacing: 8) {
                    Image(systemName: "figure.walk")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(accent)
                    Text(
                        BuxLocalizedString.format(
                            "Planned time: %@",
                            locale: appSettingsManager.interfaceLocale,
                            label
                        )
                    )
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(themeManager.labelPrimary(for: colorScheme))
                }
                Text(job.resolvedPauseWhenPlanEnds
                     ? "Walker on your Lock Screen — clock pauses when you hit this time."
                     : "Walker on your Lock Screen — keeps going if you run over.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(themeManager.labelSecondary(for: colorScheme))

                simplePlanAlertBanner

                if shouldShowPlanExtend {
                    VStack(alignment: .leading, spacing: 6) {
                        BuxCatalogDynamicText(key: "Need more time?")
                            .font(.system(size: 12, weight: .semibold))
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
            .padding(BuxLayout.section)
            .studioThemedCardChrome(cornerRadius: 16)
            .padding(.horizontal, BuxLayout.marginHorizontal)
        }
    }

    @ViewBuilder
    private var simplePlanAlertBanner: some View {
        switch timer.jobAlert {
        case .none:
            EmptyView()
        case .approaching(let minutesLeft):
            Text(
                BuxLocalizedString.format(
                    "Almost there — about %lld min left on your plan.",
                    locale: appSettingsManager.interfaceLocale,
                    minutesLeft
                )
            )
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.orange)
        case .atGoal:
            BuxCatalogDynamicText(key: "Time is up — clock paused. Save your work or add more time.")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(accent)
        case .overtime:
            BuxCatalogDynamicText(key: "You're past the agreed time — add time or save when done.")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.red)
        }
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            BuxCatalogDynamicText(key: "WHAT ARE YOU DOING?")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(themeManager.labelSecondary(for: colorScheme))
                .kerning(1)

            TextField("Optional — e.g. painting, delivery run", text: $notes, axis: .vertical)
                .lineLimit(1...3)
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
                isEnabled: displayElapsed > 0 || isRunning,
                action: { timer.reset() }
            )

            BuxActionButton(
                title: isRunning ? "Pause" : "Start",
                systemImage: isRunning ? "pause.fill" : "play.fill",
                role: .primary,
                accent: isRunning ? .red : accent,
                expands: true,
                isEnabled: selectedJobId != nil,
                action: toggleTimer
            )
        }
        .padding(.horizontal, BuxLayout.marginHorizontal)
    }

    private var finishSection: some View {
        BuxActionButton(
            title: paySnapshot?.saveButtonHint ?? "Save time to job",
            systemImage: "checkmark.circle.fill",
            role: .primary,
            accent: accent,
            expands: true,
            isEnabled: displayElapsed > 0 && selectedJobId != nil,
            action: { showFinishConfirm = true }
        )
        .padding(.horizontal, BuxLayout.marginHorizontal)
    }

    private var finishDialogTitle: String {
        paySnapshot?.style == .byTheHour ? "Save hours to this job?" : "Save time on this job?"
    }

    private var finishDialogAction: String {
        paySnapshot?.saveButtonHint ?? "Save"
    }

    private var finishDialogMessage: String {
        paySnapshot?.detail ?? "Adds this session to the job."
    }

    private var jobSelectionBinding: Binding<UUID> {
        Binding(
            get: { selectedJobId ?? jobs.first?.id ?? UUID() },
            set: { selectedJobId = $0 }
        )
    }

    private func jobPickerLabel(_ job: SimpleStudioEntry) -> String {
        let label = job.jobLabel?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let style = job.resolvedPayStyle == .byTheHour ? " · hourly" : ""
        if !label.isEmpty { return label + style }
        let customer = job.customerName.trimmingCharacters(in: .whitespacesAndNewlines)
        return (customer.isEmpty ? "Job" : customer) + style
    }

    private func hydrateFromSession() {
        if let session = timer.session, session.isSimpleJobSession {
            selectedJobId = session.projectId
            notes = session.notes
        } else if let first = jobs.first?.id {
            selectedJobId = first
        }
        refreshElapsed()
    }

    private func syncNotesToController() {
        timer.updateNotes(notes)
    }

    private func refreshElapsed() {
        displayElapsed = timer.session?.isSimpleJobSession == true ? timer.displayElapsed : 0
    }

    private func toggleTimer() {
        guard let jobId = selectedJobId ?? jobs.first?.id else { return }
        selectedJobId = jobId
        timer.refreshSimpleJobPlanFromStore()
        timer.toggleRunning(simpleJobId: jobId, simpleStore: simpleStore)
        refreshElapsed()
    }
}
