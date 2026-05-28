//
//  StudioTimerLiveActivityWidget.swift
//  BuxMuseTimerWidget
//

import ActivityKit
import SwiftUI
import WidgetKit

private extension ActivityViewContext where Attributes == StudioTimerAttributes {
    var resolvedJobName: String {
        let name = state.jobName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !name.isEmpty { return name }
        return attributes.projectName
    }
}

private enum StudioTimerWidgetDeepLink {
    static let logTimeURL = URL(string: "buxmuse://studio/log-time")!
}

struct StudioTimerLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: StudioTimerAttributes.self) { context in
            StudioTimerLockScreenView(context: context)
                .widgetURL(StudioTimerWidgetDeepLink.logTimeURL)
        } dynamicIsland: { context in
            studioTimerDynamicIsland(context: context)
        }
    }
}

// MARK: - Dynamic Island (compact layout — Apple Music–style)

private func studioTimerDynamicIsland(context: ActivityViewContext<StudioTimerAttributes>) -> DynamicIsland {
    let deepLink = StudioTimerWidgetDeepLink.logTimeURL

    return DynamicIsland {
            DynamicIslandExpandedRegion(.leading) {
                StudioTimerIslandExpandedLeading(context: context)
                    .widgetURL(deepLink)
            }
            DynamicIslandExpandedRegion(.trailing) {
                StudioTimerIslandExpandedTrailing(context: context)
                    .widgetURL(deepLink)
            }
            DynamicIslandExpandedRegion(.bottom) {
                if context.state.hasEstimate {
                    StudioTimerIslandProgressSection(context: context)
                        .padding(.top, 2)
                        .widgetURL(deepLink)
                }
            }
        } compactLeading: {
            Image(systemName: context.state.isRunning ? "stopwatch.fill" : "pause.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.green)
                .widgetURL(deepLink)
        } compactTrailing: {
            StudioTimerIslandCompactTimer(context: context)
                .widgetURL(deepLink)
        } minimal: {
            Image(systemName: "briefcase.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.green)
                .widgetURL(deepLink)
        }
        .keylineTint(Color(red: 0.18, green: 0.78, blue: 0.42))
}

private struct StudioTimerIslandExpandedLeading: View {
    let context: ActivityViewContext<StudioTimerAttributes>

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "briefcase.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.green)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 1) {
                Text(context.resolvedJobName)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Text(subtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var subtitle: String {
        if context.resolvedJobName != context.attributes.projectName {
            return context.attributes.projectName
        }
        return context.state.isRunning ? "Log Time" : "Paused"
    }
}

private struct StudioTimerIslandExpandedTrailing: View {
    let context: ActivityViewContext<StudioTimerAttributes>

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            StudioTimerElapsedLabel(
                sessionStart: context.attributes.sessionStart,
                accumulated: context.state.accumulated,
                segmentStart: context.state.segmentStart,
                isRunning: context.state.isRunning
            )
            .font(.system(size: 15, weight: .bold, design: .monospaced))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.8)

            if context.state.hasEstimate {
                StudioTimerIslandEstimateCaption(context: context)
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }
}

private struct StudioTimerIslandCompactTimer: View {
    let context: ActivityViewContext<StudioTimerAttributes>

    var body: some View {
        StudioTimerElapsedLabel(
            sessionStart: context.attributes.sessionStart,
            accumulated: context.state.accumulated,
            segmentStart: context.state.segmentStart,
            isRunning: context.state.isRunning
        )
        .font(.system(size: 12, weight: .semibold, design: .monospaced))
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.75)
        .frame(maxWidth: 52)
    }
}

/// Slim progress rail for the expanded island only (not the lock screen track).
private struct StudioTimerIslandProgressSection: View {
    let context: ActivityViewContext<StudioTimerAttributes>

    var body: some View {
        if context.state.isRunning {
            TimelineView(.periodic(from: .now, by: 1.0)) { timeline in
                islandTrack(at: timeline.date)
            }
        } else {
            islandTrack(at: Date())
        }
    }

    @ViewBuilder
    private func islandTrack(at date: Date) -> some View {
        let progress = StudioTimerLiveMetrics.progress(
            accumulated: context.state.accumulated,
            segmentStart: context.state.segmentStart,
            isRunning: context.state.isRunning,
            hasEstimate: context.state.hasEstimate,
            estimatedDuration: context.state.estimatedDuration,
            at: date
        )
        let overtime = StudioTimerLiveMetrics.isOvertime(
            accumulated: context.state.accumulated,
            segmentStart: context.state.segmentStart,
            isRunning: context.state.isRunning,
            hasEstimate: context.state.hasEstimate,
            estimatedDuration: context.state.estimatedDuration,
            at: date
        )
        StudioTimerIslandProgressTrack(progress: progress, isOvertime: overtime)
    }
}

private struct StudioTimerIslandProgressTrack: View {
    let progress: Double
    let isOvertime: Bool

    private let trackHeight: CGFloat = 3
    private let dotSize: CGFloat = 7

    private var clampedProgress: CGFloat {
        CGFloat(min(max(progress, 0), 1.05))
    }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let x = width * clampedProgress

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.18, green: 0.78, blue: 0.42),
                                Color(red: 0.98, green: 0.82, blue: 0.18),
                                Color(red: 0.92, green: 0.28, blue: 0.24)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: trackHeight)

                Capsule()
                    .fill(Color.primary.opacity(0.14))
                    .frame(width: max(0, width - x), height: trackHeight)
                    .offset(x: x)

                Circle()
                    .fill(isOvertime ? Color.red : Color.white)
                    .frame(width: dotSize, height: dotSize)
                    .shadow(color: .black.opacity(0.2), radius: 1, y: 0.5)
                    .offset(x: min(max(x - dotSize / 2, 0), width - dotSize))
            }
        }
        .frame(height: dotSize)
    }
}

