//
//  MoneyMapCanvasView.swift
//  BuxMuse
//
//  Interactive constellation map — mini preview or full-screen territory view.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

enum MoneyMapDisplayMode {
    case mini
    case full

    func canvasHeight(isLandscape: Bool) -> CGFloat {
        switch self {
        case .mini: return isLandscape ? 220 : 272
        case .full: return isLandscape ? 320 : 448
        }
    }

    func edgeInset(isLandscape: Bool) -> CGFloat {
        switch self {
        case .mini: return isLandscape ? 20 : 22
        case .full: return isLandscape ? 28 : 30
        }
    }

    var hubSize: CGFloat {
        switch self {
        case .mini: return 76
        case .full: return 112
        }
    }

    var hubValueFont: CGFloat {
        switch self {
        case .mini: return 17
        case .full: return 22
        }
    }

    var nodeScale: CGFloat {
        switch self {
        case .mini: return 0.78
        case .full: return 1.0
        }
    }

    func radiusScale(isLandscape: Bool) -> CGFloat {
        switch self {
        case .mini: return isLandscape ? 0.28 : 0.26
        case .full: return isLandscape ? 0.34 : 0.30
        }
    }
}

struct MoneyMapCanvasView: View {
    let graph: MoneyMapGraph
    var mode: MoneyMapDisplayMode = .full
    var allowsNodeSelection: Bool = true
    var motionPaused: Bool = false
    var onNodeSelected: ((MoneyMapNode) -> Void)?
    var onExpandRequested: (() -> Void)?

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var themeManager: ThemeManager
    @ObservedObject private var layoutStore = MoneyMapLayoutStore.shared

    @State private var mapAppeared = false
    @State private var firstExpandProgress: CGFloat = 1
    @State private var highlightedNodeID: String?
    @State private var canvasSize: CGSize = .zero
    @State private var draggingNodeID: String?
    @State private var dragTranslation: CGSize = .zero

    /// Continuous clock anchor — elapsed = now - anchor (no repeatForever).
    @State private var motionAnchor = Date()
    @State private var frozenElapsed: TimeInterval = 0
    @State private var blendFrom: CGFloat = 0
    @State private var blendTo: CGFloat = 0
    @State private var blendStartedAt: Date?
    @State private var parallax = MoneyMapParallaxDriver()
    @State private var liveTilt: CGSize = .zero

    private var isLandscape: Bool {
        canvasSize.width > canvasSize.height
    }

    private var wantsLiveMotion: Bool {
        mode == .full
            && !motionPaused
            && draggingNodeID == nil
            && scenePhase == .active
    }

    private var shouldTickClock: Bool {
        guard mode == .full else { return false }
        return wantsLiveMotion || blendStartedAt != nil
    }

    private func currentBlend(at now: Date) -> CGFloat {
        if mode == .mini { return 1 }
        guard let start = blendStartedAt else { return blendTo }
        return MoneyMapMotionAnimation.interpolatedBlend(from: blendFrom, to: blendTo, startedAt: start, now: now)
    }

    private func freezeBlend(at now: Date = Date()) {
        let current = currentBlend(at: now)
        blendFrom = current
        blendTo = current
        blendStartedAt = nil
    }

    private func snapBlend(to target: CGFloat) {
        blendFrom = target
        blendTo = target
        blendStartedAt = nil
    }

    private func beginBlend(to target: CGFloat, at now: Date = Date()) {
        blendFrom = currentBlend(at: now)
        blendTo = target
        blendStartedAt = now
    }

    private func finalizeBlendIfNeeded(at now: Date) {
        guard let start = blendStartedAt else { return }
        guard now.timeIntervalSince(start) >= MoneyMapMotionAnimation.blendDuration else { return }
        blendFrom = blendTo
        blendStartedAt = nil
    }

