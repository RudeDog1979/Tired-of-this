//
//  StudioUnlockAnimationView.swift
//  BuxMuse
//
//  Standalone blueprint-style unlock overlay — vector only, resolution independent.
//

import SwiftUI

// MARK: - Unlock overlay

struct StudioUnlockAnimationView: View {
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    @Binding var isPresented: Bool
    var onMidpointReveal: (() -> Void)?

    @State private var gridOpacity: CGFloat = 0
    @State private var didRevealStudio = false
    @State private var toolDrawProgress: [CGFloat] = Array(repeating: 0, count: StudioBlueprintTool.allCases.count)
    @State private var glowPulse: CGFloat = 0
    @State private var wireframeOpacity: CGFloat = 1
    @State private var symbolOpacity: CGFloat = 0
    @State private var symbolLift: CGFloat = 1
    @State private var titleStrokeProgress: CGFloat = 0
    @State private var titleFillOpacity: CGFloat = 0
    @State private var titleBlur: CGFloat = 10
    @State private var sheetOpacity: CGFloat = 1
    @State private var constellationOpacity: CGFloat = 1
    @State private var constellationScale: CGFloat = 1

    private let blueprintInk = Color(red: 0.72, green: 0.88, blue: 1.0)
    private let blueprintPaper = Color(red: 0.04, green: 0.11, blue: 0.24)
    private let blueprintGridMajor = Color(red: 0.55, green: 0.78, blue: 0.95).opacity(0.14)
    private let blueprintGridMinor = Color(red: 0.55, green: 0.78, blue: 0.95).opacity(0.07)

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let unit = min(w, h)
            let center = CGPoint(x: w * 0.5, y: h * 0.38)
            let orbitRadius = unit * 0.26
            let toolSize = unit * 0.14
            let lineWidth = max(0.8, unit * 0.0032)

            ZStack {
                blueprintPaper
                    .opacity(sheetOpacity)
                    .ignoresSafeArea()

                RadialGradient(
                    colors: [.clear, blueprintPaper.opacity(0.55)],
                    center: .center,
                    startRadius: unit * 0.2,
                    endRadius: unit * 0.85
                )
                .opacity(sheetOpacity * gridOpacity)
                .ignoresSafeArea()

                BlueprintGridLayer(
                    size: geo.size,
                    majorColor: blueprintGridMajor,
                    minorColor: blueprintGridMinor,
                    marginColor: blueprintInk.opacity(0.18)
                )
                .opacity(gridOpacity * sheetOpacity)

                BlueprintSheetMargin(
                    size: geo.size,
                    ink: blueprintInk.opacity(0.22),
                    stampText: BuxCatalogLabel.string("BUXMUSE STUDIO", locale: appSettingsManager.interfaceLocale)
                )
                    .opacity(gridOpacity * 0.85 * sheetOpacity)

                ZStack {
                    ForEach(Array(StudioBlueprintTool.allCases.enumerated()), id: \.element.id) { index, tool in
                        let angle = (Double(index) / Double(StudioBlueprintTool.allCases.count)) * 2 * .pi - .pi / 2
                        let x = center.x + CGFloat(cos(angle)) * orbitRadius
                        let y = center.y + CGFloat(sin(angle)) * orbitRadius

                        StudioToolOrbitItem(
                            tool: tool,
                            drawProgress: toolDrawProgress[index],
                            wireframeOpacity: wireframeOpacity,
                            symbolOpacity: symbolOpacity,
                            symbolLift: symbolLift,
                            glowPulse: glowPulse,
                            toolSize: toolSize,
                            lineWidth: lineWidth,
                            ink: blueprintInk,
                            glowColor: blueprintInk.opacity(0.35 + glowPulse * 0.25)
                        )
                        .position(x: x, y: y)
                    }
                }
                .opacity(constellationOpacity)
                .scaleEffect(constellationScale)

                StudioUnlockTitleBlock(
                    unit: unit,
                    strokeProgress: titleStrokeProgress,
                    fillOpacity: titleFillOpacity,
                    blur: titleBlur,
                    ink: blueprintInk,
                    title: BuxCatalogLabel.string("STUDIO MODE UNLOCKED", locale: appSettingsManager.interfaceLocale)
                )
                .position(x: w * 0.5, y: h * 0.72)
                .opacity(sheetOpacity)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(isPresented)
        .onAppear { startSequence() }
    }