private struct StudioTimerIslandEstimateCaption: View {
    let context: ActivityViewContext<StudioTimerAttributes>

    var body: some View {
        if context.state.isRunning {
            TimelineView(.periodic(from: .now, by: 1.0)) { timeline in
                caption(at: timeline.date)
            }
        } else {
            caption(at: Date())
        }
    }

    @ViewBuilder
    private func caption(at date: Date) -> some View {
        Text(captionText(at: date))
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(captionTint(at: date))
            .lineLimit(1)
    }

    private func captionText(at date: Date) -> String {
        if StudioTimerLiveMetrics.isOvertime(
            accumulated: context.state.accumulated,
            segmentStart: context.state.segmentStart,
            isRunning: context.state.isRunning,
            hasEstimate: context.state.hasEstimate,
            estimatedDuration: context.state.estimatedDuration,
            at: date
        ) {
            return "Overtime"
        }
        let elapsed = StudioTimerLiveMetrics.elapsed(
            accumulated: context.state.accumulated,
            segmentStart: context.state.segmentStart,
            isRunning: context.state.isRunning,
            at: date
        )
        let left = max(0, context.state.estimatedDuration - elapsed)
        let mins = Int(left) / 60
        if mins >= 60 { return "\(mins / 60)h \(mins % 60)m" }
        return "\(max(1, mins))m left"
    }

    private func captionTint(at date: Date) -> Color {
        StudioTimerLiveMetrics.isOvertime(
            accumulated: context.state.accumulated,
            segmentStart: context.state.segmentStart,
            isRunning: context.state.isRunning,
            hasEstimate: context.state.hasEstimate,
            estimatedDuration: context.state.estimatedDuration,
            at: date
        ) ? .red : .secondary
    }
}

// MARK: - Live progress (computed in-widget; 1 Hz while running)

private struct StudioTimerLiveProgressSection: View {
    let context: ActivityViewContext<StudioTimerAttributes>
    var height: CGFloat = 8
    var travelerSize: CGFloat = 22

    var body: some View {
        if context.state.isRunning {
            TimelineView(.periodic(from: .now, by: 1.0)) { timeline in
                progressBody(at: timeline.date)
            }
        } else {
            progressBody(at: Date())
        }
    }

    @ViewBuilder
    private func progressBody(at date: Date) -> some View {
        let progress = StudioTimerLiveMetrics.progress(
            accumulated: context.state.accumulated,
            segmentStart: context.state.segmentStart,
            isRunning: context.state.isRunning,
            hasEstimate: context.state.hasEstimate,
            estimatedDuration: context.state.estimatedDuration,
            at: date
        )
        let overtime = StudioTimerLiveMetrics.isOvertime(
            accumulated: context.state.accumulated,
            segmentStart: context.state.segmentStart,
            isRunning: context.state.isRunning,
            hasEstimate: context.state.hasEstimate,
            estimatedDuration: context.state.estimatedDuration,
            at: date
        )
        StudioTimerProgressTrack(
            progress: progress,
            isOvertime: overtime,
            height: height,
            travelerSize: travelerSize
        )
    }
}

