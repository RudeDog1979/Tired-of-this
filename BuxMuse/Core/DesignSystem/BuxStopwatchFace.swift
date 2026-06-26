//
//  BuxStopwatchFace.swift
//  BuxMuse — analog stopwatch face with centered digital readout.
//

import SwiftUI

struct BuxStopwatchFace: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    /// Frozen elapsed when paused.
    let elapsed: TimeInterval
    let isRunning: Bool
    /// `segmentStart.addingTimeInterval(-accumulated)` while running — drives system timer text.
    let timerAnchor: Date?
    let accent: Color

    private let faceSize: CGFloat = 272
    private let tickRadius: CGFloat = 118

    var body: some View {
        Group {
            if isRunning, let timerAnchor {
                TimelineView(.periodic(from: .now, by: 1.0)) { timeline in
                    let liveElapsed = max(0, timeline.date.timeIntervalSince(timerAnchor))
                    faceContent(elapsed: liveElapsed, showCentiseconds: false)
                }
            } else {
                faceContent(elapsed: elapsed, showCentiseconds: true)
            }
        }
        .frame(width: faceSize, height: faceSize)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(BuxCatalogLabel.string("Stopwatch", locale: appSettingsManager.interfaceLocale))
        .accessibilityValue(
            BuxCatalogLabel.string(isRunning ? "Running" : "Paused", locale: appSettingsManager.interfaceLocale)
        )
    }

    @ViewBuilder
    private func faceContent(elapsed: TimeInterval, showCentiseconds: Bool) -> some View {
        ZStack {
            faceBackground
            tickMarks
            if elapsed > 0 || isRunning {
                hand(angle: secondHandAngle(elapsed), length: tickRadius - 18, width: 2.5, color: accent)
                hand(angle: minuteHandAngle(elapsed), length: tickRadius - 36, width: 3.5, color: accent.opacity(0.75))
            }
            centerCap
            digitalReadout(elapsed: elapsed, showCentiseconds: showCentiseconds)
        }
    }

    private var faceBackground: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: faceGradientColors,
                        center: .center,
                        startRadius: 8,
                        endRadius: faceSize * 0.52
                    )
                )

            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            accent.opacity(colorScheme == .dark ? 0.55 : 0.45),
                            accent.opacity(0.12)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 3
                )

            Circle()
                .stroke(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.35), lineWidth: 1)
                .padding(6)
        }
        .shadow(color: accent.opacity(colorScheme == .dark ? 0.25 : 0.18), radius: 24, y: 10)
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.35 : 0.08), radius: 12, y: 6)
    }

    private var faceGradientColors: [Color] {
        if colorScheme == .dark {
            return [
                Color(red: 32/255, green: 34/255, blue: 42/255),
                Color(red: 18/255, green: 19/255, blue: 24/255)
            ]
        }
        return [
            Color.white,
            Color(red: 245/255, green: 246/255, blue: 250/255)
        ]
    }

    private var tickMarks: some View {
        ZStack {
            ForEach(0..<60, id: \.self) { index in
                Capsule()
                    .fill(index % 5 == 0 ? accent.opacity(0.55) : Color.gray.opacity(0.35))
                    .frame(width: index % 5 == 0 ? 2.5 : 1.2, height: index % 5 == 0 ? 14 : 8)
                    .offset(y: -tickRadius)
                    .rotationEffect(.degrees(Double(index) * 6))
            }
        }
    }

    private var centerCap: some View {
        ZStack {
            Circle()
                .fill(accent.opacity(0.18))
                .frame(width: 22, height: 22)
            Circle()
                .fill(accent)
                .frame(width: 10, height: 10)
        }
    }

    @ViewBuilder
    private func digitalReadout(elapsed: TimeInterval, showCentiseconds: Bool) -> some View {
        VStack(spacing: 6) {
            if isRunning, let timerAnchor {
                Text(timerInterval: timerAnchor...Date.distantFuture, countsDown: false)
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(accent)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
            } else {
                Text(formattedElapsed(elapsed))
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Color.primary.opacity(0.85))
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
            }

            if showCentiseconds {
                Text(formattedCentiseconds(elapsed))
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundStyle(accent.opacity(0.75))
            } else {
                Text(" ")
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
            }

            Text(BuxCatalogLabel.string(isRunning ? "RUNNING" : "PAUSED", locale: appSettingsManager.interfaceLocale))
                .font(.system(size: 10, weight: .bold))
                .kerning(1.2)
                .foregroundStyle(isRunning ? accent : Color.gray)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(accent.opacity(isRunning ? 0.14 : 0.06))
                )
        }
        .padding(.top, 28)
    }

    private func hand(angle: Angle, length: CGFloat, width: CGFloat, color: Color) -> some View {
        Capsule()
            .fill(color)
            .frame(width: width, height: length)
            .offset(y: -length / 2 - 10)
            .rotationEffect(angle)
    }

    private func secondHandAngle(_ elapsed: TimeInterval) -> Angle {
        let seconds = elapsed.truncatingRemainder(dividingBy: 60)
        return .degrees(seconds / 60 * 360 - 90)
    }

    private func minuteHandAngle(_ elapsed: TimeInterval) -> Angle {
        let minutes = elapsed / 60
        return .degrees(minutes.truncatingRemainder(dividingBy: 60) / 60 * 360 - 90)
    }

    private func formattedElapsed(_ elapsed: TimeInterval) -> String {
        let total = max(0, Int(elapsed))
        let hrs = total / 3600
        let mins = (total % 3600) / 60
        let secs = total % 60
        if hrs > 0 {
            return String(format: "%d:%02d:%02d", hrs, mins, secs)
        }
        return String(format: "%02d:%02d", mins, secs)
    }

    private func formattedCentiseconds(_ elapsed: TimeInterval) -> String {
        let cs = Int((elapsed.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: ".%02d", cs)
    }
}