    var body: some View {
        let _ = layoutStore.layoutToken
        VStack(alignment: .leading, spacing: mode == .mini ? 10 : 14) {
            if mode == .full {
                mapHeader
            }

            mapStageContainer

            if mode == .mini {
                miniFooter
            } else if allowsNodeSelection {
                hintRow
            }
        }
        .onAppear {
            switch mode {
            case .mini:
                mapAppeared = true
            case .full:
                if MoneyMapExperience.shouldPlayFirstFullOpenExpand {
                    mapAppeared = true
                    firstExpandProgress = 0
                    withAnimation(.spring(response: 1.05, dampingFraction: 0.76).delay(0.14)) {
                        firstExpandProgress = 1
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.35) {
                        MoneyMapExperience.markFirstFullOpenExpandPlayed()
                    }
                } else {
                    withAnimation(.spring(response: 0.85, dampingFraction: 0.78)) {
                        mapAppeared = true
                    }
                }
            }
            syncMotionLifecycle(from: nil, to: wantsLiveMotion)
            blendTo = wantsLiveMotion ? 1 : 0
            blendFrom = blendTo
            blendStartedAt = nil
        }
        .onDisappear {
            if mode == .full {
                commitInProgressDragIfNeeded()
            }
            blendTo = 0
            blendFrom = 0
            blendStartedAt = nil
            parallax.stop()
            liveTilt = .zero
        }
        .onChange(of: wantsLiveMotion) { old, wants in
            if wants {
                beginBlend(to: 1)
            } else {
                freezeBlend()
            }
            syncMotionLifecycle(from: old, to: wants)
        }
    }

    // MARK: - Stage (TimelineView ticks only while live or blending)

