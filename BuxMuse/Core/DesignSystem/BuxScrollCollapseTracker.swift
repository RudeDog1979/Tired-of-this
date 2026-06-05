//
//  BuxScrollCollapseTracker.swift
//  BuxMuse
//
//  Shared scroll-offset tracking for collapsible root tab headers.
//  Quantized updates — GPU-friendly, 60/120Hz safe (Dashboard-proven pattern).
//

import SwiftUI

// MARK: - Tuning

enum BuxScrollCollapse {
    /// Default named space for root tab scroll collapse.
    static let coordinateSpaceName = "bux_scroll_collapse"

    /// Preference updates are bucketed to this step (pt).
    static let quantizeStep: CGFloat = 8

    /// Ignore sub-threshold jitter between quantized samples.
    static let updateThreshold: CGFloat = 7

    /// Clamp tracked negative offset so preference churn stays bounded.
    static let maxTrackedOffset: CGFloat = 150

    /// Scroll distance (pt) for full large → compact header transition.
    static let defaultCollapseDistance: CGFloat = 80

    /// Subtitle / accent fade distance (pt).
    static let defaultFadeDistance: CGFloat = 100
}

// MARK: - Math

enum BuxScrollCollapseMath {
    /// 0 = expanded, 1 = fully compact.
    static func progress(
        scrollOffset: CGFloat,
        distance: CGFloat = BuxScrollCollapse.defaultCollapseDistance
    ) -> CGFloat {
        guard distance > 0 else { return 0 }
        return min(1, max(0, -scrollOffset / distance))
    }

    /// Interpolate between expanded and compact values from scroll offset.
    static func lerp(
        start: CGFloat,
        end: CGFloat,
        scrollOffset: CGFloat,
        distance: CGFloat = BuxScrollCollapse.defaultCollapseDistance
    ) -> CGFloat {
        start + (end - start) * progress(scrollOffset: scrollOffset, distance: distance)
    }

    /// Fade secondary chrome as the user scrolls (subtitle, underline).
    static func fadeOpacity(
        scrollOffset: CGFloat,
        fadeDistance: CGFloat = BuxScrollCollapse.defaultFadeDistance
    ) -> CGFloat {
        guard fadeDistance > 0 else { return 1 }
        return max(0, 1 + (scrollOffset / fadeDistance))
    }

    static func quantize(_ rawOffset: CGFloat) -> CGFloat {
        let clamped = rawOffset < 0
            ? max(-BuxScrollCollapse.maxTrackedOffset, rawOffset)
            : 0
        let step = BuxScrollCollapse.quantizeStep
        return (clamped / step).rounded() * step
    }

    static func shouldPublish(previous: CGFloat, next: CGFloat) -> Bool {
        abs(next - previous) >= BuxScrollCollapse.updateThreshold
    }
}

// MARK: - Tracking

private struct BuxScrollCollapseTrackerModifier: ViewModifier {
    @Binding var scrollOffset: CGFloat
    let coordinateSpace: String

    func body(content: Content) -> some View {
        content
            .background {
                GeometryReader { geo in
                    Color.clear.preference(
                        key: ScrollOffsetPreferenceKey.self,
                        value: geo.frame(in: .named(coordinateSpace)).minY
                    )
                }
            }
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                let stepped = BuxScrollCollapseMath.quantize(value)
                guard BuxScrollCollapseMath.shouldPublish(previous: scrollOffset, next: stepped) else { return }
                scrollOffset = stepped
            }
    }
}

extension View {
    /// Named coordinate space for collapse tracking on a `ScrollView` / `List` container.
    func buxScrollCollapseCoordinateSpace(
        _ name: String = BuxScrollCollapse.coordinateSpaceName
    ) -> some View {
        coordinateSpace(name: name)
    }

    /// Attach to the view whose vertical position should drive collapse (usually the scroll header).
    func buxTrackScrollCollapse(
        scrollOffset: Binding<CGFloat>,
        coordinateSpace: String = BuxScrollCollapse.coordinateSpaceName
    ) -> some View {
        modifier(BuxScrollCollapseTrackerModifier(
            scrollOffset: scrollOffset,
            coordinateSpace: coordinateSpace
        ))
    }
}

// MARK: - Animatable collapse (render-server friendly)

struct BuxScrollCollapseAnimatableModifier: ViewModifier, Animatable {
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    let expandedOpacity: CGFloat
    let compactOpacity: CGFloat

    func body(content: Content) -> some View {
        content
            .opacity(expandedOpacity + (compactOpacity - expandedOpacity) * progress)
    }
}

extension View {
    func buxScrollCollapseOpacity(
        progress: CGFloat,
        expanded: CGFloat = 1,
        compact: CGFloat = 0
    ) -> some View {
        modifier(BuxScrollCollapseAnimatableModifier(
            progress: progress,
            expandedOpacity: expanded,
            compactOpacity: compact
        ))
    }
}
