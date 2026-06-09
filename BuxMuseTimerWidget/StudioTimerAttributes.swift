//
//  StudioTimerAttributes.swift
//  BuxMuseTimerWidget
//
//  Keep in sync with BuxMuse/Features/Studio/Timer/StudioTimerAttributes.swift
//

import ActivityKit
import Foundation

nonisolated struct StudioTimerAttributes: ActivityAttributes, Sendable {
    struct ContentState: Codable, Hashable, Sendable {
        var accumulated: TimeInterval
        var segmentStart: Date?
        var isRunning: Bool
        var isPaused: Bool
        var hasEstimate: Bool
        var estimatedDuration: TimeInterval
        var planBaselineSeconds: TimeInterval
        var progress: Double
        var isOvertime: Bool
        var jobName: String?
    }

    var projectName: String
    var sessionStart: Date
}
