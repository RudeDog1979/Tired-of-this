//
//  BuxPadProMotionCoordinator.swift
//  BuxMuse — Prefer 120Hz on iPad Pro during split resize (M-series).
//

import SwiftUI
import QuartzCore
import UIKit

private final class BuxPadProMotionAnchorView: UIView {
    private var displayLink: CADisplayLink?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        isHidden = true
        guard BuxPadIdiom.isPad else { return }
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
        displayLink = link
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    deinit {
        displayLink?.invalidate()
    }

    @objc private func tick() {}
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
            if BuxPadIdiom.isPad {
                BuxPadProMotionPreferenceView()
                    .allowsHitTesting(false)
            }
        }
    }
}
