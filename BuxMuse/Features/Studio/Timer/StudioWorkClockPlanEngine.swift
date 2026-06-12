//
//  StudioWorkClockPlanEngine.swift
//  BuxMuse
//
//  Shared planned-time math for Simple + Pro work clock and Live Activity progress.
//

import Foundation

enum StudioWorkClockPlanEngine {
    static let minimumPlanSeconds: TimeInterval = 60

    static func normalizedPlan(_ seconds: TimeInterval?) -> TimeInterval? {
        guard let seconds, seconds >= minimumPlanSeconds else { return nil }
        return seconds
    }

    static func duration(hours: Int, minutes: Int) -> TimeInterval {
        TimeInterval(max(0, hours) * 3600 + max(0, minutes) * 60)
    }

    static func split(_ duration: TimeInterval) -> (hours: Int, minutes: Int) {
        let totalMins = max(0, Int(duration / 60))
        return (totalMins / 60, totalMins % 60)
    }

    static func trackedElapsed(
        baseline: TimeInterval,
        sessionElapsed: TimeInterval
    ) -> TimeInterval {
        max(0, baseline) + max(0, sessionElapsed)
    }

    static func progress(
        baseline: TimeInterval,
        sessionElapsed: TimeInterval,
        planTotal: TimeInterval
    ) -> Double {
        guard planTotal > 0 else { return 0 }
        return trackedElapsed(baseline: baseline, sessionElapsed: sessionElapsed) / planTotal
    }

    static func isOvertime(
        baseline: TimeInterval,
        sessionElapsed: TimeInterval,
        planTotal: TimeInterval
    ) -> Bool {
        guard planTotal > 0 else { return false }
        return trackedElapsed(baseline: baseline, sessionElapsed: sessionElapsed) > planTotal
    }

    static func remaining(
        baseline: TimeInterval,
        sessionElapsed: TimeInterval,
        planTotal: TimeInterval
    ) -> TimeInterval {
        guard planTotal > 0 else { return 0 }
        return max(0, planTotal - trackedElapsed(baseline: baseline, sessionElapsed: sessionElapsed))
    }
}

extension SimpleStudioEntry {
    /// How long the customer expects the job to take (drives lock-screen progress + optional auto-pause).
    public var resolvedPauseWhenPlanEnds: Bool {
        pauseWhenPlanEnds ?? true
    }

    public var hasWorkPlan: Bool {
        StudioWorkClockPlanEngine.normalizedPlan(plannedWorkSeconds) != nil
    }

    public var plannedTimeLabel: String? {
        guard let plan = StudioWorkClockPlanEngine.normalizedPlan(plannedWorkSeconds) else { return nil }
        return StudioTimerSession.formattedDuration(plan)
    }
}
