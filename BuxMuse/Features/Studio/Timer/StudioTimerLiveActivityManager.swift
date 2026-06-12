//
//  StudioTimerLiveActivityManager.swift
//  BuxMuse
//

@preconcurrency import ActivityKit
import Foundation

@MainActor
enum StudioTimerLiveActivityManager {
    private static var currentActivity: Activity<StudioTimerAttributes>?
    /// When false (screen off), skip `Activity.update` while the stopwatch runs.
    private(set) static var displayAwake = true

    static var isSupported: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    static func setDisplayAwake(_ awake: Bool) {
        displayAwake = awake
    }

    @available(*, deprecated, message: "Use setDisplayAwake")
    static func setLiveUpdatesEnabled(_ enabled: Bool) {
        displayAwake = enabled
    }

    static func displayJobName(notes: String, projectName: String) -> String {
        let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        return projectName
    }

    /// Push Live Activity state. Skips running-session pushes while the display is off (unless `force`).
    static func sync(session: StudioTimerSession?, projectName: String, force: Bool = false) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            endAll()
            return
        }

        guard let session, session.hasActiveWork else {
            endAll()
            return
        }

        if !force, !displayAwake, session.isRunning {
            return
        }

        let now = Date()
        let jobName = displayJobName(notes: session.notes, projectName: projectName)
        let state = StudioTimerAttributes.ContentState(
            accumulated: session.accumulated,
            segmentStart: session.segmentStart,
            isRunning: session.isRunning,
            isPaused: !session.isRunning && session.accumulated > 0,
            hasEstimate: session.hasJobEstimate,
            estimatedDuration: session.estimatedDuration,
            planBaselineSeconds: session.planBaselineSeconds,
            progress: session.progress(at: now),
            isOvertime: session.isOvertime,
            jobName: jobName
        )

        if currentActivity == nil {
            currentActivity = Activity<StudioTimerAttributes>.activities.first
        }

        let staleDate = staleDate(for: session, now: now)

        if let activity = currentActivity {
            let content = ActivityContent(state: state, staleDate: staleDate)
            Task {
                await StudioTimerActivityKitGateway.update(activity, content: content)
            }
            return
        }

        let attributes = StudioTimerAttributes(
            projectName: projectName,
            sessionStart: session.sessionStartedAt
        )

        do {
            let content = ActivityContent(state: state, staleDate: staleDate)
            currentActivity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
        } catch {
            print("StudioTimerLiveActivity: request failed \(error)")
        }
    }

    /// Catch-up when the display turns on or the user opens the app (smooth jump to true elapsed & progress).
    static func syncOnForeground(session: StudioTimerSession?, projectName: String) {
        sync(session: session, projectName: projectName, force: true)
    }

    private static func staleDate(for session: StudioTimerSession, now: Date) -> Date? {
        guard session.isRunning else { return nil }

        if session.hasJobEstimate, session.estimatedDuration > 0 {
            let remaining = StudioWorkClockPlanEngine.remaining(
                baseline: session.planBaselineSeconds,
                sessionElapsed: session.elapsed(at: now),
                planTotal: session.estimatedDuration
            )
            if remaining > 1 {
                return now.addingTimeInterval(remaining)
            }
        }

        return nil
    }

    static func endAll() {
        guard let activity = currentActivity else { return }
        currentActivity = nil
        let final = activity.content.state
        let content = ActivityContent(state: final, staleDate: nil)
        Task {
            await StudioTimerActivityKitGateway.end(
                activity,
                content: content,
                dismissalPolicy: .immediate
            )
        }
    }

    static func endAllAsync() async {
        await StudioTimerActivityKitGateway.endAll()
        currentActivity = nil
    }
}
