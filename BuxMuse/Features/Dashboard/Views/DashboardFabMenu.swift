//
//  DashboardFabMenu.swift
//  BuxMuse — Dashboard Expense FAB: iPad command arc + iPhone touch dock.
//

import SwiftUI

struct DashboardFabItem: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let action: () -> Void
}

struct DashboardFabAnchorPreferenceKey: PreferenceKey {
    static var defaultValue: CGPoint? = nil

    static func reduce(value: inout CGPoint?, nextValue: () -> CGPoint?) {
        if let next = nextValue() {
            value = next
        }
    }
}

extension View {
    /// Reports the Expense (+) circle center for iPad HUD arc deployment.
    func dashboardFabAnchor(circleDiameter: CGFloat) -> some View {
        background {
            GeometryReader { proxy in
                let frame = proxy.frame(in: .named("dashboardOverlay"))
                let center = CGPoint(
                    x: frame.midX,
                    y: frame.minY + 10 + circleDiameter * 0.5
                )
                Color.clear.preference(key: DashboardFabAnchorPreferenceKey.self, value: center)
            }
        }
    }
}

struct DashboardFabMenuOverlay: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var themeManager: ThemeManager

    @Binding var isExpanded: Bool
    let studioEnabled: Bool
    let onManualEntry: () -> Void
    let onScanReceipt: () -> Void
    let onNewInvoice: () -> Void
    let onShortcut: () -> Void
    let onDismiss: () -> Void
    let onFullyClosed: () -> Void
    var fabAnchor: CGPoint? = nil

    @State private var deployed = false

    var body: some View {
        ZStack {
            if BuxPadIdiom.isPad {
                Color.black.opacity(colorScheme == .dark ? 0.28 : 0.14)
                    .opacity(deployed ? 1 : 0)
                    .ignoresSafeArea()
                    .onTapGesture(perform: onDismiss)
            } else {
                DashboardFabPhoneBackdrop(colorScheme: colorScheme, onDismiss: onDismiss)
            }

            if BuxPadIdiom.isPad {
                DashboardFabCommandArc(
                    fabAnchor: fabAnchor,
                    deployed: deployed,
                    studioEnabled: studioEnabled,
                    onManualEntry: onManualEntry,
                    onScanReceipt: onScanReceipt,
                    onNewInvoice: onNewInvoice,
                    onShortcut: onShortcut
                )
            } else {
                DashboardFabTouchDock(
                    fabAnchor: fabAnchor,
                    studioEnabled: studioEnabled,
                    onManualEntry: onManualEntry,
                    onScanReceipt: onScanReceipt,
                    onNewInvoice: onNewInvoice
                )
            }
        }
        .onAppear {
            guard !deployed else { return }
            if reduceMotion {
                deployed = true
            } else {
                withAnimation(.spring(response: 0.46, dampingFraction: 0.78)) {
                    deployed = true
                }
            }
        }
        .onChange(of: isExpanded) { _, expanded in
            if expanded {
                guard !deployed else { return }
                if reduceMotion {
                    deployed = true
                } else {
                    withAnimation(.spring(response: 0.46, dampingFraction: 0.78)) {
                        deployed = true
                    }
                }
            } else {
                retractOverlay()
            }
        }
    }

    private func retractOverlay() {
        if reduceMotion {
            deployed = false
            onFullyClosed()
            return
        }

        withAnimation(.spring(response: 0.38, dampingFraction: 0.84)) {
            deployed = false
        }

        let delay = BuxPadIdiom.isPad ? 0.36 : 0.12
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            onFullyClosed()
        }
    }
}

// MARK: - iPad — HUD command arc (deploys from Expense FAB)

private enum DashboardFabArcPortID: Hashable {
    case manual
    case studio
    case scan
    case invoice
    case shortcut
}

private struct DashboardFabArcPort: Identifiable {
    enum Kind {
        case action(() -> Void)
        case studioHub
    }

    let id: DashboardFabArcPortID
    let title: String
    let icon: String
    let kind: Kind
}

