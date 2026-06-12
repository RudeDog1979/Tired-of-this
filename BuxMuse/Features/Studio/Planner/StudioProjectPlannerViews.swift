//
//  StudioProjectPlannerViews.swift
//  BuxMuse
//

import SwiftUI

struct StudioProjectPlannerSection: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    let snapshot: StudioProjectPlannerSnapshot
    var projectMilestones: [StudioProjectMilestone] = []
    var customMilestoneCount: Int = 0
    var onEditMilestones: (() -> Void)? = nil
    var onRescheduleMilestone: ((UUID, Date) -> Void)? = nil

    @State private var dragMilestoneId: UUID?

    private var accent: Color { themeManager.contrastAccentColor(for: colorScheme) }

    var body: some View {
        VStack(alignment: .leading, spacing: BuxLayout.tight) {
            HStack(spacing: 6) {
                BuxCatalogDynamicText(key: "PROJECT PLANNER")
                    .font(.system(size: 11, weight: .bold))
                    .buxLabelSecondary()
                ProFeatureBadge(compact: true)
                Spacer()
                if let onEditMilestones {
                    Button(BuxCatalogLabel.string("Milestones", locale: appSettingsManager.interfaceLocale), action: onEditMilestones)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(accent)
                }
            }

            VStack(alignment: .leading, spacing: 14) {
                healthRow
                timelineGantt
                if snapshot.budgetHoursTotal > 0 {
                    budgetRow
                }
                if !snapshot.milestones.isEmpty {
                    milestonesList
                } else if customMilestoneCount == 0, let onEditMilestones {
                    Button(action: onEditMilestones) {
                        Label(
                            BuxCatalogLabel.string("Add planner milestones", locale: appSettingsManager.interfaceLocale),
                            systemImage: "plus.circle"
                        )
                            .font(.system(size: 12, weight: .semibold))
                    }
                }
                if !snapshot.alerts.isEmpty {
                    alertsList
                }
            }
            .padding(BuxLayout.section)
            .studioThemedCardChrome(cornerRadius: 24)
        }
    }

    private var healthRow: some View {
        HStack(alignment: .center, spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: CGFloat(snapshot.healthScore) / 100)
                    .stroke(healthColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(
                    BuxLocalizedString.format(
                        "%lld%%",
                        locale: appSettingsManager.interfaceLocale,
                        snapshot.healthScore
                    )
                )
                    .font(.system(size: 18, weight: .bold, design: .rounded))
            }
            .frame(width: 56, height: 56)

            VStack(alignment: .leading, spacing: 4) {
                Text(
                    BuxLocalizedString.format(
                        "Health · %@",
                        locale: appSettingsManager.interfaceLocale,
                        snapshot.healthLabel
                    )
                )
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                if let note = snapshot.underpricingNote {
                    Text(note)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.orange)
                } else if let predicted = snapshot.predictedHoursToComplete {
                    Text(
                        BuxLocalizedString.format(
                            "~%@h to finish at current pace",
                            locale: appSettingsManager.interfaceLocale,
                            String(format: "%.1f", predicted)
                        )
                    )
                        .font(.system(size: 11, weight: .medium))
                        .buxLabelSecondary()
                }
            }
            Spacer()
        }
    }

    private var healthColor: Color {
        switch snapshot.healthScore {
        case 80...: return .green
        case 60..<80: return .yellow
        case 40..<60: return .orange
        default: return .red
        }
    }

    private var timelineGantt: some View {
        VStack(alignment: .leading, spacing: 8) {
            BuxCatalogDynamicText(key: "Timeline")
                .font(.system(size: 12, weight: .bold))
                .buxLabelSecondary()

            GeometryReader { geo in
                let width = geo.size.width
                let span = max(1, snapshot.timelineEnd.timeIntervalSince(snapshot.timelineStart))
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.secondary.opacity(0.12))
                        .frame(height: 14)

                    ForEach(snapshot.segments) { segment in
                        let x = segment.start.timeIntervalSince(snapshot.timelineStart) / span
                        let w = segment.duration / span
                        RoundedRectangle(cornerRadius: 6)
                            .fill(segmentColor(segment.kind))
                            .frame(
                                width: max(4, width * CGFloat(w)),
                                height: 14
                            )
                            .offset(x: width * CGFloat(x))
                    }

                    Rectangle()
                        .fill(accent)
                        .frame(width: 2, height: 22)
                        .offset(x: width * CGFloat(snapshot.nowProgress) - 1)

                    if onRescheduleMilestone != nil {
                        ForEach(projectMilestones) { milestone in
                            let progress = milestone.dueDate.timeIntervalSince(snapshot.timelineStart) / span
                            let xPos = width * CGFloat(min(1, max(0, progress)))
                            Circle()
                                .fill(milestone.isCompleted ? Color.green : accent)
                                .frame(width: 12, height: 12)
                                .offset(x: xPos - 6, y: 1)
                                .gesture(
                                    DragGesture(minimumDistance: 4)
                                        .onChanged { value in
                                            dragMilestoneId = milestone.id
                                            let fraction = min(1, max(0, Double(value.location.x / width)))
                                            let date = snapshot.timelineStart.addingTimeInterval(span * fraction)
                                            onRescheduleMilestone?(milestone.id, date)
                                        }
                                        .onEnded { _ in dragMilestoneId = nil }
                                )
                        }
                    }
                }
            }
            .frame(height: 28)

            if onRescheduleMilestone != nil, !projectMilestones.isEmpty {
                BuxCatalogDynamicText(key: "Drag a dot on the timeline to reschedule a milestone.")
                    .font(.system(size: 10, weight: .medium))
                    .buxLabelSecondary()
            }

            HStack {
                Text(shortDate(snapshot.timelineStart))
                Spacer()
                Text(shortDate(snapshot.timelineEnd))
            }
            .font(.system(size: 10, weight: .medium))
            .buxLabelSecondary()
        }
    }

    private var budgetRow: some View {
        let ratio = min(1.2, snapshot.budgetHoursUsed / max(0.01, snapshot.budgetHoursTotal))
        return VStack(alignment: .leading, spacing: 6) {
            BuxCatalogDynamicText(key: "Budget hours")
                .font(.system(size: 12, weight: .bold))
                .buxLabelSecondary()
            ProgressView(value: min(1, ratio))
                .tint(ratio >= 1 ? .red : accent)
            Text(
                BuxLocalizedString.format(
                    "%@/%@h",
                    locale: appSettingsManager.interfaceLocale,
                    String(format: "%.1f", snapshot.budgetHoursUsed),
                    String(format: "%.1f", snapshot.budgetHoursTotal)
                )
            )
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .buxLabelSecondary()
        }
    }

    private var milestonesList: some View {
        VStack(alignment: .leading, spacing: 8) {
            BuxCatalogDynamicText(key: "Milestones")
                .font(.system(size: 12, weight: .bold))
                .buxLabelSecondary()
            ForEach(snapshot.milestones.prefix(8)) { milestone in
                HStack(spacing: 8) {
                    Image(systemName: milestone.isPast ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 12))
                        .foregroundColor(milestone.isPast ? .green : .secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(milestone.title)
                            .font(.system(size: 12, weight: .semibold))
                        if let stored = projectMilestones.first(where: { $0.id == milestone.id }),
                           let dep = stored.dependsOnMilestoneId,
                           let parent = projectMilestones.first(where: { $0.id == dep }) {
                            Text(
                                BuxLocalizedString.format(
                                    "After %@",
                                    locale: appSettingsManager.interfaceLocale,
                                    parent.title
                                )
                            )
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.orange)
                        }
                    }
                    Spacer()
                    Text(shortDate(milestone.date))
                        .font(.system(size: 10, weight: .medium))
                        .buxLabelSecondary()
                }
            }
        }
    }

    private var alertsList: some View {
        VStack(alignment: .leading, spacing: 8) {
            BuxCatalogDynamicText(key: "Planner alerts")
                .font(.system(size: 12, weight: .bold))
                .buxLabelSecondary()
            ForEach(snapshot.alerts.prefix(4)) { alert in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: alertIcon(alert.severity))
                        .foregroundColor(alertColor(alert.severity))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(alert.title)
                            .font(.system(size: 12, weight: .bold))
                        Text(alert.detail)
                            .font(.system(size: 11, weight: .medium))
                            .buxLabelSecondary()
                    }
                }
            }
        }
    }

    private func segmentColor(_ kind: StudioPlannerTimelineSegment.Kind) -> Color {
        switch kind {
        case .elapsed: return accent.opacity(0.85)
        case .planned: return accent.opacity(0.25)
        case .milestone: return .purple.opacity(0.5)
        }
    }

    private func alertIcon(_ severity: StudioPlannerAlert.Severity) -> String {
        switch severity {
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .critical: return "xmark.octagon.fill"
        }
    }

    private func alertColor(_ severity: StudioPlannerAlert.Severity) -> Color {
        switch severity {
        case .info: return .blue
        case .warning: return .orange
        case .critical: return .red
        }
    }

    private func shortDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .short
        return f.string(from: date)
    }
}