    private func startSequence() {
        resetState()

        withAnimation(.easeOut(duration: 0.4)) {
            gridOpacity = 1
        }

        for index in StudioBlueprintTool.allCases.indices {
            let delay = 0.42 + Double(index) * 0.34
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.easeInOut(duration: 0.52)) {
                    toolDrawProgress[index] = 1
                }
            }
        }

        let drawEnd = 0.42 + Double(StudioBlueprintTool.allCases.count) * 0.34 + 0.55
        let exitFadeStart = drawEnd + 3.4
        let sequenceEnd = exitFadeStart + 0.58 + 0.5
        let midpoint = sequenceEnd * 0.5

        DispatchQueue.main.asyncAfter(deadline: .now() + midpoint) {
            revealStudioIfNeeded()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + drawEnd) {
            withAnimation(.easeOut(duration: 0.5)) {
                glowPulse = 1
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.48) {
                withAnimation(.easeOut(duration: 0.55)) {
                    glowPulse = 0
                }
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + drawEnd + 0.65) {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            withAnimation(.easeOut(duration: 0.38)) {
                wireframeOpacity = 0
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                symbolOpacity = 1
                symbolLift = 0
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + drawEnd + 1.05) {
            withAnimation(.easeInOut(duration: 0.55)) {
                titleStrokeProgress = 1
            }
            withAnimation(.easeOut(duration: 0.65)) {
                titleFillOpacity = 1
                titleBlur = 0
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + exitFadeStart) {
            withAnimation(.easeInOut(duration: 0.55)) {
                gridOpacity = 0
                sheetOpacity = 0
                constellationOpacity = 0
                constellationScale = 1.06
                titleFillOpacity = 0
                titleStrokeProgress = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.58) {
                withAnimation(.easeInOut(duration: 0.5)) {
                    isPresented = false
                }
            }
        }
    }

    private func revealStudioIfNeeded() {
        guard !didRevealStudio else { return }
        didRevealStudio = true
        onMidpointReveal?()
    }

    private func resetState() {
        didRevealStudio = false
        gridOpacity = 0
        toolDrawProgress = Array(repeating: 0, count: StudioBlueprintTool.allCases.count)
        glowPulse = 0
        wireframeOpacity = 1
        symbolOpacity = 0
        symbolLift = 1
        titleStrokeProgress = 0
        titleFillOpacity = 0
        titleBlur = 10
        sheetOpacity = 1
        constellationOpacity = 1
        constellationScale = 1
    }
}

// MARK: - Tool model

private enum StudioBlueprintTool: String, CaseIterable, Identifiable {
    case laptop, hammer, screwdriver, hardHat, pencil, ruler

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .laptop: return "laptopcomputer"
        case .hammer: return "hammer.fill"
        case .screwdriver: return "wrench.and.screwdriver.fill"
        case .hardHat: return "helmet.fill"
        case .pencil: return "pencil.and.ruler.fill"
        case .ruler: return "ruler.fill"
        }
    }

}

private struct BlueprintToolWireframeShape: Shape {
    let tool: StudioBlueprintTool

    func path(in rect: CGRect) -> Path {
        switch tool {
        case .laptop: BlueprintLaptopShape().path(in: rect)
        case .hammer: BlueprintHammerShape().path(in: rect)
        case .screwdriver: BlueprintScrewdriverShape().path(in: rect)
        case .hardHat: BlueprintHardHatShape().path(in: rect)
        case .pencil: BlueprintPencilShape().path(in: rect)
        case .ruler: BlueprintRulerShape().path(in: rect)
        }
    }
}

