//
//  PresenceWeekRing.swift
//  BuxMuse
//
//  Seven discrete presence ticks for the week cycle.
//

import SwiftUI

struct PresenceWeekRing: View {
    let filledCount: Int
    var size: CGFloat = 148
    var lineWidth: CGFloat = 10
    var animateFill: Bool = true

    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var revealed = 0

    private var accent: Color { themeManager.contrastAccentColor(for: colorScheme) }
    private var track: Color {
        colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.08)
    }

    var body: some View {
        ZStack {
            ForEach(0..<7, id: \.self) { index in
                Circle()
                    .trim(from: start(for: index), to: end(for: index))
                    .stroke(
                        index < revealed ? accent : track,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
            }

            Circle()
                .fill(accent.opacity(colorScheme == .dark ? 0.16 : 0.10))
                .frame(width: size * 0.42, height: size * 0.42)

            Image(systemName: "calendar")
                .font(.system(size: size * 0.16, weight: .semibold))
                .foregroundColor(accent)
        }
        .frame(width: size, height: size)
        .onAppear {
            let target = min(7, max(0, filledCount))
            guard animateFill else {
                revealed = target
                return
            }
            revealed = 0
            for i in 0..<target {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08 + Double(i) * 0.07) {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
                        revealed = i + 1
                    }
                }
            }
        }
        .onChange(of: filledCount) { _, newValue in
            revealed = min(7, max(0, newValue))
        }
        .accessibilityHidden(true)
    }

    private func start(for index: Int) -> CGFloat {
        let gap: CGFloat = 0.028
        let segment = (1.0 - gap * 7) / 7
        return CGFloat(index) * (segment + gap)
    }

    private func end(for index: Int) -> CGFloat {
        let gap: CGFloat = 0.028
        let segment = (1.0 - gap * 7) / 7
        return start(for: index) + segment
    }
}

struct PresenceMiniTicks: View {
    let filledCount: Int

    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<7, id: \.self) { index in
                Capsule(style: .continuous)
                    .fill(
                        index < filledCount
                            ? themeManager.contrastAccentColor(for: colorScheme)
                            : (colorScheme == .dark ? Color.white.opacity(0.14) : Color.black.opacity(0.1))
                    )
                    .frame(width: 10, height: 4)
            }
        }
        .accessibilityHidden(true)
    }
}