private struct DashboardFabCommandArc: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var themeManager: ThemeManager

    let fabAnchor: CGPoint?
    let deployed: Bool
    let studioEnabled: Bool
    let onManualEntry: () -> Void
    let onScanReceipt: () -> Void
    let onNewInvoice: () -> Void
    let onShortcut: () -> Void

    @ObservedObject private var settingsStore = SettingsStore.shared
    @State private var studioExpanded = false
    @State private var studioChildFactor: CGFloat = 0
    @State private var hoveredID: DashboardFabArcPortID?
    @State private var pluckingID: DashboardFabArcPortID?

    private let arcRadius: CGFloat = 132
    private let studioChildRadius: CGFloat = 84
    private let peripheralDiameter: CGFloat = 56
    private let centerHubDiameter: CGFloat = 58
    private let labelStackHeight: CGFloat = 32

    private var hudCanvasWidth: CGFloat { arcRadius * 2.5 }
    private var hudCanvasHeight: CGFloat { arcRadius * 1.7 }

    private var peripheralPorts: [DashboardFabArcPort] {
        var list = [
            DashboardFabArcPort(
                id: .manual,
                title: "Manual Entry",
                icon: "square.and.pencil",
                kind: .action(onManualEntry)
            )
        ]
        let shortcut = settingsStore.ipadFabShortcut
        let allowed = DashboardFabPadShortcut.availableShortcuts(studioEnabled: studioEnabled)
        if allowed.contains(shortcut) {
            list.append(
                DashboardFabArcPort(
                    id: .shortcut,
                    title: shortcut.titleKey,
                    icon: shortcut.icon,
                    kind: .action(onShortcut)
                )
            )
        }
        return list
    }

    private var studioChildren: [DashboardFabArcPort] {
        guard studioEnabled, studioExpanded else { return [] }
        return [
            DashboardFabArcPort(
                id: .scan,
                title: "Scan Receipt",
                icon: "camera.fill",
                kind: .action(onScanReceipt)
            ),
            DashboardFabArcPort(
                id: .invoice,
                title: "New Invoice",
                icon: "plus.rectangle.fill.on.folder.fill",
                kind: .action(onNewInvoice)
            )
        ]
    }

    private var accent: Color {
        themeManager.contrastAccentColor(for: colorScheme)
    }

    var body: some View {
        GeometryReader { geo in
            let origin = fabAnchor ?? CGPoint(x: geo.size.width * 0.5, y: geo.size.height * 0.34)
            let peripheralCount = peripheralPorts.count
            let deployFactor = deployed ? 1.0 : 0.0

            ZStack {
                ZStack {
                    hudArcRing(deployFactor: deployFactor)

                    ForEach(0..<peripheralCount, id: \.self) { index in
                        let target = peripheralOffset(index: index, count: peripheralCount, radius: arcRadius)
                        hudTargetLine(
                            to: CGSize(width: target.width * deployFactor, height: target.height * deployFactor),
                            emphasized: false
                        )
                        .opacity(deployFactor)
                        .animation(
                            reduceMotion ? nil : .easeOut(duration: 0.28).delay(peripheralMotionDelay(index: index, count: peripheralCount)),
                            value: deployed
                        )
                    }

                    ForEach(Array(studioChildren.enumerated()), id: \.element.id) { index, _ in
                        let target = studioChildOffset(index: index)
                        hudTargetLine(
                            to: CGSize(width: target.width * studioChildFactor, height: target.height * studioChildFactor),
                            emphasized: false
                        )
                        .opacity(studioChildFactor)
                    }

                    if let hoveredID,
                       let port = hoveredPeripheralPort(id: hoveredID),
                       let index = peripheralPorts.firstIndex(where: { $0.id == port.id }) {
                        hudTargetLine(
                            to: peripheralOffset(index: index, count: peripheralCount, radius: arcRadius),
                            emphasized: true
                        )
                    } else if let hoveredID,
                              let index = studioChildren.firstIndex(where: { $0.id == hoveredID }) {
                        hudTargetLine(
                            to: studioChildOffset(index: index),
                            emphasized: true
                        )
                    }

                    ForEach(Array(peripheralPorts.enumerated()), id: \.element.id) { index, port in
                        peripheralPort(
                            port,
                            index: index,
                            count: peripheralCount,
                            deployFactor: deployFactor
                        )
                    }

                    if studioEnabled {
                        centerHub(deployFactor: deployFactor)
                    }

                    ForEach(Array(studioChildren.enumerated()), id: \.element.id) { index, port in
                        studioChildPort(port, index: index)
                    }
                }
                .frame(width: hudCanvasWidth, height: hudCanvasHeight)
                .position(origin)
            }
        }
        .ignoresSafeArea()
        .onChange(of: deployed) { _, isDeployed in
            if !isDeployed {
                studioExpanded = false
                studioChildFactor = 0
            }
        }
        .onChange(of: studioExpanded) { _, expanded in
            if reduceMotion {
                studioChildFactor = expanded ? 1 : 0
                return
            }
            withAnimation(.spring(response: 0.36, dampingFraction: 0.8)) {
                studioChildFactor = expanded ? 1 : 0
            }
        }
        .onAppear {
            let allowed = DashboardFabPadShortcut.availableShortcuts(studioEnabled: studioEnabled)
            if !allowed.contains(settingsStore.ipadFabShortcut) {
                settingsStore.ipadFabShortcut = .themes
            }
        }
    }

    private func hoveredPeripheralPort(id: DashboardFabArcPortID) -> DashboardFabArcPort? {
        peripheralPorts.first(where: { $0.id == id })
    }

    private func hudArcRing(deployFactor: CGFloat) -> some View {
        DashboardFabUpperArcShape(radius: arcRadius)
            .trim(from: 0, to: deployFactor)
            .stroke(
                accent.opacity(colorScheme == .dark ? 0.78 : 0.62),
                style: StrokeStyle(lineWidth: 1.75, lineCap: .round)
            )
            .frame(width: hudCanvasWidth, height: hudCanvasHeight)
            .allowsHitTesting(false)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.34), value: deployed)
    }

    private func hudTargetLine(to offset: CGSize, emphasized: Bool) -> some View {
        DashboardFabHUDSpokeShape(target: offset)
            .stroke(
                accent.opacity(emphasized ? 0.9 : 0.38),
                style: StrokeStyle(
                    lineWidth: emphasized ? 2 : 1.25,
                    lineCap: .round,
                    dash: emphasized ? [] : [4, 6]
                )
            )
            .frame(width: hudCanvasWidth, height: hudCanvasHeight)
            .allowsHitTesting(false)
    }

    @ViewBuilder
    private func centerHub(deployFactor: CGFloat) -> some View {
        let isHovered = hoveredID == .studio
        let isPlucking = pluckingID == .studio
        let hubScale = (0.35 + 0.65 * deployFactor) * (isPlucking ? 1.1 : 1) * (isHovered ? 1.04 : 1)
        let labelYOffset = (centerHubDiameter * 0.5 + 6 + labelStackHeight * 0.5) * deployFactor

        Button {
            handleStudioHubTap()
        } label: {
            ZStack {
                DashboardFabHUDReticle(
                    accent: accent,
                    active: isHovered || isPlucking || studioExpanded,
                    diameter: centerHubDiameter,
                    emphasizeInnerRing: isHovered || isPlucking || studioExpanded
                )

                Image(systemName: studioExpanded ? "chevron.down" : "sparkles")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(accent.opacity(isHovered || isPlucking ? 1 : 0.9))
                    .scaleEffect(isPlucking ? 0.88 : 1)
            }
        }
        .buttonStyle(.plain)
        .frame(width: centerHubDiameter + 12, height: centerHubDiameter + 12)
        .contentShape(Circle())
        .scaleEffect(hubScale)
        .opacity(max(deployFactor, 0.001))
        .animation(
            reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.76)
                .delay(deployed ? 0 : 0.14),
            value: deployed
        )
        .animation(.spring(response: 0.28, dampingFraction: 0.62), value: isPlucking)
        .animation(.easeOut(duration: 0.16), value: isHovered)
        .onContinuousHover { phase in
            switch phase {
            case .active: hoveredID = .studio
            case .ended: if hoveredID == .studio { hoveredID = nil }
            }
        }
        .accessibilityLabel(studioExpanded ? "Collapse Studio" : "Studio")

        BuxCatalogDynamicText(key: "Studio")
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(isHovered || isPlucking ? accent : themeManager.labelPrimary(for: colorScheme))
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background {
                Capsule()
                    .fill(themeManager.cardFill(for: colorScheme).opacity(isHovered ? 1 : 0.94))
                    .overlay {
                        Capsule()
                            .stroke(themeManager.themedCardStroke(for: colorScheme), lineWidth: 0.5)
                    }
            }
            .opacity(deployFactor)
            .offset(y: labelYOffset)
            .allowsHitTesting(false)
    }

    private func handleStudioHubTap() {
        #if canImport(UIKit)
        if !reduceMotion {
            UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.8)
        }
        #endif
        withAnimation(.spring(response: 0.38, dampingFraction: 0.8)) {
            studioExpanded.toggle()
        }
    }

    private func peripheralPort(
        _ port: DashboardFabArcPort,
        index: Int,
        count: Int,
        deployFactor: CGFloat
    ) -> some View {
        portButton(
            port,
            diameter: peripheralDiameter,
            target: peripheralOffset(index: index, count: count, radius: arcRadius),
            deployFactor: deployFactor,
            motionDelay: peripheralMotionDelay(index: index, count: count)
        )
    }

    private func studioChildPort(
        _ port: DashboardFabArcPort,
        index: Int
    ) -> some View {
        portButton(
            port,
            diameter: peripheralDiameter * 0.92,
            target: studioChildOffset(index: index),
            deployFactor: studioChildFactor,
            motionDelay: Double(index) * 0.06,
            tracksStudioChildren: true
        )
    }

    private func portButton(
        _ port: DashboardFabArcPort,
        diameter: CGFloat,
        target: CGSize,
        deployFactor: CGFloat,
        motionDelay: Double,
        tracksStudioChildren: Bool = false
    ) -> some View {
        let isHovered = hoveredID == port.id
        let isPlucking = pluckingID == port.id
        let portOffset = CGSize(
            width: target.width * deployFactor,
            height: target.height * deployFactor
        )
        let labelYOffset = (diameter * 0.5 + 6 + labelStackHeight * 0.5) * deployFactor
        let motion = Animation.spring(response: 0.4, dampingFraction: 0.76).delay(motionDelay)

        return ZStack {
            Button {
                handlePortTap(port)
            } label: {
                ZStack {
                    DashboardFabHUDReticle(
                        accent: accent,
                        active: isHovered || isPlucking,
                        diameter: diameter,
                        emphasizeInnerRing: isHovered || isPlucking
                    )

                    Image(systemName: port.icon)
                        .font(.system(size: diameter * 0.38, weight: .semibold))
                        .foregroundStyle(accent.opacity(isHovered || isPlucking ? 1 : 0.9))
                        .scaleEffect(isPlucking ? 0.88 : 1)
                }
            }
            .buttonStyle(.plain)
            .frame(width: diameter + 12, height: diameter + 12)
            .contentShape(Circle())
            .scaleEffect(portScale(factor: deployFactor, isHovered: isHovered, isPlucking: isPlucking))
            .opacity(max(deployFactor, 0.001))
            .offset(x: portOffset.width, y: portOffset.height)
            .animation(reduceMotion ? nil : motion, value: tracksStudioChildren ? studioChildFactor : deployFactor)
            .animation(.spring(response: 0.28, dampingFraction: 0.62), value: isPlucking)
            .animation(.easeOut(duration: 0.16), value: isHovered)
            .onContinuousHover { phase in
                switch phase {
                case .active: hoveredID = port.id
                case .ended: if hoveredID == port.id { hoveredID = nil }
                }
            }
            .accessibilityLabel(port.title)

            BuxCatalogDynamicText(key: port.title)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(isHovered || isPlucking ? accent : themeManager.labelPrimary(for: colorScheme))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background {
                    Capsule()
                        .fill(themeManager.cardFill(for: colorScheme).opacity(isHovered ? 1 : 0.94))
                        .overlay {
                            Capsule()
                                .stroke(themeManager.themedCardStroke(for: colorScheme), lineWidth: 0.5)
                        }
                }
                .frame(minWidth: diameter + 16)
                .opacity(deployFactor)
                .offset(x: portOffset.width, y: portOffset.height + labelYOffset)
                .allowsHitTesting(false)
        }
    }

    private func portScale(factor: CGFloat, isHovered: Bool, isPlucking: Bool) -> CGFloat {
        var scale = 0.2 + 0.8 * factor
        if isPlucking { scale *= 1.12 }
        if isHovered { scale *= 1.05 }
        return scale
    }

    private func handlePortTap(_ port: DashboardFabArcPort) {
        #if canImport(UIKit)
        if !reduceMotion {
            UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.8)
        }
        #endif

        switch port.kind {
        case .studioHub:
            break
        case .action(let action):
            if reduceMotion {
                action()
                return
            }
            pluckingID = port.id
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                pluckingID = nil
                action()
            }
        }
    }

    private func peripheralMotionDelay(index: Int, count: Int) -> Double {
        if deployed { return Double(index) * 0.08 }
        return Double(count - 1 - index) * 0.07
    }

    private func peripheralOffset(index: Int, count: Int, radius: CGFloat) -> CGSize {
        if count == 1 {
            return CGSize(width: -radius * 0.95, height: -radius * 0.35)
        }
        switch index {
        case 0:
            return CGSize(width: -radius * 0.95, height: -radius * 0.35)
        default:
            return CGSize(width: radius * 0.95, height: -radius * 0.35)
        }
    }

    private func studioChildOffset(index: Int) -> CGSize {
        switch index {
        case 0:
            return CGSize(width: -studioChildRadius * 0.78, height: -studioChildRadius * 0.62)
        default:
            return CGSize(width: studioChildRadius * 0.78, height: -studioChildRadius * 0.62)
        }
    }
}

