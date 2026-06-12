//
//  BuxCoachMarkCalloutLayout.swift
//  BuxMuse
//

import SwiftUI

enum BuxCoachMarkTailEdge {
    case top
    case bottom
}

struct BuxCoachMarkPlacement {
    let cardRect: CGRect
    let tailEdge: BuxCoachMarkTailEdge
    let tailAnchorX: CGFloat
    let highlightRect: CGRect

    var stackOrigin: CGPoint {
        let tailH = BuxCoachMarkCalloutLayout.tailHeight
        switch tailEdge {
        case .top:
            return CGPoint(x: cardRect.minX, y: cardRect.minY - tailH)
        case .bottom:
            return CGPoint(x: cardRect.minX, y: cardRect.minY)
        }
    }
}

enum BuxCoachMarkCalloutLayout {
    static let estimatedCardHeight: CGFloat = 248
    static let tailHeight: CGFloat = 10
    static let tailWidth: CGFloat = 18
    static let gap: CGFloat = 10
    static let highlightPadding: CGFloat = 8

    static func cardWidth(for screenWidth: CGFloat) -> CGFloat {
        min(320, screenWidth - 32)
    }

    static func placement(
        anchorFrame: CGRect,
        cardHeight: CGFloat,
        in screenSize: CGSize,
        safeAreaInsets: EdgeInsets
    ) -> BuxCoachMarkPlacement {
        let padded = anchorFrame.insetBy(dx: -highlightPadding, dy: -highlightPadding)
        let minX = safeAreaInsets.leading + 16
        let maxX = screenSize.width - safeAreaInsets.trailing - 16
        let minY = safeAreaInsets.top + 12
        let maxY = screenSize.height - safeAreaInsets.bottom - 12

        let cardW = cardWidth(for: screenSize.width)
        let cardH = max(180, cardHeight)
        let stackH = cardH + tailHeight

        let spaceAbove = padded.minY - minY
        let spaceBelow = maxY - padded.maxY
        let preferBelow = spaceBelow >= stackH + gap + 8
            || spaceBelow > spaceAbove

        let tailEdge: BuxCoachMarkTailEdge
        let stackTop: CGFloat

        if preferBelow {
            tailEdge = .top
            stackTop = min(padded.maxY + gap, maxY - stackH)
        } else {
            tailEdge = .bottom
            stackTop = max(padded.minY - gap - stackH, minY)
        }

        var cardMidX = padded.midX
        let halfW = cardW / 2
        cardMidX = min(max(cardMidX, minX + halfW), maxX - halfW)

        let cardTop = tailEdge == .top ? stackTop + tailHeight : stackTop
        let cardRect = CGRect(
            x: cardMidX - halfW,
            y: cardTop,
            width: cardW,
            height: cardH
        )

        let tailMinX = cardRect.minX + 24
        let tailMaxX = cardRect.maxX - 24
        let tailAnchorX = min(max(padded.midX, tailMinX), tailMaxX)

        return BuxCoachMarkPlacement(
            cardRect: cardRect,
            tailEdge: tailEdge,
            tailAnchorX: tailAnchorX,
            highlightRect: padded
        )
    }
}

private struct TutorialScrimShape: Shape {
    let highlight: CGRect?

    func path(in rect: CGRect) -> Path {
        var path = Path(rect)
        if let highlight {
            path.addPath(Path(roundedRect: highlight, cornerRadius: 16, style: .continuous))
        }
        return path
    }
}

struct TutorialScrimLayer: View {
    let highlight: CGRect?

    var body: some View {
        TutorialScrimShape(highlight: highlight)
            .fill(Color.black.opacity(0.52), style: FillStyle(eoFill: true))
            .allowsHitTesting(false)
    }
}

struct BuxCoachMarkTail: View {
    let edge: BuxCoachMarkTailEdge
    let color: Color

    var body: some View {
        BuxCoachMarkTailShape(edge: edge)
            .fill(color)
            .frame(width: BuxCoachMarkCalloutLayout.tailWidth, height: BuxCoachMarkCalloutLayout.tailHeight)
    }
}

private struct BuxCoachMarkTailShape: Shape {
    let edge: BuxCoachMarkTailEdge

    func path(in rect: CGRect) -> Path {
        var path = Path()
        switch edge {
        case .bottom:
            path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        case .top:
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        }
        path.closeSubpath()
        return path
    }
}

struct BuxCoachMarkHighlightRing: View {
    let rect: CGRect
    let accent: Color
    @State private var pulse = false

    var body: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(accent.opacity(pulse ? 0.95 : 0.55), lineWidth: pulse ? 2.5 : 1.5)
            .frame(width: rect.width, height: rect.height)
            .scaleEffect(pulse ? 1.04 : 1.0)
            .offset(x: rect.minX, y: rect.minY)
            .allowsHitTesting(false)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
    }
}
