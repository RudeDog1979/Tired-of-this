//
//  BuxPadProMotionCoordinator.swift
//  BuxMuse — Prefer 120Hz on iPad Pro during split resize (M-series).
//

import SwiftUI
import QuartzCore
import UIKit

private final class BuxPadProMotionAnchorView: UIView {
    private var displayLink: CADisplayLink?
    private var lastLayoutTime: CFTimeInterval = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        isHidden = true
        let link = CADisplayLink(target: self, selector: #selector(tick))
        if #available(iOS 15.0, *) {
            let maxFPS = UIScreen.main.maximumFramesPerSecond
            let preferred = min(120, max(60, maxFPS))
            link.preferredFrameRateRange = CAFrameRateRange(
                minimum: 60,
                maximum: Float(preferred),
                preferred: Float(preferred)
            )
        }
        link.add(to: .main, forMode: .common)
        link.isPaused = true // Start paused to save CPU/battery when idle
        displayLink = link
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // Unpause the display link during layout changes (e.g. split resizing)
        displayLink?.isPaused = false
        lastLayoutTime = CACurrentMediaTime()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    deinit {
        displayLink?.invalidate()
    }

    @objc private func tick() {
        // Auto-pause if no layout updates occur for 0.5s to restore 0% idle CPU
        if CACurrentMediaTime() - lastLayoutTime > 0.5 {
            displayLink?.isPaused = true
        }
    }
}

private struct BuxPadProMotionPreferenceView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        BuxPadProMotionAnchorView(frame: .zero)
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

extension View {
    /// Attach on pad root — requests ProMotion frame rate where hardware supports it.
    func buxPadPrefersProMotion() -> some View {
        background {
            BuxPadProMotionPreferenceView()
                .allowsHitTesting(false)
        }
    }
}