// MARK: - Orbit item

private struct StudioToolOrbitItem: View {
    let tool: StudioBlueprintTool
    let drawProgress: CGFloat
    let wireframeOpacity: CGFloat
    let symbolOpacity: CGFloat
    let symbolLift: CGFloat
    let glowPulse: CGFloat
    let toolSize: CGFloat
    let lineWidth: CGFloat
    let ink: Color
    let glowColor: Color

    var body: some View {
        ZStack {
            Circle()
                .fill(glowColor)
                .frame(width: toolSize * 1.35, height: toolSize * 1.35)
                .blur(radius: toolSize * 0.22)
                .opacity(glowPulse * 0.85)

            BlueprintToolWireframeShape(tool: tool)
                .trim(from: 0, to: drawProgress)
                .stroke(
                    ink.opacity(0.92),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                )
                .frame(width: toolSize, height: toolSize)
                .opacity(wireframeOpacity)
                .shadow(color: ink.opacity(0.45), radius: lineWidth * 2)

            Image(systemName: tool.symbolName)
                .font(.system(size: toolSize * 0.42, weight: .medium))
                .foregroundStyle(ink)
                .frame(width: toolSize, height: toolSize)
                .opacity(symbolOpacity)
                .offset(y: -toolSize * 0.08 * symbolLift)
                .shadow(color: ink.opacity(0.35), radius: toolSize * 0.06)
        }
        .frame(width: toolSize * 1.4, height: toolSize * 1.4)
    }
}

// MARK: - Title

private struct StudioUnlockTitleBlock: View {
    let unit: CGFloat
    let strokeProgress: CGFloat
    let fillOpacity: CGFloat
    let blur: CGFloat
    let ink: Color
    let title: String
    private var fontSize: CGFloat { unit * 0.042 }
    private var subSize: CGFloat { unit * 0.018 }

    private var titleFont: Font {
        .system(size: fontSize, weight: .bold, design: .default)
    }

    var body: some View {
        VStack(spacing: unit * 0.012) {
            ZStack {
                Text(title)
                    .font(titleFont)
                    .kerning(unit * 0.004)
                    .foregroundStyle(ink.opacity(0.9))
                    .opacity(fillOpacity)

                Text(title)
                    .font(titleFont)
                    .kerning(unit * 0.004)
                    .foregroundStyle(.clear)
                    .background(
                        BlueprintTitleOutline(progress: strokeProgress)
                            .stroke(ink, style: StrokeStyle(lineWidth: max(0.7, unit * 0.0028), lineCap: .round, lineJoin: .round))
                    )
                    .mask(
                        Text(title)
                            .font(titleFont)
                            .kerning(unit * 0.004)
                    )
                    .opacity(1 - fillOpacity * 0.85)
            }
            .blur(radius: blur)

            BuxCatalogDynamicText(key: "SHEET 01 · ISSUED")
                .font(.system(size: subSize, weight: .semibold, design: .monospaced))
                .kerning(unit * 0.003)
                .foregroundStyle(ink.opacity(0.45 * fillOpacity))
        }
        .multilineTextAlignment(.center)
    }
}

private struct BlueprintTitleOutline: Shape {
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let insetRect = rect.insetBy(dx: rect.width * 0.02, dy: rect.height * 0.18)
        return RoundedRectangle(cornerRadius: insetRect.height * 0.2, style: .continuous)
            .path(in: insetRect)
            .trimmedPath(from: 0, to: max(0.001, progress))
    }
}

// MARK: - Grid & sheet chrome

private struct BlueprintGridLayer: View {
    let size: CGSize
    let majorColor: Color
    let minorColor: Color
    let marginColor: Color

