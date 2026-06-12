//
//  StudioProjectPlannerEngine.swift
//  BuxMuse
//
//  On-device project planner: health score, timeline, scope & time alerts.
//

import Foundation

public struct StudioPlannerTimelineSegment: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let label: String
    public let start: Date
    public let end: Date
    public let kind: Kind

    public enum Kind: String, Sendable {
        case elapsed
        case planned
        case milestone
    }

    public var duration: TimeInterval { max(0, end.timeIntervalSince(start)) }
}

public struct StudioPlannerMilestone: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let title: String
    public let date: Date
    public var isPast: Bool
}

public struct StudioPlannerAlert: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let detail: String
    public let severity: Severity

    public enum Severity: String, Sendable {
        case info, warning, critical
    }
}

public struct StudioProjectPlannerSnapshot: Equatable, Sendable {
    public var healthScore: Int
    public var healthLabel: String
    public var timelineStart: Date
    public var timelineEnd: Date
    public var nowProgress: Double
    public var segments: [StudioPlannerTimelineSegment]
    public var milestones: [StudioPlannerMilestone]
    public var alerts: [StudioPlannerAlert]
    public var budgetHoursUsed: Double
    public var budgetHoursTotal: Double
    public var predictedHoursToComplete: Double?
    public var isUnderpriced: Bool
    public var underpricingNote: String?
}

public enum StudioProjectPlannerEngine {

