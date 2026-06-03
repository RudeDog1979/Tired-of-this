//
//  StudioTimerLiveMetrics.swift
//  BuxMuseTimerWidget
//
//  Lightweight elapsed/progress math for Live Activity UI (no app updates while locked).
//

import Foundation

enum StudioTimerLiveMetrics {
    static func elapsed(
        accumulated: TimeInterval,
        segmentStart: Date?,
        isRunning: Bool,
        at date: Date = Date()
    ) -> TimeInterval {
        var total = max(0, accumulated)
        if isRunning, let segmentStart {
            total += date.timeIntervalSince(segmentStart)
        }
        return total
    }

    static func progress(
        accumulated: TimeInterval,
        segmentStart: Date?,
        isRunning: Bool,
        hasEstimate: Bool,
        estimatedDuration: TimeInterval,
        planBaselineSeconds: TimeInterval = 0,
        at date: Date = Date()
    ) -> Double {
        guard hasEstimate, estimatedDuration > 0 else { return 0 }
        let sessionElapsed = elapsed(
            accumulated: accumulated,
            segmentStart: segmentStart,
            isRunning: isRunning,
            at: date
        )
        let tracked = max(0, planBaselineSeconds) + sessionElapsed
        return tracked / estimatedDuration
    }

    static func isOvertime(
        accumulated: TimeInterval,
        segmentStart: Date?,
        isRunning: Bool,
        hasEstimate: Bool,
        estimatedDuration: TimeInterval,
        planBaselineSeconds: TimeInterval = 0,
        at date: Date = Date()
    ) -> Bool {
        guard hasEstimate, estimatedDuration > 0 else { return false }
        let sessionElapsed = elapsed(
            accumulated: accumulated,
            segmentStart: segmentStart,
            isRunning: isRunning,
            at: date
        )
        let tracked = max(0, planBaselineSeconds) + sessionElapsed
        return tracked > estimatedDuration
    }
}