    var body: some View {
        Canvas { context, canvasSize in
            let spacingMajor = canvasSize.width * 0.08
            let spacingMinor = spacingMajor * 0.25

            var minor = Path()
            stride(from: 0, through: canvasSize.width, by: spacingMinor).forEach { x in
                minor.move(to: CGPoint(x: x, y: 0))
                minor.addLine(to: CGPoint(x: x, y: canvasSize.height))
            }
            stride(from: 0, through: canvasSize.height, by: spacingMinor).forEach { y in
                minor.move(to: CGPoint(x: 0, y: y))
                minor.addLine(to: CGPoint(x: canvasSize.width, y: y))
            }
            context.stroke(minor, with: .color(minorColor), lineWidth: 0.5)

            var major = Path()
            stride(from: 0, through: canvasSize.width, by: spacingMajor).forEach { x in
                major.move(to: CGPoint(x: x, y: 0))
                major.addLine(to: CGPoint(x: x, y: canvasSize.height))
            }
            stride(from: 0, through: canvasSize.height, by: spacingMajor).forEach { y in
                major.move(to: CGPoint(x: 0, y: y))
                major.addLine(to: CGPoint(x: canvasSize.width, y: y))
            }
            context.stroke(major, with: .color(majorColor), lineWidth: 1)

            let inset = canvasSize.width * 0.06
            let border = CGRect(
                x: inset,
                y: inset * 1.4,
                width: canvasSize.width - inset * 2,
                height: canvasSize.height - inset * 2.2
            )
            context.stroke(
                Path(roundedRect: border, cornerRadius: 2),
                with: .color(marginColor),
                lineWidth: 1.2
            )

            let tick = canvasSize.width * 0.04
            var ticks = Path()
            for i in 0..<5 {
                let t = border.minX + (border.width / 4) * CGFloat(i)
                ticks.move(to: CGPoint(x: t, y: border.maxY))
                ticks.addLine(to: CGPoint(x: t, y: border.maxY + tick * 0.35))
            }
            context.stroke(ticks, with: .color(marginColor.opacity(0.7)), lineWidth: 0.8)

            var axis = Path()
            axis.move(to: CGPoint(x: canvasSize.width * 0.5, y: border.minY))
            axis.addLine(to: CGPoint(x: canvasSize.width * 0.5, y: border.maxY))
            axis.move(to: CGPoint(x: border.minX, y: canvasSize.height * 0.38))
            axis.addLine(to: CGPoint(x: border.maxX, y: canvasSize.height * 0.38))
            context.stroke(axis, with: .color(marginColor.opacity(0.35)), style: StrokeStyle(lineWidth: 0.6, dash: [4, 6]))
        }
        .frame(width: size.width, height: size.height)
    }
}

private struct BlueprintSheetMargin: View {
    let size: CGSize
    let ink: Color
    let stampText: String

    var body: some View {
        Canvas { context, canvasSize in
            let inset = canvasSize.width * 0.06
            let corner = CGPoint(x: inset, y: inset * 1.4)
            var cross = Path()
            cross.move(to: CGPoint(x: corner.x + canvasSize.width * 0.08, y: corner.y))
            cross.addLine(to: CGPoint(x: corner.x, y: corner.y))
            cross.addLine(to: CGPoint(x: corner.x, y: corner.y + canvasSize.width * 0.08))
            context.stroke(cross, with: .color(ink), lineWidth: 1)

            let label = Text(stampText)
                .font(.system(size: canvasSize.width * 0.022, weight: .bold, design: .monospaced))
            context.draw(context.resolve(label), at: CGPoint(x: canvasSize.width * 0.5, y: inset * 0.75), anchor: .center)
        }
        .frame(width: size.width, height: size.height)
    }
}

// MARK: - Wireframe shapes (unit space 0…1)

