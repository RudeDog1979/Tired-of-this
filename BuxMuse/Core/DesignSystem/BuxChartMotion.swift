//
//  BuxChartMotion.swift
//  BuxMuse Design System
//
//  One-shot, GPU-friendly chart animation primitives for expense hero cards and detail sheets.
//

import SwiftUI

// MARK: - Play context (card vs sheet — separate view instances, each animates once)

enum BuxChartPlayContext: Sendable {
    case compactCard
    case detailSheet
}

// MARK: - Animation tokens

enum BuxChartMotion {
    /// Primary chart draw / grow entrance (detail sheets).
    static var entrance: Animation {
        BuxMotion.reducedMotion
            ? .easeOut(duration: 0.22)
            : .spring(response: 0.62, dampingFraction: 0.86)
    }

    /// Hero card charts — GPU mask only; easeOut avoids spring overshoot cost.
    static var cardEntrance: Animation {
        BuxMotion.reducedMotion
            ? .easeOut(duration: 0.28)
            : .easeOut(duration: 0.88)
    }

    /// Sparkline / area line trace.
    static var draw: Animation {
        BuxMotion.reducedMotion
            ? .easeOut(duration: 0.2)
            : .spring(response: 0.58, dampingFraction: 0.88)
    }

    /// Bar / row stagger inside a chart.
    static func bar(index: Int, base: Double = 0.045) -> Animation {
        let anim = entrance
        return BuxMotion.reducedMotion ? anim : anim.delay(Double(index) * base)
    }

    /// Scales a data value by animation progress (0…1).
    static func scaled(_ value: Double, progress: Double) -> Double {
        value * min(max(progress, 0), 1)
    }

    static func scaled(_ value: CGFloat, progress: Double) -> CGFloat {
        value * CGFloat(min(max(progress, 0), 1))
    }

    /// Per-bar progress derived from a single chart-wide progress (staggered grow).
    static func staggeredProgress(
        global progress: Double,
        index: Int,
        count: Int,
        step: Double = 0.07
    ) -> Double {
        guard count > 0 else { return min(max(progress, 0), 1) }
        let start = Double(index) * step
        guard progress > start else { return 0 }
        return min(1, (progress - start) / max(0.01, 1 - start))
    }

    /// Headroom so sparkline / trend peaks are not clipped in compact cards.
    static func paddedYDomain(
        for values: [Double],
        paddingRatio: Double = 0.18,
        floor: Double = 0
    ) -> ClosedRange<Double> {
        guard let minValue = values.min(), let maxValue = values.max() else {
            return floor...(floor + 1)
        }
        if minValue == maxValue {
            let headroom = max(maxValue * 0.2, 1)
            return floor...(maxValue + headroom)
        }
        let span = maxValue - minValue
        let pad = span * paddingRatio
        return max(floor, minValue - pad)...(maxValue + pad)
    }

    static func playCardEntrance(progress: inout Double, hasPlayed: inout Bool) {
        guard !hasPlayed else { return }
        hasPlayed = true
        if BuxMotion.reducedMotion {
            progress = 1
        } else {
            withAnimation(cardEntrance) {
                progress = 1
            }
        }
    }

    static func resetCardEntrance(progress: inout Double, hasPlayed: inout Bool) {
        hasPlayed = false
        progress = 0
    }
}

// MARK: - Environment progress (0 = hidden, 1 = fully drawn)

private struct BuxChartAnimationProgressKey: EnvironmentKey {
    static let defaultValue: Double = 0
}

extension EnvironmentValues {
    var buxChartAnimationProgress: Double {
        get { self[BuxChartAnimationProgressKey.self] }
        set { self[BuxChartAnimationProgressKey.self] = newValue }
    }
}

// MARK: - One-shot driver (plays once per view instance; no replay on carousel swipe-back)

private struct BuxChartOneShotDriver: ViewModifier {
    let context: BuxChartPlayContext
    let delay: Double

    @State private var progress: Double = 0
    @State private var hasPlayed = false

    func body(content: Content) -> some View {
        content
            .environment(\.buxChartAnimationProgress, progress)
            .onAppear(perform: playOnce)
    }

    private func playOnce() {
        guard !hasPlayed else { return }
        hasPlayed = true
        _ = context

        if BuxMotion.reducedMotion {
            progress = 1
        } else {
            withAnimation(BuxChartMotion.entrance.delay(delay)) {
                progress = 1
            }
        }
    }
}

// MARK: - View extensions

extension View {
    /// Drives `buxChartAnimationProgress` from 0→1 once when this view appears.
    func buxChartOneShotAnimation(
        context: BuxChartPlayContext = .compactCard,
        delay: Double = 0
    ) -> some View {
        modifier(BuxChartOneShotDriver(context: context, delay: delay))
    }

    /// Parent-driven progress for hero cards (carousel coordinates one smooth pass).
    func buxChartProgress(_ progress: Double) -> some View {
        environment(\.buxChartAnimationProgress, progress)
    }

    /// Rasterizes chart layers on the GPU — detail sheets only; skip on compact cards.
    @ViewBuilder
    func gpuChartLayer(enabled: Bool = true) -> some View {
        if enabled {
            drawingGroup(opaque: false, colorMode: .linear)
        } else {
            self
        }
    }

    /// Compact cards use parent-driven progress; detail contexts self-animate.
    @ViewBuilder
    func chartSelfAnimated(context: BuxChartPlayContext, delay: Double = 0) -> some View {
        if context == .compactCard {
            self
        } else {
            buxChartOneShotAnimation(context: context, delay: delay)
        }
    }

    /// GPU clip reveal — chart rasterizes once; only the mask transform animates.
    func buxGPUChartReveal(progress: Double, axis: BuxChartRevealAxis = .horizontal) -> some View {
        modifier(BuxGPUChartRevealModifier(progress: progress, axis: axis))
    }
}

// MARK: - GPU mask reveal

enum BuxChartRevealAxis {
    case horizontal
    case radial
}

/// Rasterize chart once, animate mask only. Modifier is NOT Animatable — avoids Swift Charts redraw per frame.
private struct BuxGPUChartRevealModifier: ViewModifier {
    let progress: Double
    let axis: BuxChartRevealAxis

    func body(content: Content) -> some View {
        content
            .mask(alignment: maskAlignment) {
                BuxGPURevealMask(progress: progress, axis: axis)
            }
    }

    private var maskAlignment: Alignment {
        switch axis {
        case .horizontal: return .leading
        case .radial: return .center
        }
    }
}

/// Lightweight Animatable mask — scale transforms only, no Path rebuild.
private struct BuxGPURevealMask: View, Animatable {
    var progress: Double
    let axis: BuxChartRevealAxis

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        switch axis {
        case .horizontal:
            Rectangle()
                .scaleEffect(x: max(0.0001, progress), y: 1, anchor: .leading)
        case .radial:
            Circle()
                .scaleEffect(max(0.0001, progress))
        }
    }
}