/// Hub-to-port spoke in canvas space — origin is always the frame center (Studio / FAB hub).
private struct DashboardFabHUDSpokeShape: Shape {
    var target: CGSize

    func path(in rect: CGRect) -> Path {
        let hub = CGPoint(x: rect.midX, y: rect.midY)
        var path = Path()
        path.move(to: hub)
        path.addLine(to: CGPoint(x: hub.x + target.width, y: hub.y + target.height))
        return path
    }
}

private struct DashboardFabUpperArcShape: Shape {
    var radius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(180),
            endAngle: .degrees(0),
            clockwise: false
        )
        return path
    }
}

private struct DashboardFabHUDReticle: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager

    let accent: Color
    let active: Bool
    let diameter: CGFloat
    var emphasizeInnerRing: Bool = false

    private var themeManagerFill: Color {
        themeManager.cardFill(for: colorScheme)
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(themeManagerFill.opacity(emphasizeInnerRing ? 0.96 : (active ? 0.92 : 0.82)))
                .frame(width: diameter, height: diameter)

            Circle()
                .stroke(accent.opacity(active ? 0.95 : 0.65), lineWidth: active ? 2 : 1.5)
                .frame(width: diameter, height: diameter)

            Circle()
                .stroke(
                    accent.opacity(emphasizeInnerRing ? 0.85 : (active ? 0.3 : 0.18)),
                    lineWidth: emphasizeInnerRing ? 2 : 1
                )
                .frame(width: diameter * (emphasizeInnerRing ? 0.72 : 0.58), height: diameter * (emphasizeInnerRing ? 0.72 : 0.58))

            if !emphasizeInnerRing {
                ForEach(0..<4, id: \.self) { quadrant in
                    DashboardFabHUDBracket()
                        .stroke(accent.opacity(active ? 0.95 : 0.62), lineWidth: active ? 2 : 1.5)
                        .frame(width: diameter * 0.38, height: diameter * 0.38)
                        .rotationEffect(.degrees(Double(quadrant) * 90))
                }
            }
        }
        .animation(.easeOut(duration: 0.18), value: emphasizeInnerRing)
        .animation(.easeOut(duration: 0.18), value: active)
    }
}