private struct BlueprintLaptopShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var p = Path()
        let body = CGRect(x: w * 0.12, y: h * 0.18, width: w * 0.76, height: h * 0.52)
        p.addRoundedRect(in: body, cornerSize: CGSize(width: w * 0.04, height: w * 0.04))
        p.addRect(CGRect(x: w * 0.18, y: h * 0.24, width: w * 0.64, height: h * 0.36))
        var base = Path()
        base.move(to: CGPoint(x: w * 0.06, y: h * 0.72))
        base.addLine(to: CGPoint(x: w * 0.94, y: h * 0.72))
        base.addLine(to: CGPoint(x: w * 0.98, y: h * 0.88))
        base.addLine(to: CGPoint(x: w * 0.02, y: h * 0.88))
        base.closeSubpath()
        p.addPath(base)
        return p
    }
}

private struct BlueprintHammerShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var p = Path()
        p.addRect(CGRect(x: w * 0.08, y: h * 0.2, width: w * 0.36, height: h * 0.32))
        p.move(to: CGPoint(x: w * 0.44, y: h * 0.36))
        p.addLine(to: CGPoint(x: w * 0.88, y: h * 0.88))
        p.move(to: CGPoint(x: w * 0.5, y: h * 0.28))
        p.addLine(to: CGPoint(x: w * 0.5, y: h * 0.52))
        return p
    }
}

private struct BlueprintScrewdriverShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var p = Path()
        p.addRoundedRect(
            in: CGRect(x: w * 0.38, y: h * 0.06, width: w * 0.24, height: h * 0.22),
            cornerSize: CGSize(width: w * 0.06, height: w * 0.06)
        )
        p.move(to: CGPoint(x: w * 0.5, y: h * 0.28))
        p.addLine(to: CGPoint(x: w * 0.5, y: h * 0.72))
        p.move(to: CGPoint(x: w * 0.42, y: h * 0.78))
        p.addLine(to: CGPoint(x: w * 0.58, y: h * 0.92))
        p.addLine(to: CGPoint(x: w * 0.5, y: h * 0.72))
        return p
    }
}

private struct BlueprintHardHatShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var p = Path()
        p.addArc(
            center: CGPoint(x: w * 0.5, y: h * 0.52),
            radius: w * 0.36,
            startAngle: .degrees(200),
            endAngle: .degrees(-20),
            clockwise: false
        )
        p.addLine(to: CGPoint(x: w * 0.12, y: h * 0.62))
        p.addLine(to: CGPoint(x: w * 0.88, y: h * 0.62))
        p.move(to: CGPoint(x: w * 0.22, y: h * 0.38))
        p.addLine(to: CGPoint(x: w * 0.78, y: h * 0.38))
        p.addRect(CGRect(x: w * 0.44, y: h * 0.12, width: w * 0.12, height: h * 0.12))
        return p
    }
}

private struct BlueprintPencilShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var p = Path()
        p.move(to: CGPoint(x: w * 0.72, y: h * 0.1))
        p.addLine(to: CGPoint(x: w * 0.18, y: h * 0.86))
        p.move(to: CGPoint(x: w * 0.62, y: h * 0.18))
        p.addLine(to: CGPoint(x: w * 0.78, y: h * 0.34))
        p.move(to: CGPoint(x: w * 0.14, y: h * 0.82))
        p.addLine(to: CGPoint(x: w * 0.22, y: h * 0.92))
        p.addLine(to: CGPoint(x: w * 0.28, y: h * 0.86))
        return p
    }
}

private struct BlueprintRulerShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var p = Path()
        p.addRoundedRect(
            in: CGRect(x: w * 0.1, y: h * 0.38, width: w * 0.8, height: h * 0.24),
            cornerSize: CGSize(width: h * 0.04, height: h * 0.04)
        )
        for i in 0..<6 {
            let x = w * (0.18 + CGFloat(i) * 0.11)
            p.move(to: CGPoint(x: x, y: h * 0.38))
            p.addLine(to: CGPoint(x: x, y: h * (i % 2 == 0 ? 0.48 : 0.44)))
        }
        return p
    }
}
