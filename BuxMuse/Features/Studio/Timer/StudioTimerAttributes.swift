//
//  StudioTimerAttributes.swift
//  BuxMuse
//
//  ActivityKit attributes — keep in sync with BuxMuseTimerWidget/StudioTimerAttributes.swift
//

import ActivityKit
import Foundation

struct StudioTimerAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var accumulated: TimeInterval
        var segmentStart: Date?
        var isRunning: Bool
        var isPaused: Bool
        var hasEstimate: Bool
        var estimatedDuration: TimeInterval
        var progress: Double
        var isOvertime: Bool
        /// Task label from Log Time; nil on older activities — UI falls back to project name.
        var jobName: String?
    }

    var projectName: String
    var sessionStart: Date
}
