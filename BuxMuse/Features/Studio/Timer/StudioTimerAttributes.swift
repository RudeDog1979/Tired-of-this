//
//  StudioTimerAttributes.swift
//  BuxMuse
//
//  ActivityKit attributes — keep in sync with BuxMuseTimerWidget/StudioTimerAttributes.swift
//

import ActivityKit
import Foundation

/// ActivityKit reads attributes from concurrent contexts — must not inherit default `@MainActor` isolation.
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
        /// Task label from Log Time; nil on older activities — UI falls back to project name.
        var jobName: String?
    }

    var projectName: String
    var sessionStart: Date
}