    public static func snapshot(
        project: StudioProject,
        receipts: [StudioReceipt],
        agreement: AgreementDraft?,
        profile: StudioProfile,
        locale: Locale = BuxInterfaceLocale.currentInterfaceLocale
    ) -> StudioProjectPlannerSnapshot {
        let analysis = StudioProjectEngine.analyzeProject(project: project, receipts: receipts)
        let loggedHours = analysis.totalTime / 3600.0
        let billableHours = analysis.billableTime / 3600.0
        let nonBillableHours = max(0, loggedHours - billableHours)

        var alerts: [StudioPlannerAlert] = []
        var health = 88.0

        if project.budgetedHours > 0 {
            let ratio = loggedHours / project.budgetedHours
            if ratio >= 1.0 {
                alerts.append(.init(
                    id: "scope",
                    title: StudioPlannerL10n.line("Scope creep", locale: locale),
                    detail: StudioPlannerL10n.format(
                        "%.1fh over the %.1fh budget.",
                        locale: locale,
                        loggedHours - project.budgetedHours,
                        project.budgetedHours
                    ),
                    severity: .critical
                ))
                health -= 28
            } else if ratio >= 0.9 {
                alerts.append(.init(
                    id: "scope-warn",
                    title: StudioPlannerL10n.line("Scope budget tight", locale: locale),
                    detail: StudioPlannerL10n.format(
                        "%.1fh left in scope.",
                        locale: locale,
                        max(0, project.budgetedHours - loggedHours)
                    ),
                    severity: .warning
                ))
                health -= 12
            }
        }

        if project.allowedRevisions > 0, project.currentRevisions > project.allowedRevisions {
            alerts.append(.init(
                id: "revisions",
                title: StudioPlannerL10n.line("Extra revisions", locale: locale),
                detail: StudioPlannerL10n.format(
                    "%lld revision(s) beyond agreement.",
                    locale: locale,
                    Int64(project.currentRevisions - project.allowedRevisions)
                ),
                severity: .warning
            ))
            health -= 10
        }

        if loggedHours >= 2, nonBillableHours / loggedHours >= 0.2 {
            alerts.append(.init(
                id: "leakage",
                title: StudioPlannerL10n.line("Time leakage", locale: locale),
                detail: StudioPlannerL10n.format(
                    "%.1fh logged as non-billable — check if that time should be invoiced.",
                    locale: locale,
                    nonBillableHours
                ),
                severity: .warning
            ))
            health -= 14
        }

        if analysis.isOverrunRisk {
            alerts.append(.init(
                id: "overrun",
                title: StudioPlannerL10n.line("Fixed-fee overrun", locale: locale),
                detail: StudioPlannerL10n.line(
                    "Hours on a fixed project are high relative to fee — effective rate may be dropping.",
                    locale: locale
                ),
                severity: .warning
            ))
            health -= 10
        }

        var underpricingNote: String?
        var isUnderpriced = false
        if let defaultRate = profile.defaultHourlyRate, defaultRate > 0,
           analysis.effectiveHourlyRate > 0,
           analysis.effectiveHourlyRate < defaultRate * Decimal(0.85) {
            isUnderpriced = true
            underpricingNote = StudioPlannerL10n.format(
                "Effective %@/hr is below your default %@/hr.",
                locale: locale,
                "\(analysis.effectiveHourlyRate)",
                "\(defaultRate)"
            )
            alerts.append(.init(
                id: "rate",
                title: StudioPlannerL10n.line("Underpricing signal", locale: locale),
                detail: underpricingNote!,
                severity: .warning
            ))
            health -= 12
        }

        for milestone in project.plannerMilestones where !milestone.isCompleted {
            if let depId = milestone.dependsOnMilestoneId,
               let parent = project.plannerMilestones.first(where: { $0.id == depId }),
               !parent.isCompleted,
               milestone.dueDate < parent.dueDate {
                alerts.append(.init(
                    id: "dep-\(milestone.id.uuidString)",
                    title: StudioPlannerL10n.line("Dependency order", locale: locale),
                    detail: StudioPlannerL10n.format(
                        "\"%@\" is scheduled before \"%@\" completes.",
                        locale: locale,
                        milestone.title,
                        parent.title
                    ),
                    severity: .warning
                ))
                health -= 5
            }
        }

        if let agreement, agreement.hasClientApprovalProof {
            health += 6
        } else if agreement != nil {
            alerts.append(.init(
                id: "approval",
                title: StudioPlannerL10n.line("Client approval pending", locale: locale),
                detail: StudioPlannerL10n.line(
                    "Agreement exists but client proof is not recorded yet.",
                    locale: locale
                ),
                severity: .info
            ))
            health -= 4
        }

        let predictedHours: Double? = {
            guard project.budgetedHours > 0, loggedHours > 0, loggedHours < project.budgetedHours else { return nil }
            return project.budgetedHours - loggedHours
        }()

        let timeline = buildTimeline(project: project, loggedHours: loggedHours, predictedExtra: predictedHours, locale: locale)
        let milestones = buildMilestones(project: project, locale: locale)
        let progress = progressAlongTimeline(now: Date(), start: timeline.start, end: timeline.end)

        let score = Int(min(100, max(0, health.rounded())))
        let label = healthLabel(for: score, locale: locale)

        return StudioProjectPlannerSnapshot(
            healthScore: score,
            healthLabel: label,
            timelineStart: timeline.start,
            timelineEnd: timeline.end,
            nowProgress: progress,
            segments: timeline.segments,
            milestones: milestones,
            alerts: alerts,
            budgetHoursUsed: loggedHours,
            budgetHoursTotal: project.budgetedHours,
            predictedHoursToComplete: predictedHours,
            isUnderpriced: isUnderpriced,
            underpricingNote: underpricingNote
        )
    }

    private static func healthLabel(for score: Int, locale: Locale) -> String {
        let key: String = switch score {
        case 80...: "Healthy"
        case 60..<80: "Watch"
        case 40..<60: "At risk"
        default: "Critical"
        }
        return StudioPlannerL10n.line(key, locale: locale)
    }