    @ViewBuilder
    private var mapStageContainer: some View {
        let cornerRadius: CGFloat = mode == .mini ? 18 : 22
        let cardPadding: CGFloat = mode == .mini ? 10 : 12

        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(mapBackgroundMaterial)

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(themeManager.current.accentColor.opacity(0.12), lineWidth: 1)

            Group {
                if mode == .full {
                    TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !shouldTickClock)) { timeline in
                        let now = timeline.date
                        let blend = currentBlend(at: now)
                        let elapsed = wantsLiveMotion
                            ? now.timeIntervalSince(motionAnchor)
                            : frozenElapsed
                        mapStage(elapsed: elapsed, blend: blend, tilt: liveTilt)
                            .onChange(of: now) { _, date in
                                finalizeBlendIfNeeded(at: date)
                            }
                    }
                } else {
                    mapStage(elapsed: 0, blend: 1, tilt: .zero)
                }
            }
            .padding(cardPadding)
        }
        .frame(height: mode.canvasHeight(isLandscape: isLandscape))
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .background {
            GeometryReader { geo in
                Color.clear
                    .onAppear { canvasSize = geo.size }
                    .onChange(of: geo.size) { _, newSize in canvasSize = newSize }
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .onTapGesture {
            if mode == .mini { onExpandRequested?() }
        }
    }

    private var mapBackgroundMaterial: Color {
        themeManager.materialScheme(for: colorScheme).surfaceContainer
            .opacity(mode == .full ? 0.45 : 0.35)
    }

    private func parallaxShift(tilt: CGSize, blend: CGFloat, depth: CGFloat) -> CGSize {
        guard mode == .full else { return .zero }
        return MoneyMapMotionMath.parallaxShift(tilt: tilt, blend: blend, depth: depth)
    }

    @ViewBuilder
    private func mapStage(elapsed: TimeInterval, blend: CGFloat, tilt: CGSize) -> some View {
        let liveBlend = mode == .full ? blend : 0
        ZStack {
            MoneyMapTopoWavesView(
                accent: themeManager.current.accentColor,
                isDark: colorScheme == .dark
            )
            .offset(MoneyMapMotionMath.backgroundParallaxShift(tilt: tilt, blend: liveBlend))

            sunHaloCanvas(elapsed: elapsed, blend: blend, tilt: tilt)

            connectionCanvas(elapsed: elapsed, blend: blend, tilt: tilt)

            centerHub(elapsed: elapsed, blend: blend, tilt: tilt)

            nodeLayer(elapsed: elapsed, blend: blend, tilt: tilt)
        }
    }

    // MARK: - Motion lifecycle

    private func syncMotionLifecycle(from old: Bool?, to wants: Bool) {
        if wants {
            motionAnchor = Date().addingTimeInterval(-frozenElapsed)
            parallax.start { liveTilt = $0 }
        } else {
            if old == true {
                frozenElapsed = Date().timeIntervalSince(motionAnchor)
            }
            parallax.stop()
            liveTilt = .zero
        }
    }

    // MARK: - Chrome

    private var mapBackground: some View {
        mapBackgroundMaterial
    }

    private var mapHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Your financial landscape")
                    .buxSectionLabelStyle(color: themeManager.sectionHeaderColor(for: colorScheme))
                Text(isLandscape ? "Landscape weave · tap territories" : "Tap a territory to explore")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(themeManager.labelSecondary(for: colorScheme))
            }
            Spacer()
            if allowsNodeSelection {
                resetLayoutButton
            }
        }
        .padding(.horizontal, 4)
    }

    private var resetLayoutButton: some View {
        Button(action: resetNodeLayout) {
            Image(systemName: "arrow.trianglehead.counterclockwise")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(themeManager.labelPrimary(for: colorScheme))
                .frame(width: 34, height: 34)
                .background { BuxGlassCircleBackground(diameter: 34) }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Reset map layout")
    }

    private var miniFooter: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .foregroundColor(themeManager.current.accentColor)
            Text("\(graph.nodes.count) territories · tap to open full map")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(themeManager.labelSecondary(for: colorScheme))
        }
        .padding(.horizontal, 6)
    }

    private var hintRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "hand.tap.fill")
                .foregroundColor(themeManager.current.accentColor)
            Text("Long-press & drag to weave the web · tap for territory detail")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(themeManager.labelSecondary(for: colorScheme))
        }
        .padding(.horizontal, 6)
    }

    // MARK: - Map layers

    @ViewBuilder
    private func sunHaloCanvas(elapsed: TimeInterval, blend: CGFloat, tilt: CGSize) -> some View {
        // Full map uses hub shadow only — large radial halos wash over weave lines.
        if mode == .mini {
            GeometryReader { geo in
                let accent = themeManager.current.accentColor
                let isDark = colorScheme == .dark
                let haloDiameter = mode.hubSize * 1.62
                let hubShift = parallaxShift(tilt: tilt, blend: blend, depth: MoneyMapMotionMath.ParallaxDepth.sun)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                accent.opacity((isDark ? 0.22 : 0.36) * Double(blend)),
                                accent.opacity((isDark ? 0.10 : 0.18) * Double(blend)),
                                accent.opacity((isDark ? 0.04 : 0.08) * Double(blend)),
                                .clear
                            ],
                            center: .center,
                            startRadius: mode.hubSize * 0.08,
                            endRadius: haloDiameter / 2
                        )
                    )
                    .frame(width: haloDiameter, height: haloDiameter)
                    .position(x: geo.size.width / 2 + hubShift.width, y: geo.size.height / 2 + hubShift.height)
            }
            .allowsHitTesting(false)
        }
    }

    private func connectionCanvas(elapsed: TimeInterval, blend: CGFloat, tilt: CGSize) -> some View {
        Canvas { context, size in
            let hubShift = parallaxShift(tilt: tilt, blend: blend, depth: MoneyMapMotionMath.ParallaxDepth.hub)
            let center = CGPoint(
                x: size.width / 2 + hubShift.width,
                y: size.height / 2 + hubShift.height
            )
            let trimEnd = connectionTrimProgress

            for node in graph.nodes {
                let drift = MoneyMapMotionMath.driftOffset(for: node, elapsed: elapsed, blend: blend)
                let base = renderedPoint(for: node, in: size, drift: drift)
                let nodeShift = parallaxShift(tilt: tilt, blend: blend, depth: MoneyMapMotionMath.ParallaxDepth.node(ring: node.ring))
                let nodeCenter = CGPoint(x: base.x + nodeShift.width, y: base.y + nodeShift.height)
                let nodeDiameter = (36 + node.weight * 22) * mode.nodeScale
                let endpoints = connectionEndpoints(
                    hubCenter: center,
                    nodeCenter: nodeCenter,
                    hubRadius: mode.hubSize / 2,
                    nodeRadius: nodeDiameter / 2
                )
                var path = Path()
                path.move(to: endpoints.hub)
                path.addQuadCurve(to: endpoints.node, control: controlPoint(from: endpoints.hub, to: endpoints.node))
                let highlighted = highlightedNodeID == node.id || draggingNodeID == node.id
                let trimmed = path.trimmedPath(from: 0, to: trimEnd)
                if highlighted {
                    context.stroke(
                        trimmed,
                        with: .color(node.accentColor.opacity(0.95)),
                        style: StrokeStyle(lineWidth: 2.8, lineCap: .round, lineJoin: .round)
                    )
                } else {
                    context.stroke(
                        trimmed,
                        with: .color(node.accentColor.opacity(0.40)),
                        style: StrokeStyle(lineWidth: 1.6, lineCap: .round, dash: [5, 4])
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func centerHub(elapsed: TimeInterval, blend: CGFloat, tilt: CGSize) -> some View {
        GeometryReader { geo in
            let size = geo.size
            let accent = themeManager.current.accentColor
            let pulse = MoneyMapMotionMath.hubPulseScale(elapsed: elapsed, blend: blend)
            let hubShift = parallaxShift(tilt: tilt, blend: blend, depth: MoneyMapMotionMath.ParallaxDepth.hub)

            ZStack {
                VStack(spacing: 4) {
                    Text(graph.centerTitle.uppercased())
                        .font(.system(size: mode == .mini ? 8 : 9, weight: .bold))
                        .kerning(1)
                        .foregroundStyle(hubTitleColor(accent: accent))
                    Text(graph.centerValue)
                        .font(.system(size: mode.hubValueFont, weight: .black, design: .rounded))
                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                        .minimumScaleFactor(0.65)
                        .lineLimit(1)
                    Text(graph.centerSubtitle)
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(themeManager.labelSecondary(for: colorScheme))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                }
                .padding(mode == .mini ? 10 : 16)
                .frame(width: mode.hubSize, height: mode.hubSize)
                .background {
                    hubOrbBackground(accent: accent)
                }
            }
            .scaleEffect(mapAppeared ? pulse : 0.6)
            .opacity(mapAppeared ? 1 : 0)
            .shadow(
                color: mode == .full ? MoneyMapOrbChrome.orbShadowColor(isDark: colorScheme == .dark) : .clear,
                radius: mode == .full ? 10 : 0,
                y: mode == .full ? 4 : 0
            )
            .position(
                x: size.width / 2 + hubShift.width,
                y: size.height / 2 + hubShift.height
            )
        }
        .allowsHitTesting(false)
    }

    private func nodeLayer(elapsed: TimeInterval, blend: CGFloat, tilt: CGSize) -> some View {
        GeometryReader { geo in
            ForEach(graph.nodes) { node in
                nodeView(node: node, size: geo.size, elapsed: elapsed, blend: blend, tilt: tilt)
            }
        }
    }

    @ViewBuilder
    private func nodeView(node: MoneyMapNode, size: CGSize, elapsed: TimeInterval, blend: CGFloat, tilt: CGSize) -> some View {
        let drift = MoneyMapMotionMath.driftOffset(for: node, elapsed: elapsed, blend: blend)
        let point = renderedPoint(for: node, in: size, drift: drift)
        let isHighlighted = highlightedNodeID == node.id || draggingNodeID == node.id
        let diameter = (36 + node.weight * 22) * mode.nodeScale
        let isDragging = draggingNodeID == node.id
        let nodeShift = parallaxShift(tilt: tilt, blend: blend, depth: MoneyMapMotionMath.ParallaxDepth.node(ring: node.ring))
        let nodeScale = nodeDisplayScale(isDragging: isDragging, isHighlighted: isHighlighted, node: node)

        VStack(spacing: 2) {
            ZStack {
                nodeOrbBackground(node: node, diameter: diameter, isHighlighted: isHighlighted)

                Image(systemName: node.systemIcon)
                    .font(.system(size: (10 + node.weight * 5) * mode.nodeScale, weight: .bold))
                    .foregroundStyle(node.accentColor)

                if node.isProTerritory {
                    Image(systemName: "s.circle.fill")
                        .font(.system(size: 9, weight: .black))
                        .foregroundStyle(.purple)
                        .offset(x: diameter * 0.34, y: -diameter * 0.34)
                }
            }
            if mode == .full {
                Text(node.title)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .frame(maxWidth: 76)
            }
        }
        .scaleEffect(nodeScale)
        .opacity(nodeDisplayOpacity)
        .shadow(
            color: mode == .full && !isDragging
                ? MoneyMapOrbChrome.orbShadowColor(isDark: colorScheme == .dark)
                : .clear,
            radius: mode == .full ? 5 : 0,
            y: mode == .full ? 2 : 0
        )
        .position(x: point.x + nodeShift.width, y: point.y + nodeShift.height)
        .animation(.spring(response: 0.45, dampingFraction: 0.72), value: isHighlighted)
        .animation(mode == .mini ? .spring(response: 0.58, dampingFraction: 0.84) : nil, value: layoutStore.layoutToken)
        .onTapGesture {
            guard draggingNodeID == nil else { return }
            if mode == .mini {
                onExpandRequested?()
            } else if allowsNodeSelection {
                highlightedNodeID = node.id
                onNodeSelected?(node)
            }
        }
        .gesture(nodeDragGesture(for: node))
    }

    private func nodeDragGesture(for node: MoneyMapNode) -> some Gesture {
        LongPressGesture(minimumDuration: 0.35)
            .sequenced(before: DragGesture())
            .onChanged { value in
                guard mode == .full, allowsNodeSelection else { return }
                switch value {
                case .second(true, let drag):
                    if draggingNodeID == nil {
                        draggingNodeID = node.id
                        highlightedNodeID = node.id
                        frozenElapsed = Date().timeIntervalSince(motionAnchor)
                        snapBlend(to: 0)
                        parallax.stop()
                        liveTilt = .zero
                        #if canImport(UIKit)
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        #endif
                    }
                    if let drag {
                        let stored = layoutStore.offset(for: node.id)
                        let contentSize = mapContentSize(from: canvasSize)
                        let proposed = CGSize(
                            width: stored.width + drag.translation.width,
                            height: stored.height + drag.translation.height
                        )
                        let clamped = clampedUserOffset(for: node, proposed, in: contentSize)
                        dragTranslation = CGSize(
                            width: clamped.width - stored.width,
                            height: clamped.height - stored.height
                        )
                    }
                default:
                    break
                }
            }
            .onEnded { value in
                guard mode == .full, allowsNodeSelection else { return }
                if case .second(true, let drag?) = value {
                    let contentSize = mapContentSize(from: canvasSize)
                    let stored = layoutStore.offset(for: node.id)
                    let proposed = CGSize(
                        width: stored.width + drag.translation.width,
                        height: stored.height + drag.translation.height
                    )
                    layoutStore.setOffset(clampedUserOffset(for: node, proposed, in: contentSize), for: node.id)
                }
                draggingNodeID = nil
                dragTranslation = .zero
                highlightedNodeID = nil
            }
    }

    private func resetNodeLayout() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
        withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) {
            highlightedNodeID = nil
            draggingNodeID = nil
            dragTranslation = .zero
        }
        layoutStore.resetAll()
    }

    /// Persists an active drag when the full map closes mid-gesture (no bulk save on disappear).
    private func commitInProgressDragIfNeeded() {
        guard let nodeID = draggingNodeID,
              let node = graph.nodes.first(where: { $0.id == nodeID }),
              canvasSize.width > 80, canvasSize.height > 80 else { return }
        let contentSize = mapContentSize(from: canvasSize)
        let stored = layoutStore.offset(for: nodeID)
        let proposed = CGSize(
            width: stored.width + dragTranslation.width,
            height: stored.height + dragTranslation.height
        )
        layoutStore.setOffset(clampedUserOffset(for: node, proposed, in: contentSize), for: nodeID)
        draggingNodeID = nil
        dragTranslation = .zero
    }

    private func resolvedPoint(for node: MoneyMapNode, in size: CGSize, drift: CGSize = .zero) -> CGPoint {
        let base = nodePoint(for: node, in: size)
        let offset = totalOffset(for: node.id, in: size)
        return CGPoint(x: base.x + offset.width + drift.width, y: base.y + offset.height + drift.height)
    }

    private func renderedPoint(for node: MoneyMapNode, in size: CGSize, drift: CGSize = .zero) -> CGPoint {
        let target = resolvedPoint(for: node, in: size, drift: drift)
        guard mode == .full, firstExpandProgress < 1 else { return target }
        let hub = CGPoint(x: size.width / 2, y: size.height / 2)
        let t = firstExpandFraction(for: node)
        return CGPoint(
            x: hub.x + (target.x - hub.x) * t,
            y: hub.y + (target.y - hub.y) * t
        )
    }

    private func firstExpandFraction(for node: MoneyMapNode) -> CGFloat {
        let stagger = CGFloat(node.ring) * 0.075
        let span: CGFloat = 0.86
        return min(1, max(0, (firstExpandProgress - stagger) / span))
    }

    private var connectionTrimProgress: CGFloat {
        guard mapAppeared else { return 0 }
        if mode == .full, firstExpandProgress < 1 { return firstExpandProgress }
        return 1
    }

    private func nodeDisplayScale(isDragging: Bool, isHighlighted: Bool, node: MoneyMapNode) -> CGFloat {
        if mode == .full, firstExpandProgress < 1 {
            let t = firstExpandFraction(for: node)
            return 0.22 + 0.78 * t
        }
        guard mapAppeared else { return 0.2 }
        if isDragging { return 1.08 }
        if isHighlighted { return 1.04 }
        return 1
    }

    private var nodeDisplayOpacity: Double {
        if mode == .mini { return 1 }
        if mode == .full, firstExpandProgress < 1 { return 1 }
        return mapAppeared ? 1 : 0
    }

    private func totalOffset(for nodeID: String, in size: CGSize) -> CGSize {
        guard let node = graph.nodes.first(where: { $0.id == nodeID }) else { return .zero }
        let stored = layoutStore.offset(for: nodeID)
        if mode == .mini {
            let mapped = MoneyMapMiniLayoutAdapter.miniOffset(
                for: node,
                graph: graph,
                storedFullOffset: stored,
                miniContentSize: size,
                isLandscape: isLandscape
            )
            return clampedUserOffset(for: node, mapped, in: size)
        }
        guard mode == .full else { return .zero }
        let raw: CGSize = if draggingNodeID == nodeID {
            CGSize(width: stored.width + dragTranslation.width, height: stored.height + dragTranslation.height)
        } else {
            stored
        }
        return clampedUserOffset(for: node, raw, in: size)
    }

    private func mapContentSize(from canvas: CGSize) -> CGSize {
        guard canvas.width > 0, canvas.height > 0 else { return canvas }
        let pad = (mode == .mini ? 10.0 : 12.0) * 2
        return CGSize(width: max(1, canvas.width - pad), height: max(1, canvas.height - pad))
    }

    private func nodeExtent(for node: MoneyMapNode) -> CGFloat {
        let diameter = (36 + node.weight * 22) * mode.nodeScale
        let proBadge = node.isProTerritory ? diameter * 0.34 : 0
        return diameter / 2 + proBadge + 2
    }

    private func labelAllowance(for node: MoneyMapNode) -> CGFloat {
        mode == .full ? 22 : 4
    }

    private func clampedUserOffset(for node: MoneyMapNode, _ offset: CGSize, in size: CGSize) -> CGSize {
        guard size.width > 1, size.height > 1 else { return offset }
        let base = nodePoint(for: node, in: size)
        let extent = nodeExtent(for: node)
        let slack: CGFloat = 12 // parallax + glow bleed

        let minX = extent + slack
        let maxX = size.width - extent - slack
        let minY = extent + slack
        let maxY = size.height - extent - slack - labelAllowance(for: node)

        guard minX <= maxX, minY <= maxY else { return .zero }

        let x = min(max(base.x + offset.width, minX), maxX) - base.x
        let y = min(max(base.y + offset.height, minY), maxY) - base.y
        return CGSize(width: x, height: y)
    }

    private func nodePoint(for node: MoneyMapNode, in size: CGSize) -> CGPoint {
        let margin = layoutMargin(in: size)
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let usableW = size.width - margin * 2
        let usableH = size.height - margin * 2
        let maxRing = CGFloat(graph.nodes.map(\.ring).max() ?? 0)
        let ringStep: CGFloat = mode == .mini ? 14 : 18
        let nodeRadius = maxNodeRadius
        let labelAllowance: CGFloat = mode == .full ? 20 : 4
        let maxOrbit = min(usableW, usableH) / 2 - nodeRadius - labelAllowance
        let requestedBase = min(usableW, usableH) * mode.radiusScale(isLandscape: isLandscape)
        let ringSpan = maxRing * ringStep
        let baseRadius = min(requestedBase, max(0, maxOrbit - ringSpan))
        let ringOffset = CGFloat(node.ring) * ringStep
        let rx = (baseRadius + ringOffset) * (isLandscape ? 1.08 : 1.0)
        let ry = (baseRadius + ringOffset) * (isLandscape ? 0.90 : 1.0)
        return CGPoint(x: center.x + cos(node.angle) * rx, y: center.y + sin(node.angle) * ry)
    }

    private var maxNodeRadius: CGFloat {
        let maxWeight = graph.nodes.map(\.weight).max() ?? 1
        return (36 + maxWeight * 22) * mode.nodeScale / 2
    }

    private func layoutMargin(in size: CGSize) -> CGFloat {
        mode.edgeInset(isLandscape: isLandscape) + maxNodeRadius + (mode == .full ? 8 : 4)
    }

    private func controlPoint(from: CGPoint, to: CGPoint) -> CGPoint {
        CGPoint(
            x: (from.x + to.x) / 2 + (from.y - to.y) * 0.12,
            y: (from.y + to.y) / 2 + (to.x - from.x) * 0.12
        )
    }

    private func connectionEndpoints(
        hubCenter: CGPoint,
        nodeCenter: CGPoint,
        hubRadius: CGFloat,
        nodeRadius: CGFloat
    ) -> (hub: CGPoint, node: CGPoint) {
        let dx = nodeCenter.x - hubCenter.x
        let dy = nodeCenter.y - hubCenter.y
        let dist = max(hypot(dx, dy), 0.001)
        let ux = dx / dist
        let uy = dy / dist
        return (
            hub: CGPoint(x: hubCenter.x + ux * hubRadius, y: hubCenter.y + uy * hubRadius),
            node: CGPoint(x: nodeCenter.x - ux * nodeRadius, y: nodeCenter.y - uy * nodeRadius)
        )
    }

    private func hubTitleColor(accent: Color) -> Color {
        if mode == .full {
            return colorScheme == .dark ? .white : .black
        }
        return accent
    }

    @ViewBuilder
    private func hubOrbBackground(accent: Color) -> some View {
        Group {
            if mode == .full {
                Circle()
                    .fill(MoneyMapOrbChrome.hubTintFill(accent: accent, isDark: colorScheme == .dark))
            } else {
                Circle()
                    .fill(.ultraThinMaterial)
            }
        }
        .overlay(
            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: [accent, .purple.opacity(0.75)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
        )
    }

    @ViewBuilder
    private func nodeOrbBackground(node: MoneyMapNode, diameter: CGFloat, isHighlighted: Bool) -> some View {
        let stroke = node.accentColor.opacity(isHighlighted ? 0.95 : 0.55)
        let lineWidth: CGFloat = isHighlighted ? 2.5 : 1.5
        Group {
            if mode == .full {
                Circle()
                    .fill(MoneyMapOrbChrome.nodeTintFill(isDark: colorScheme == .dark))
            } else {
                Circle()
                    .fill(.ultraThinMaterial)
            }
        }
        .frame(width: diameter, height: diameter)
        .overlay(Circle().strokeBorder(stroke, lineWidth: lineWidth))
    }
}

private extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
