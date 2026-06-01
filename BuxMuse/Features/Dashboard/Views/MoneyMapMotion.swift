//
//  MoneyMapMotion.swift
//  BuxMuse
//
//  Efficient motion clock and drift math.
//

import SwiftUI
#if canImport(CoreMotion)
import CoreMotion
#endif

// MARK: - Drift math (continuous — no repeatForever)

enum MoneyMapMotionMath {
    /// Slow orbital drift — small, smooth movement.
    static let driftPeriod: TimeInterval = 18.0
    static let driftAmplitude: CGFloat = 5.0

    /// Normalized 0…1 autoreverse curve from elapsed time.
    static func driftUnitPhase(elapsed: TimeInterval) -> Double {
        let cycle = elapsed / driftPeriod
        let t = cycle - floor(cycle)
        return 0.5 - 0.5 * cos(t * 2 * .pi)
    }

    static func driftOffset(for node: MoneyMapNode, elapsed: TimeInterval, blend: CGFloat) -> CGSize {
        guard blend > 0.001 else { return .zero }
        let phase = driftUnitPhase(elapsed: elapsed)
        let amp = driftAmplitude * blend
        let x = cos(phase * .pi * 2 + node.angle) * amp
        let y = sin(phase * .pi * 2 + node.angle * 1.3) * amp
        return CGSize(width: x, height: y)
    }

    static func hubPulseScale(elapsed: TimeInterval, blend: CGFloat) -> CGFloat {
        let phase = driftUnitPhase(elapsed: elapsed)
        return 1 + 0.018 * sin(phase * .pi * 2) * blend
    }

    static func hubCoronaOpacity(elapsed: TimeInterval, blend: CGFloat) -> Double {
        let phase = driftUnitPhase(elapsed: elapsed)
        let base = 0.22 + 0.20 * blend
        return base + 0.14 * sin(phase * .pi * 2 + 0.6) * Double(blend)
    }

    /// Layer depth — background slowest, planets float furthest (original Money Map feel).
    enum ParallaxDepth {
        static let ambient: CGFloat = 0.10
        static let sun: CGFloat = 0.36
        static let connections: CGFloat = 0.22
        static let hub: CGFloat = 0.48
        static func node(ring: Int) -> CGFloat { 0.85 + CGFloat(ring) * 0.08 }
    }

    static func parallaxShift(tilt: CGSize, blend: CGFloat, depth: CGFloat, cap: CGFloat = 10) -> CGSize {
        guard blend > 0.02 else { return .zero }
        let raw = CGSize(width: tilt.width * depth * blend, height: tilt.height * depth * blend)
        return CGSize(
            width: raw.width.clamped(to: -cap...cap),
            height: raw.height.clamped(to: -cap...cap)
        )
    }

    static func backgroundParallaxShift(tilt: CGSize, blend: CGFloat) -> CGSize {
        parallaxShift(tilt: tilt, blend: blend, depth: ParallaxDepth.ambient, cap: 8)
    }

    static func sunParallaxShift(tilt: CGSize, blend: CGFloat) -> CGSize {
        parallaxShift(tilt: tilt, blend: blend, depth: ParallaxDepth.sun, cap: 9)
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

// MARK: - Device tilt (read inside TimelineView — no @Published)

@MainActor
final class MoneyMapParallaxDriver {
    private(set) var tilt: CGSize = .zero

    #if canImport(CoreMotion)
    private let manager = CMMotionManager()
    private let motionQueue: OperationQueue = {
        let q = OperationQueue()
        q.name = "com.buxmuse.moneymap.parallax"
        q.maxConcurrentOperationCount = 1
        q.qualityOfService = .userInteractive
        return q
    }()
    #endif
    private var isRunning = false
    private var onTiltUpdate: (@MainActor (CGSize) -> Void)?

    func start(onTiltUpdate: @escaping @MainActor (CGSize) -> Void) {
        self.onTiltUpdate = onTiltUpdate
        #if canImport(CoreMotion)
        guard !isRunning, manager.isDeviceMotionAvailable else {
            onTiltUpdate(.zero)
            return
        }
        isRunning = true
        manager.deviceMotionUpdateInterval = 1.0 / 60.0
        manager.startDeviceMotionUpdates(to: motionQueue) { [weak self] motion, _ in
            guard let self, let motion else { return }
            let roll = CGFloat(motion.attitude.roll).clamped(to: -0.42...0.42)
            let pitch = CGFloat(motion.attitude.pitch).clamped(to: -0.42...0.42)
            let target = CGSize(width: roll * 26, height: pitch * 20)
            DispatchQueue.main.async {
                let follow: CGFloat = 0.32
                let smoothed = CGSize(
                    width: self.tilt.width + (target.width - self.tilt.width) * follow,
                    height: self.tilt.height + (target.height - self.tilt.height) * follow
                )
                let dx = abs(smoothed.width - self.tilt.width)
                let dy = abs(smoothed.height - self.tilt.height)
                guard dx > 0.03 || dy > 0.03 else { return }
                self.tilt = smoothed
                self.onTiltUpdate?(smoothed)
            }
        }
        #else
        onTiltUpdate(.zero)
        #endif
    }

    func stop() {
        #if canImport(CoreMotion)
        guard isRunning else { return }
        manager.stopDeviceMotionUpdates()
        isRunning = false
        tilt = .zero
        onTiltUpdate?(.zero)
        onTiltUpdate = nil
        #endif
    }
}

// MARK: - Pause / resume curves

enum MoneyMapMotionAnimation {
    static let scrollSettleAtHome: TimeInterval = 0.38
    /// Slow ease — visible fade, not a snap.
    static let blendDuration: TimeInterval = 1.18

    static func smoothstep(_ t: CGFloat) -> CGFloat {
        let u = min(max(t, 0), 1)
        return u * u * (3 - 2 * u)
    }

    static func interpolatedBlend(from: CGFloat, to: CGFloat, startedAt: Date, now: Date) -> CGFloat {
        let u = CGFloat(min(1, now.timeIntervalSince(startedAt) / blendDuration))
        return from + (to - from) * smoothstep(u)
    }
}

/// Map is at its scroll-home slot (top of the Money Map page).
enum MoneyMapScrollHome {
    static let offsetThreshold: CGFloat = 16
    static func isAtHome(scrollOffsetY: CGFloat) -> Bool {
        scrollOffsetY < offsetThreshold
    }
}

/// Debounce token without @State churn — avoids commit hitches during scroll ([Apple](https://developer.apple.com/documentation/xcode/understanding-hitches-in-your-app)).
final class MoneyMapScrollIdleCoordinator {
    var generation = 0
}

/// Quantized scroll position — action fires every ~8pt, not only at home threshold.
struct MoneyMapScrollActivity: Equatable {
    let offsetBucket: Int

    var offsetY: CGFloat { CGFloat(offsetBucket) * 8 }
}
