//
//  StudioTimerAttributes.swift
//  BuxMuseTimerWidget
//
//  Keep in sync with BuxMuse/Features/Studio/Timer/StudioTimerAttributes.swift
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
        var jobName: String?
    }

    var projectName: String
    var sessionStart: Date
}
