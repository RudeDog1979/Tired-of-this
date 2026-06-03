//
//  StudioTimerController.swift
//  BuxMuse
//
//  Single source of truth for the Studio log-time stopwatch + Live Activity sync.
//

import Combine
import Foundation

@MainActor
final class StudioTimerController: ObservableObject {
    static let shared = StudioTimerController()

    @Published private(set) var session: StudioTimerSession?
    @Published private(set) var jobAlert: StudioTimerJobAlert = .none

    private let fileName = "studio_timer_session.json"
    private var store: StudioStore?
    private var simpleStore: SimpleStudioStore?
    private var notesLiveActivitySyncTask: Task<Void, Never>?
    private static let approachingThreshold = 0.90

    private init() {
        load()
        evaluateJobMilestones()
    }

    func attach(store: StudioStore) {
        self.store = store
        syncLiveActivity()
        evaluateJobMilestones()
    }

    func attach(simpleStore: SimpleStudioStore) {
        self.simpleStore = simpleStore
        syncLiveActivity()
    }

    func attach(studioStore: StudioStore, simpleStore: SimpleStudioStore) {
        self.store = studioStore
        self.simpleStore = simpleStore
        syncLiveActivity()
        evaluateJobMilestones()
    }

    private func resolvedDisplayName() -> String {
        guard let session else { return "Studio" }
        if session.isSimpleJobSession {
            if let job = simpleStore?.entry(id: session.projectId) {
                let label = job.jobLabel?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if !label.isEmpty { return label }
                let customer = job.customerName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !customer.isEmpty { return customer }
            }
            return "Job"
        }
        return store?.projects.first(where: { $0.id == session.projectId })?.name ?? "Studio"
    }

    var hasActiveSession: Bool {
        session?.hasActiveWork == true
    }

    var displayElapsed: TimeInterval {
        session?.elapsed() ?? 0
    }

    var isRunning: Bool {
        session?.isRunning == true
    }

    var estimateLocked: Bool {
        session?.estimateLocked == true
    }

    func bindExistingSession() -> StudioTimerSession? {
        session
    }

    func startOrResume(simpleJobId: UUID, simpleStore: SimpleStudioStore) {
        self.simpleStore = simpleStore
        startOrResumeTarget(
            targetId: simpleJobId,
            isSimpleJob: true,
            studioStore: store
        )
    }

    func startOrResume(projectId: UUID, store: StudioStore) {
        self.store = store
        startOrResumeTarget(
            targetId: projectId,
            isSimpleJob: false,
            studioStore: store
        )
    }

    private func startOrResumeTarget(
        targetId: UUID,
        isSimpleJob: Bool,
        studioStore: StudioStore?
    ) {
        if let studioStore { self.store = studioStore }
        let now = Date()
        var didStart = false

        if var existing = session, existing.projectId == targetId, existing.isSimpleJobSession == isSimpleJob {
            if isSimpleJob { mergeSimpleJobPlan(into: &existing, jobId: targetId) }
            if !existing.isRunning {
                existing.segmentStart = now
                existing.isRunning = true
                if existing.hasJobEstimate, existing.estimatedDuration > 0 {
                    existing.estimateLocked = true
                }
                session = existing
                persist()
                didStart = true
            }
            syncLiveActivity()
            evaluateJobMilestones()
            StudioTimerDisplayMonitor.shared.handleTimerRunningStateChanged()
            return
        }

        if var existing = session, existing.hasActiveWork {
            if !existing.isRunning {
                existing.segmentStart = now
                existing.isRunning = true
                if existing.hasJobEstimate, existing.estimatedDuration > 0 {
                    existing.estimateLocked = true
                }
                session = existing
                persist()
                didStart = true
            }
            syncLiveActivity()
            if didStart { evaluateJobMilestones() }
            StudioTimerDisplayMonitor.shared.handleTimerRunningStateChanged()
            return
        }

        var fresh = StudioTimerSession(
            projectId: targetId,
            isSimpleJobSession: isSimpleJob,
            segmentStart: now,
            isRunning: true,
            sessionStartedAt: now
        )
        if isSimpleJob {
            mergeSimpleJobPlan(into: &fresh, jobId: targetId)
        }
        session = fresh
        persist()
        syncLiveActivity()
        evaluateJobMilestones()
        StudioTimerDisplayMonitor.shared.handleTimerRunningStateChanged()
    }