private struct StudioTimerLiveEstimateLabel: View {
    let context: ActivityViewContext<StudioTimerAttributes>

    var body: some View {
        if context.state.isRunning {
            TimelineView(.periodic(from: .now, by: 1.0)) { timeline in
                Text(estimateText(at: timeline.date))
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(estimateTint(at: timeline.date))
            }
        } else {
            Text(estimateText(at: Date()))
                .font(.caption2.weight(.medium))
                .foregroundStyle(estimateTint(at: Date()))
        }
    }

    private func estimateText(at date: Date) -> String {
        let overtime = StudioTimerLiveMetrics.isOvertime(
            accumulated: context.state.accumulated,
            segmentStart: context.state.segmentStart,
            isRunning: context.state.isRunning,
            hasEstimate: context.state.hasEstimate,
            estimatedDuration: context.state.estimatedDuration,
            at: date
        )
        if overtime { return "Overtime" }
        let elapsed = StudioTimerLiveMetrics.elapsed(
            accumulated: context.state.accumulated,
            segmentStart: context.state.segmentStart,
            isRunning: context.state.isRunning,
            at: date
        )
        let left = max(0, context.state.estimatedDuration - elapsed)
        let mins = Int(left) / 60
        if mins >= 60 { return "\(mins / 60)h \(mins % 60)m left" }
        return "\(max(1, mins))m left"
    }

    private func estimateTint(at date: Date) -> Color {
        StudioTimerLiveMetrics.isOvertime(
            accumulated: context.state.accumulated,
            segmentStart: context.state.segmentStart,
            isRunning: context.state.isRunning,
            hasEstimate: context.state.hasEstimate,
            estimatedDuration: context.state.estimatedDuration,
            at: date
        ) ? .red : .secondary
    }
}

private struct StudioTimerLockScreenView: View {
    let context: ActivityViewContext<StudioTimerAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.resolvedJobName)
                        .font(.headline.weight(.semibold))
                        .lineLimit(2)
                    if context.resolvedJobName != context.attributes.projectName {
                        Text(context.attributes.projectName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
                StudioTimerElapsedLabel(
                    sessionStart: context.attributes.sessionStart,
                    accumulated: context.state.accumulated,
                    segmentStart: context.state.segmentStart,
                    isRunning: context.state.isRunning
                )
                .font(.title3.monospacedDigit().weight(.bold))
            }

            if context.state.hasEstimate {
                StudioTimerLiveProgressSection(context: context)
                StudioTimerLiveLockProgressCaption(context: context)
            } else if context.state.isPaused {
                Text("Paused")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.orange)
            }
        }
        .padding(14)
    }
}

private struct StudioTimerLiveLockProgressCaption: View {
    let context: ActivityViewContext<StudioTimerAttributes>

    var body: some View {
        if context.state.isRunning {
            TimelineView(.periodic(from: .now, by: 1.0)) { timeline in
                caption(at: timeline.date)
            }
        } else {
            caption(at: Date())
        }
    }

    @ViewBuilder
    private func caption(at date: Date) -> some View {
        let progress = StudioTimerLiveMetrics.progress(
            accumulated: context.state.accumulated,
            segmentStart: context.state.segmentStart,
            isRunning: context.state.isRunning,
            hasEstimate: context.state.hasEstimate,
            estimatedDuration: context.state.estimatedDuration,
            at: date
        )
        let overtime = StudioTimerLiveMetrics.isOvertime(
            accumulated: context.state.accumulated,
            segmentStart: context.state.segmentStart,
            isRunning: context.state.isRunning,
            hasEstimate: context.state.hasEstimate,
            estimatedDuration: context.state.estimatedDuration,
            at: date
        )
        HStack {
            Text(overtime ? "Past estimate" : "Job progress")
                .font(.caption2)
                .foregroundStyle(overtime ? .red : .secondary)
            Spacer()
            Text("\(Int(min(progress * 100, 999)))%")
                .font(.caption2.monospacedDigit().weight(.semibold))
        }
    }
}

struct StudioTimerElapsedLabel: View {
    let sessionStart: Date
    let accumulated: TimeInterval
    let segmentStart: Date?
    let isRunning: Bool

    var body: some View {
        if isRunning, let segmentStart {
            let anchor = segmentStart.addingTimeInterval(-accumulated)
            Text(timerInterval: anchor...Date.distantFuture, countsDown: false)
        } else {
            Text(format(accumulated))
        }
    }

    private func format(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%02d:%02d", m, s)
    }
}
