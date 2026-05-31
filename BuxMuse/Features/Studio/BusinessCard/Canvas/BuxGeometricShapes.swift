//
//  BuxGeometricShapes.swift
//  BuxMuse — proprietary geometric paths for Bux Canvas
//

import SwiftUI

enum BuxGeometricShapes {

    static func path(for type: CardShapeType, in rect: CGRect) -> Path {
        switch type {
        case .rectangle, .accentBar, .line, .badge:
            return Path(roundedRect: rect, cornerRadius: 0)
        case .circle, .star, .symbol:
            return Path(ellipseIn: rect)
        case .triangle:
            return triangle(in: rect, pointing: .up)
        case .triangleHalf:
            return rightTriangle(in: rect)
        case .diamond:
            return diamond(in: rect)
        case .hexagon:
            return regularPolygon(in: rect, sides: 6)
        case .quarterCircle:
            return quarterCircle(in: rect)
        case .parallelogram:
            return parallelogram(in: rect, skew: 0.22)
        case .chevron:
            return chevron(in: rect)
        case .semicircle:
            return semicircle(in: rect)
        }
    }

    private static func triangle(in rect: CGRect, pointing: TrianglePoint) -> Path {
        var p = Path()
        switch pointing {
        case .up:
            p.move(to: CGPoint(x: rect.midX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        }
        p.closeSubpath()
        return p
    }

    private static func rightTriangle(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }

    private static func diamond(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        p.closeSubpath()
        return p
    }

    private static func regularPolygon(in rect: CGRect, sides: Int) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        var p = Path()
        for i in 0..<sides {
            let angle = (Double(i) / Double(sides)) * 2 * .pi - .pi / 2
            let pt = CGPoint(x: center.x + CGFloat(cos(angle)) * radius, y: center.y + CGFloat(sin(angle)) * radius)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }

    private static func quarterCircle(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addArc(
            center: CGPoint(x: rect.minX, y: rect.maxY),
            radius: min(rect.width, rect.height),
            startAngle: .degrees(-90),
            endAngle: .degrees(0),
            clockwise: false
        )
        p.closeSubpath()
        return p
    }

    private static func parallelogram(in rect: CGRect, skew: CGFloat) -> Path {
        let offset = rect.width * skew
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + offset, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - offset, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }

    private static func chevron(in rect: CGRect) -> Path {
        let inset = rect.width * 0.18
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - inset, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + inset, y: rect.midY))
        p.closeSubpath()
        return p
    }

    private static func semicircle(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addArc(
            center: CGPoint(x: rect.midX, y: rect.maxY),
            radius: rect.width / 2,
            startAngle: .degrees(0),
            endAngle: .degrees(180),
            clockwise: true
        )
        p.closeSubpath()
        return p
    }

    private enum TrianglePoint { case up }
}

struct BuxGeometricShapeView: View {
    let type: CardShapeType
    let fill: AnyShapeStyle
    let stroke: Color?
    let strokeWidth: Double
    let cornerRadius: Double
    var symbolName: String? = nil

    var body: some View {
        GeometryReader { geo in
            let rect = CGRect(origin: .zero, size: geo.size)
            Group {
                switch type {
                case .rectangle, .accentBar:
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(fill)
                case .circle, .badge:
                    Circle().fill(fill)
                case .line:
                    Rectangle().fill(fill).frame(height: max(1, strokeWidth))
                case .star:
                    Image(systemName: "star.fill").resizable().scaledToFit().foregroundStyle(fill)
                case .symbol:
                    Image(systemName: symbolName ?? "star.fill").resizable().scaledToFit().foregroundStyle(fill)
                default:
                    BuxGeometricShapes.path(for: type, in: rect)
                        .fill(fill)
                }
            }
            .overlay {
                if let stroke, strokeWidth > 0, type != .line {
                    BuxGeometricShapes.path(for: type, in: rect)
                        .stroke(stroke, lineWidth: strokeWidth)
                }
            }
        }
    }
}