    /// Applies quoted planned time from a Simple job (walker on Lock Screen, optional auto-pause).
    private func mergeSimpleJobPlan(into session: inout StudioTimerSession, jobId: UUID) {
        guard session.isSimpleJobSession,
              !session.estimateLocked,
              let job = simpleStore?.entry(id: jobId),
              job.kind == .job,
              let plan = StudioWorkClockPlanEngine.normalizedPlan(job.plannedWorkSeconds) else { return }
        session.hasJobEstimate = true
        session.estimatedDuration = plan
        session.planBaselineSeconds = job.loggedSeconds ?? 0
        session.autoPauseAtPlanEnd = job.resolvedPauseWhenPlanEnds
    }

    func refreshSimpleJobPlanFromStore() {
        guard var current = session,
              current.isSimpleJobSession,
              !current.estimateLocked else { return }
        mergeSimpleJobPlan(into: &current, jobId: current.projectId)
        session = current
        persist()
        syncLiveActivity()
        evaluateJobMilestones()
    }

    func pause() {
        guard var current = session, current.isRunning, let segmentStart = current.segmentStart else { return }
        current.accumulated += Date().timeIntervalSince(segmentStart)
        current.segmentStart = nil
        current.isRunning = false
        session = current
        persist()
        syncLiveActivity(force: true)
        evaluateJobMilestones()
        StudioTimerDisplayMonitor.shared.handleTimerRunningStateChanged()
    }

    func toggleRunning(projectId: UUID, store: StudioStore) {
        self.store = store
        if session == nil || session?.projectId != projectId || session?.isSimpleJobSession == true {
            startOrResume(projectId: projectId, store: store)
            return
        }
        if session?.isRunning == true {
            pause()
        } else {
            startOrResume(projectId: projectId, store: store)
        }
    }

    func toggleRunning(simpleJobId: UUID, simpleStore: SimpleStudioStore) {
        self.simpleStore = simpleStore
        if session == nil || session?.projectId != simpleJobId || session?.isSimpleJobSession != true {
            startOrResume(simpleJobId: simpleJobId, simpleStore: simpleStore)
            return
        }
        if session?.isRunning == true {
            pause()
        } else {
            startOrResume(simpleJobId: simpleJobId, simpleStore: simpleStore)
        }
    }

    func reset() {
        session = nil
        jobAlert = .none
        persist()
        StudioTimerLiveActivityManager.endAll()
        StudioTimerNotificationScheduler.cancelAll()
        StudioTimerDisplayMonitor.shared.handleTimerRunningStateChanged()
    }

    func recordLap() {
        guard var current = session else { return }
        current.laps.append(current.elapsed())
        session = current
        persist()
    }

    func updateNotes(_ notes: String) {
        guard var current = session else { return }
        current.notes = notes
        session = current
        persist()
        scheduleDebouncedLiveActivitySync()
    }

    /// Locks the job-time estimate when the stopwatch is running (after sheet draft is applied).
    func lockEstimateIfRunning() {
        guard var current = session,
              current.isRunning,
              current.hasJobEstimate,
              current.estimatedDuration > 0,
              !current.estimateLocked else { return }
        current.estimateLocked = true
        session = current
        persist()
        evaluateJobMilestones()
    }

    func updateBillable(_ value: Bool) {
        guard var current = session else { return }
        current.isBillable = value
        session = current
        persist()
    }

    func updateProjectId(_ id: UUID) {
        guard var current = session, !current.isSimpleJobSession else { return }
        current.projectId = id
        session = current
        persist()
        syncLiveActivity()
    }

    func updateSimpleJobId(_ id: UUID) {
        guard var current = session, current.isSimpleJobSession else { return }
        current.projectId = id
        mergeSimpleJobPlan(into: &current, jobId: id)
        session = current
        persist()
        syncLiveActivity()
        evaluateJobMilestones()
    }

