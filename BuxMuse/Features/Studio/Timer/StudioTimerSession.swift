//
//  StudioTimerSession.swift
//  BuxMuse
//
//  Persisted Studio log-time session (survives background / app termination).
//

import Foundation

struct StudioTimerSession: Codable, Equatable {
    var projectId: UUID
    var notes: String
    var isBillable: Bool
    var accumulated: TimeInterval
    var segmentStart: Date?
    var isRunning: Bool
    var laps: [TimeInterval]
    var hasJobEstimate: Bool
    var estimatedDuration: TimeInterval
    var sessionStartedAt: Date
    var estimateLocked: Bool
    var notifiedApproaching: Bool
    var notifiedAtGoal: Bool

    init(
        projectId: UUID,
        notes: String = "",
        isBillable: Bool = true,
        accumulated: TimeInterval = 0,
        segmentStart: Date? = nil,
        isRunning: Bool = false,
        laps: [TimeInterval] = [],
        hasJobEstimate: Bool = false,
        estimatedDuration: TimeInterval = 0,
        sessionStartedAt: Date = Date(),
        estimateLocked: Bool = false,
        notifiedApproaching: Bool = false,
        notifiedAtGoal: Bool = false
    ) {
        self.projectId = projectId
        self.notes = notes
        self.isBillable = isBillable
        self.accumulated = accumulated
        self.segmentStart = segmentStart
        self.isRunning = isRunning
        self.laps = laps
        self.hasJobEstimate = hasJobEstimate
        self.estimatedDuration = estimatedDuration
        self.sessionStartedAt = sessionStartedAt
        self.estimateLocked = estimateLocked
        self.notifiedApproaching = notifiedApproaching
        self.notifiedAtGoal = notifiedAtGoal
    }

    enum CodingKeys: String, CodingKey {
        case projectId, notes, isBillable, accumulated, segmentStart, isRunning, laps
        case hasJobEstimate, estimatedDuration, sessionStartedAt
        case estimateLocked, notifiedApproaching, notifiedAtGoal
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        projectId = try c.decode(UUID.self, forKey: .projectId)
        notes = try c.decode(String.self, forKey: .notes)
        isBillable = try c.decode(Bool.self, forKey: .isBillable)
        accumulated = try c.decode(TimeInterval.self, forKey: .accumulated)
        segmentStart = try c.decodeIfPresent(Date.self, forKey: .segmentStart)
        isRunning = try c.decode(Bool.self, forKey: .isRunning)
        laps = try c.decode([TimeInterval].self, forKey: .laps)
        hasJobEstimate = try c.decode(Bool.self, forKey: .hasJobEstimate)
        estimatedDuration = try c.decode(TimeInterval.self, forKey: .estimatedDuration)
        sessionStartedAt = try c.decode(Date.self, forKey: .sessionStartedAt)
        estimateLocked = try c.decodeIfPresent(Bool.self, forKey: .estimateLocked) ?? false
        notifiedApproaching = try c.decodeIfPresent(Bool.self, forKey: .notifiedApproaching) ?? false
        notifiedAtGoal = try c.decodeIfPresent(Bool.self, forKey: .notifiedAtGoal) ?? false
    }

    var hasActiveWork: Bool {
        isRunning
            || accumulated > 0
            || !laps.isEmpty
            || (hasJobEstimate && estimatedDuration > 0)
            || !notes.isEmpty
    }

    func elapsed(at date: Date = Date()) -> TimeInterval {
        var total = accumulated
        if isRunning, let segmentStart {
            total += date.timeIntervalSince(segmentStart)
        }
        return max(0, total)
    }

    func progress(at date: Date = Date()) -> Double {
        guard hasJobEstimate, estimatedDuration > 0 else { return 0 }
        return elapsed(at: date) / estimatedDuration
    }

    var isOvertime: Bool {
        hasJobEstimate && estimatedDuration > 0 && elapsed() > estimatedDuration
    }

    var isUnderEstimate: Bool {
        hasJobEstimate && estimatedDuration > 0 && elapsed() < estimatedDuration
    }

    static func formattedDuration(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval))
        let hours = total / 3600
        let mins = (total % 3600) / 60
        if hours > 0, mins > 0 { return "\(hours)h \(mins)m" }
        if hours > 0 { return "\(hours)h" }
        return "\(max(1, mins))m"
    }
}

enum StudioTimerJobAlert: Equatable {
    case none
    case approaching(minutesLeft: Int)
    case atGoal
    case overtime
}

extension StudioTimerSession {
    static func formattedElapsed(_ interval: TimeInterval, style: StudioTimerFormatStyle = .hub) -> String {
        let total = max(0, Int(interval))
        let hours = total / 3600
        let mins = (total % 3600) / 60
        let secs = total % 60
        switch style {
        case .hub:
            if hours > 0 {
                return String(format: "%d:%02d:%02d", hours, mins, secs)
            }
            return String(format: "%02d:%02d", mins, secs)
        case .stopwatch:
            let cs = Int((interval.truncatingRemainder(dividingBy: 1)) * 100)
            if hours > 0 {
                return String(format: "%d:%02d:%02d.%02d", hours, mins, secs, cs)
            }
            return String(format: "%02d:%02d.%02d", mins, secs, cs)
        }
    }
}

enum StudioTimerFormatStyle {
    case hub
    case stopwatch
}