private struct DashboardFabHUDBracket: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let inset: CGFloat = 2
        let arm = min(rect.width, rect.height) * 0.55
        path.move(to: CGPoint(x: rect.minX + inset, y: rect.minY + arm))
        path.addLine(to: CGPoint(x: rect.minX + inset, y: rect.minY + inset))
        path.addLine(to: CGPoint(x: rect.minX + arm, y: rect.minY + inset))
        return path
    }
}

// MARK: - iPhone backdrop — soft scrim only

private struct DashboardFabPhoneBackdrop: View {
    let colorScheme: ColorScheme
    let onDismiss: () -> Void

    var body: some View {
        Color.black.opacity(colorScheme == .dark ? 0.22 : 0.14)
            .ignoresSafeArea()
            .onTapGesture(perform: onDismiss)
    }
}

// MARK: - iPhone — centered touch dock + Studio mini row

private struct DashboardFabTouchDock: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var themeManager: ThemeManager

    let fabAnchor: CGPoint?
    let studioEnabled: Bool
    let onManualEntry: () -> Void
    let onScanReceipt: () -> Void
    let onNewInvoice: () -> Void

    @State private var appeared = false
    @State private var studioExpanded = false

    private var accent: Color {
        themeManager.contrastAccentColor(for: colorScheme)
    }

    private let actionDiameter: CGFloat = 60
    private let studioDiameter: CGFloat = 52

    var body: some View {
        GeometryReader { geo in
            let anchorY = fabAnchor?.y ?? geo.size.height * 0.42
            let dockY = min(anchorY + 108, geo.size.height - 128)

            VStack(spacing: 16) {
                if studioEnabled, studioExpanded {
                    HStack(spacing: 28) {
                        touchAction(
                            title: "Scan Receipt",
                            icon: "camera.fill",
                            diameter: studioDiameter,
                            delay: 0.05,
                            action: onScanReceipt
                        )
                        touchAction(
                            title: "New Invoice",
                            icon: "plus.rectangle.fill.on.folder.fill",
                            diameter: studioDiameter,
                            delay: 0.1,
                            action: onNewInvoice
                        )
                    }
                    .transition(.scale(scale: 0.88).combined(with: .opacity))
                }

                HStack(spacing: 28) {
                    touchAction(
                        title: "Manual Entry",
                        icon: "square.and.pencil",
                        diameter: actionDiameter,
                        delay: 0,
                        action: onManualEntry
                    )

                    if studioEnabled {
                        Button {
                            #if canImport(UIKit)
                            if !reduceMotion {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.75)
                            }
                            #endif
                            withAnimation(.spring(response: 0.34, dampingFraction: 0.8)) {
                                studioExpanded.toggle()
                            }
                        } label: {
                            touchActionLabel(
                                title: "Studio",
                                icon: studioExpanded ? "chevron.down" : "sparkles",
                                diameter: actionDiameter,
                                highlighted: studioExpanded
                            )
                        }
                        .buttonStyle(DashboardFabTouchPressStyle(reduceMotion: reduceMotion))
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .background {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(themeManager.cardFill(for: colorScheme))
                    .overlay {
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(themeManager.themedCardStroke(for: colorScheme), lineWidth: 0.6)
                    }
                    .shadow(color: .black.opacity(colorScheme == .dark ? 0.28 : 0.1), radius: 18, y: 8)
            }
            .frame(maxWidth: min(geo.size.width - 48, 340))
            .scaleEffect(appeared ? 1 : (reduceMotion ? 1 : 0.9))
            .opacity(appeared ? 1 : 0)
            .position(x: geo.size.width * 0.5, y: dockY)
        }
        .onAppear {
            guard !appeared else { return }
            if reduceMotion {
                appeared = true
            } else {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.8)) {
                    appeared = true
                }
            }
        }
    }

    private func touchAction(
        title: String,
        icon: String,
        diameter: CGFloat,
        delay: Double,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: {
            #if canImport(UIKit)
            if !reduceMotion {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred(intensity: 0.85)
            }
            #endif
            action()
        }) {
            touchActionLabel(title: title, icon: icon, diameter: diameter, highlighted: false)
        }
        .buttonStyle(DashboardFabTouchPressStyle(reduceMotion: reduceMotion))
        .animation(
            reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.78).delay(delay),
            value: appeared
        )
    }

    private func touchActionLabel(
        title: String,
        icon: String,
        diameter: CGFloat,
        highlighted: Bool
    ) -> some View {
        VStack(spacing: 8) {
            BuxHeroActionCircle(diameter: diameter) {
                Image(systemName: icon)
                    .font(.system(size: diameter * 0.36, weight: .semibold))
                    .foregroundStyle(accent)
            }
            .overlay {
                if highlighted {
                    Circle()
                        .stroke(accent.opacity(0.55), lineWidth: 2)
                        .frame(width: diameter + 4, height: diameter + 4)
                }
            }

            BuxCatalogDynamicText(key: title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(themeManager.labelSecondary(for: colorScheme))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: max(diameter + 12, 76))
        }
    }
}

private struct DashboardFabTouchPressStyle: ButtonStyle {
    let reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.94 : 1)
            .animation(.spring(response: 0.24, dampingFraction: 0.62), value: configuration.isPressed)
    }
}