    func setJobEstimate(enabled: Bool, duration: TimeInterval, autoPauseAtEnd: Bool? = nil) {
        guard var current = session else { return }
        guard !current.estimateLocked else { return }
        current.hasJobEstimate = enabled
        current.estimatedDuration = enabled ? max(StudioWorkClockPlanEngine.minimumPlanSeconds, duration) : 0
        if !enabled {
            current.planBaselineSeconds = 0
            current.notifiedApproaching = false
            current.notifiedAtGoal = false
        } else if !current.isSimpleJobSession {
            current.planBaselineSeconds = 0
        }
        if let autoPauseAtEnd {
            current.autoPauseAtPlanEnd = autoPauseAtEnd
        }
        session = current
        persist()
        syncLiveActivity()
        evaluateJobMilestones()
    }

    func unlockEstimateForEditing() {
        guard var current = session, current.estimateLocked, !current.isRunning else { return }
        current.estimateLocked = false
        current.notifiedApproaching = false
        current.notifiedAtGoal = false
        session = current
        persist()
        evaluateJobMilestones()
    }

    func extendEstimate(by extra: TimeInterval) {
        guard var current = session, current.hasJobEstimate else { return }
        current.estimatedDuration += max(0, extra)
        let progress = current.progress()
        if progress < Self.approachingThreshold {
            current.notifiedApproaching = false
            current.notifiedAtGoal = false
        } else if progress < 1.0 {
            current.notifiedAtGoal = false
        }
        session = current
        persist()
        syncLiveActivity()
        evaluateJobMilestones()
    }

    func applyFromSheet(
        projectId: UUID,
        notes: String,
        isBillable: Bool,
        hasJobEstimate: Bool,
        estimatedDuration: TimeInterval,
        laps: [TimeInterval]
    ) {
        if var current = session {
            current.projectId = projectId
            current.notes = notes
            current.isBillable = isBillable
            current.laps = laps
            if !current.estimateLocked {
                current.hasJobEstimate = hasJobEstimate
                current.estimatedDuration = hasJobEstimate ? max(60, estimatedDuration) : 0
            }
            session = current
            persist()
            syncLiveActivity()
            lockEstimateIfRunning()
            evaluateJobMilestones()
            return
        }

        if hasJobEstimate || !notes.isEmpty || !laps.isEmpty {
            session = StudioTimerSession(
                projectId: projectId,
                notes: notes,
                isBillable: isBillable,
                laps: laps,
                hasJobEstimate: hasJobEstimate,
                estimatedDuration: hasJobEstimate ? max(60, estimatedDuration) : 0
            )
            persist()
        }
    }

    func evaluateJobMilestones() {
        guard var current = session,
              current.hasJobEstimate,
              current.estimatedDuration > 0 else {
            jobAlert = .none
            return
        }

        let planActive = current.isSimpleJobSession || current.estimateLocked
        guard planActive else {
            jobAlert = .none
            return
        }

        let now = Date()
        let progress = current.progress(at: now)
        let remaining = StudioWorkClockPlanEngine.remaining(
            baseline: current.planBaselineSeconds,
            sessionElapsed: current.elapsed(at: now),
            planTotal: current.estimatedDuration
        )

        let projectName = resolvedDisplayName()
        let jobName = StudioTimerLiveActivityManager.displayJobName(notes: current.notes, projectName: projectName)

        if progress >= Self.approachingThreshold, !current.notifiedApproaching {
            current.notifiedApproaching = true
            let minutesLeft = max(1, Int(ceil(remaining / 60)))
            jobAlert = .approaching(minutesLeft: minutesLeft)
            StudioTimerNotificationScheduler.notifyApproaching(projectName: jobName, minutesLeft: minutesLeft)
            session = current
            persist()
        }

        if progress >= 1.0, !current.notifiedAtGoal {
            current.notifiedAtGoal = true
            jobAlert = .atGoal
            StudioTimerNotificationScheduler.notifyAtGoal(projectName: jobName)
            session = current
            persist()
        } else if current.isOvertime {
            jobAlert = .overtime
        } else if progress >= 1.0 {
            jobAlert = .atGoal
        } else if progress >= Self.approachingThreshold {
            let minutesLeft = max(1, Int(ceil(remaining / 60)))
            jobAlert = .approaching(minutesLeft: minutesLeft)
        } else {
            jobAlert = .none
        }

        if progress >= 1.0,
           session?.isRunning == true,
           session?.autoPauseAtPlanEnd == true {
            pause()
            syncLiveActivity(force: true)
            jobAlert = .atGoal
        }
    }