    private static func buildTimeline(
        project: StudioProject,
        loggedHours: Double,
        predictedExtra: Double?,
        locale: Locale
    ) -> (start: Date, end: Date, segments: [StudioPlannerTimelineSegment]) {
        let start = project.startDate
        var end = project.endDate ?? Date().addingTimeInterval(14 * 86_400)
        if let latestMilestone = project.plannerMilestones.map(\.dueDate).max(),
           latestMilestone > end {
            end = latestMilestone
        }
        if project.budgetedHours > 0, loggedHours > 0 {
            let daysUsed = max(1, Date().timeIntervalSince(start) / 86_400)
            let hoursPerDay = loggedHours / daysUsed
            if hoursPerDay > 0, let extra = predictedExtra, extra > 0 {
                let extraDays = (extra / hoursPerDay) * 86_400
                let projectedEnd = Date().addingTimeInterval(extraDays)
                if projectedEnd > end { end = projectedEnd }
            }
        }

        var segments: [StudioPlannerTimelineSegment] = []
        let elapsedEnd = min(Date(), end)
        if elapsedEnd > start {
            segments.append(
                StudioPlannerTimelineSegment(
                    id: UUID(),
                    label: StudioPlannerL10n.line("Elapsed", locale: locale),
                    start: start,
                    end: elapsedEnd,
                    kind: .elapsed
                )
            )
        }
        if end > elapsedEnd {
            segments.append(
                StudioPlannerTimelineSegment(
                    id: UUID(),
                    label: StudioPlannerL10n.line("Planned", locale: locale),
                    start: elapsedEnd,
                    end: end,
                    kind: .planned
                )
            )
        }

        for milestone in project.plannerMilestones.sorted(by: { $0.dueDate < $1.dueDate }) {
            let day: TimeInterval = 86_400
            let segStart = milestone.dueDate.addingTimeInterval(-day / 2)
            segments.append(
                StudioPlannerTimelineSegment(
                    id: milestone.id,
                    label: milestone.title,
                    start: segStart,
                    end: segStart.addingTimeInterval(day),
                    kind: .milestone
                )
            )
        }

        if project.plannerMilestones.isEmpty,
           !project.plannedDeliverables.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let mid = start.addingTimeInterval(end.timeIntervalSince(start) * 0.55)
            segments.append(
                StudioPlannerTimelineSegment(
                    id: UUID(),
                    label: StudioPlannerL10n.line("Deliverables", locale: locale),
                    start: mid,
                    end: mid.addingTimeInterval(86_400),
                    kind: .milestone
                )
            )
        }

        return (start, end, segments)
    }

    private static func buildMilestones(project: StudioProject, locale: Locale) -> [StudioPlannerMilestone] {
        let now = Date()
        if !project.plannerMilestones.isEmpty {
            return project.plannerMilestones
                .sorted { $0.dueDate < $1.dueDate }
                .map { milestone in
                    StudioPlannerMilestone(
                        id: milestone.id,
                        title: milestone.title,
                        date: milestone.dueDate,
                        isPast: milestone.isCompleted || milestone.dueDate < now
                    )
                }
        }

        var items: [StudioPlannerMilestone] = [
            .init(
                id: UUID(),
                title: StudioPlannerL10n.line("Kickoff", locale: locale),
                date: project.startDate,
                isPast: project.startDate < now
            )
        ]
        if project.budgetedHours > 0 {
            let mid = project.startDate.addingTimeInterval(7 * 86_400)
            items.append(.init(
                id: UUID(),
                title: StudioPlannerL10n.line("Scope checkpoint", locale: locale),
                date: mid,
                isPast: mid < now
            ))
        }
        if let end = project.endDate {
            items.append(.init(
                id: UUID(),
                title: StudioPlannerL10n.line("Delivery", locale: locale),
                date: end,
                isPast: end < now
            ))
        } else if project.budgetedHours > 0 {
            let est = project.startDate.addingTimeInterval(Double(project.budgetedHours) * 3_600)
            items.append(.init(
                id: UUID(),
                title: StudioPlannerL10n.line("Target delivery", locale: locale),
                date: est,
                isPast: est < now
            ))
        }
        let deliverable = project.plannedDeliverables.trimmingCharacters(in: .whitespacesAndNewlines)
        if !deliverable.isEmpty {
            let label = deliverable.count > 36 ? String(deliverable.prefix(33)) + "…" : deliverable
            items.append(.init(
                id: UUID(),
                title: label,
                date: project.endDate ?? project.startDate.addingTimeInterval(10 * 86_400),
                isPast: (project.endDate ?? Date()) < now
            ))
        }
        return items.sorted { $0.date < $1.date }
    }

    private static func progressAlongTimeline(now: Date, start: Date, end: Date) -> Double {
        let span = end.timeIntervalSince(start)
        guard span > 0 else { return 0 }
        return min(1, max(0, now.timeIntervalSince(start) / span))
    }
}
