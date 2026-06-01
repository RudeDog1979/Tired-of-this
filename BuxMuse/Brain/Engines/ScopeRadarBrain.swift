//
//  ScopeRadarBrain.swift
//  BuxMuse
//  Brain/Engines/
//
//  Scope creep analysis engine. Compares consumed hours & revision count against
//  project-defined budgets. All calculations happen locally. Zero network.
//

import Foundation
import Combine

// MARK: - Scope Radar Analysis Result

/// Outcome produced by the Scope Radar engine for a single studio project.
public struct ScopeRadarAnalysis {

    // MARK: Inputs
    public let budgetedHours: Double
    public let loggedHours: Double
    public let allowedRevisions: Int
    public let currentRevisions: Int

    // MARK: Derived

    /// 0.0 ... 1.0+ — fraction of budgeted hours consumed. >1 means over budget.
    public var hoursRatio: Double {
        guard budgetedHours > 0 else { return 0 }
        return loggedHours / budgetedHours
    }

    /// Remaining hours. Negative = over budget.
    public var remainingHours: Double { budgetedHours - loggedHours }

    /// 0.0 ... 1.0+ — fraction of revision slots consumed.
    public var revisionsRatio: Double {
        guard allowedRevisions > 0 else { return 0 }
        return Double(currentRevisions) / Double(allowedRevisions)
    }

    public var isHoursOverBudget: Bool { hoursRatio >= 1.0 }
    public var isRevisionsOver: Bool { currentRevisions > allowedRevisions }
    public var isAnyAlertActive: Bool { isHoursOverBudget || isRevisionsOver }

    public var overallRisk: ScopeRiskLevel {
        let maxRatio = max(hoursRatio, revisionsRatio)
        switch maxRatio {
        case ..<0.70: return .green
        case 0.70..<0.90: return .yellow
        case 0.90..<1.0: return .orange
        default: return .red
        }
    }

    // MARK: Templates

    /// Generates a professional scope change notification email body.
    public func scopeChangeEmail(projectName: String, clientName: String) -> String {
        let hoursOver = max(0, loggedHours - budgetedHours)
        let revOver = max(0, currentRevisions - allowedRevisions)
        return """
        Subject: Scope Change Notice — \(projectName)

        Hi \(clientName),

        I'm writing to flag that work on \(projectName) has exceeded our original agreement:

        • Budgeted Hours: \(String(format: "%.1f", budgetedHours)) hrs | Logged: \(String(format: "%.1f", loggedHours)) hrs (\(String(format: "+%.1f", hoursOver)) over)
        • Included Revisions: \(allowedRevisions) | Used: \(currentRevisions) (\(revOver > 0 ? "+\(revOver) over" : "within scope"))

        Any additional time will be billed at our agreed hourly rate. I'd be happy to discuss adjusting the project scope or timeline.

        Please reply to confirm how you'd like to proceed.

        Best,
        [Your Name]
        """
    }

    /// Generates a concise scope warning message for in-app display.
    public func warningBannerText(projectName: String) -> String {
        var parts: [String] = []
        if isHoursOverBudget {
            parts.append("\(String(format: "%.1f", loggedHours - budgetedHours))h over budget")
        }
        if isRevisionsOver {
            parts.append("\(currentRevisions - allowedRevisions) extra revision(s)")
        }
        if parts.isEmpty { return "" }
        return "⚠️ \(projectName): " + parts.joined(separator: " · ")
    }
}

// MARK: - Risk Level

public enum ScopeRiskLevel: String {
    case green  = "On Track"
    case yellow = "Approaching Limit"
    case orange = "Near Threshold"
    case red    = "Over Budget"

    public var color: String {
        switch self {
        case .green:  return "#34C759"
        case .yellow: return "#FFCC00"
        case .orange: return "#FF9500"
        case .red:    return "#FF3B30"
        }
    }

    public var systemIcon: String {
        switch self {
        case .green:  return "checkmark.circle.fill"
        case .yellow: return "exclamationmark.circle.fill"
        case .orange: return "exclamationmark.triangle.fill"
        case .red:    return "xmark.octagon.fill"
        }
    }
}

// MARK: - Brain

/// Singleton engine for scope creep calculations.
public final class ScopeRadarBrain {

    public static let shared = ScopeRadarBrain()
    private init() {}

    /// Analyzes a project's scope utilisation given time log and revision state.
    public func analyze(
        budgetedHours: Double,
        loggedHours: Double,
        allowedRevisions: Int,
        currentRevisions: Int
    ) -> ScopeRadarAnalysis {
        ScopeRadarAnalysis(
            budgetedHours: budgetedHours,
            loggedHours: loggedHours,
            allowedRevisions: allowedRevisions,
            currentRevisions: currentRevisions
        )
    }
}