    @discardableResult
    func logToActiveTarget(studioStore: StudioStore?, simpleStore: SimpleStudioStore?) -> Bool {
        guard let current = session else { return false }
        if current.isSimpleJobSession {
            guard let simpleStore else { return false }
            return logToSimpleJob(simpleStore: simpleStore)
        }
        guard let studioStore else { return false }
        return logToProject(store: studioStore)
    }

    @discardableResult
    func logToSimpleJob(simpleStore: SimpleStudioStore) -> Bool {
        guard var current = session, current.isSimpleJobSession else { return false }
        if current.isRunning, let segmentStart = current.segmentStart {
            current.accumulated += Date().timeIntervalSince(segmentStart)
            current.segmentStart = nil
            current.isRunning = false
        }

        let duration = current.elapsed()
        guard duration > 0 else { return false }

        simpleStore.appendLoggedTime(
            jobEntryId: current.projectId,
            duration: duration,
            sessionNote: current.notes
        )

        session = nil
        jobAlert = .none
        persist()
        StudioTimerLiveActivityManager.endAll()
        StudioTimerNotificationScheduler.cancelAll()
        StudioTimerDisplayMonitor.shared.handleTimerRunningStateChanged()
        return true
    }

    @discardableResult
    func logToProject(store: StudioStore) -> Bool {
        guard var current = session, !current.isSimpleJobSession else { return false }
        if current.isRunning, let segmentStart = current.segmentStart {
            current.accumulated += Date().timeIntervalSince(segmentStart)
            current.segmentStart = nil
            current.isRunning = false
        }

        let duration = current.elapsed()
        guard duration > 0,
              var project = store.projects.first(where: { $0.id == current.projectId }) else {
            return false
        }

        let now = Date()
        let start = now.addingTimeInterval(-duration)
        let entry = StudioTimeEntry(
            projectId: current.projectId,
            startTime: start,
            endTime: now,
            notes: current.notes,
            isBillable: current.isBillable
        )
        project.timeEntries.append(entry)
        store.updateProject(project)

        session = nil
        jobAlert = .none
        persist()
        StudioTimerLiveActivityManager.endAll()
        StudioTimerNotificationScheduler.cancelAll()
        StudioTimerDisplayMonitor.shared.handleTimerRunningStateChanged()
        return true
    }

    @discardableResult
    func finishEarly(store: StudioStore) -> Bool {
        logToProject(store: store)
    }

    @discardableResult
    func finishEarly(simpleStore: SimpleStudioStore) -> Bool {
        logToSimpleJob(simpleStore: simpleStore)
    }

    func refreshLiveActivity() {
        evaluateJobMilestones()
        syncLiveActivity(force: false)
    }

    /// Catch up Live Activity UI after unlock / foreground (smooth jump to true elapsed & progress).
    func syncLiveActivityOnForeground() {
        evaluateJobMilestones()
        StudioTimerLiveActivityManager.syncOnForeground(session: session, projectName: resolvedDisplayName())
    }

    private func scheduleDebouncedLiveActivitySync() {
        notesLiveActivitySyncTask?.cancel()
        notesLiveActivitySyncTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 900_000_000)
            guard !Task.isCancelled else { return }
            syncLiveActivity(force: false)
        }
    }

    // MARK: - Persistence

    private var sessionURL: URL {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("Studio", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir.appendingPathComponent(fileName)
    }

    private func load() {
        let url = sessionURL
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(StudioTimerSession.self, from: data) else {
            session = nil
            return
        }
        session = decoded
        if decoded.isRunning, decoded.segmentStart == nil {
            var fixed = decoded
            fixed.segmentStart = Date()
            session = fixed
            persist()
        }
    }

    private func persist() {
        let url = sessionURL
        if let session {
            if let data = try? JSONEncoder().encode(session) {
                try? data.write(to: url, options: .atomic)
            }
        } else {
            try? FileManager.default.removeItem(at: url)
        }
        objectWillChange.send()
    }

    private func syncLiveActivity(force: Bool = false) {
        StudioTimerLiveActivityManager.sync(
            session: session,
            projectName: resolvedDisplayName(),
            force: force
        )
    }
}
