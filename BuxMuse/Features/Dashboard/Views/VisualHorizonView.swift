//
//  VisualHorizonView.swift
//  BuxMuse
//
//  A premium, high-fidelity trend line background graphic for the dashboard.
//  Draws a smooth Bezier curve representing 7-day spending.
//

import SwiftUI

struct VisualHorizonView: View {
    @Environment(\.buxPadFlatDashboardChrome) private var padFlatChrome

    let points: [Double]
    let accentColor: Color
    var horizontalPadding: CGFloat = 0
    var cornerRadius: CGFloat = 28
    
    @State private var animates = false
    @State private var didReveal = false
    
    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            
            let startX = horizontalPadding
            let endX = width - horizontalPadding
            
            // 7 data points distributed from the left edge of the card to the right edge of the card
            let cgPoints = computePoints(in: geo.size, startX: startX, endX: endX)
            
            ZStack {
                // Clipped background wave fill and stroke
                ZStack {
                    // Volumetric gradient fill
                    HorizonCurveFillShape(points: cgPoints)
                        .fill(
                            LinearGradient(
                                colors: [accentColor.opacity(0.18), accentColor.opacity(0.0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    
                    // Blurred neon glow under stroke (skipped on iPad Home — blur is scroll-GPU heavy).
                    if !padFlatChrome {
                        HorizonCurveShape(points: cgPoints)
                            .stroke(accentColor.opacity(0.4), lineWidth: 4.5)
                            .blur(radius: 4)
                    }
                    
                    // Sharp primary stroke line
                    HorizonCurveShape(points: cgPoints)
                        .stroke(
                            LinearGradient(
                                colors: [accentColor, accentColor.opacity(0.75)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                        )
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                
                // Unclipped today dot sitting right on the edge of the card
                if let lastPoint = cgPoints.last {
                    ZStack {
                        // Halo glow rings
                        Circle()
                            .stroke(accentColor, lineWidth: 2)
                            .frame(width: 10, height: 10)
                            .scaleEffect(1.6)
                            .opacity(0.55)
                        
                        // 3D Glass orb sphere look (white radial core highlight)
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [.white, accentColor],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 5
                                )
                            )
                            .frame(width: 10, height: 10)
                            .shadow(
                                color: padFlatChrome ? .clear : accentColor,
                                radius: padFlatChrome ? 0 : 5
                            )
                    }
                    .position(lastPoint)
                }
            }
            .mask(
                Rectangle()
                    .frame(width: animates ? width + 20 : 0, height: height)
                    .frame(maxWidth: .infinity, alignment: .leading)
            )
            .onAppear {
                tryRevealHorizon()
            }
            .onChange(of: points) { _, _ in
                tryRevealHorizon()
            }
        }
    }

    private func tryRevealHorizon() {
        guard !didReveal, !points.isEmpty else { return }
        didReveal = true
        withAnimation(.spring(response: 3.8, dampingFraction: 0.96)) {
            animates = true
        }
    }
    
    private func computePoints(in size: CGSize, startX: CGFloat, endX: CGFloat) -> [CGPoint] {
        guard !points.isEmpty else {
            // Default elegant curved horizontal path when no data
            return (0..<7).map { i in
                let x = startX + (endX - startX) * CGFloat(i) / 6.0
                return CGPoint(x: x, y: size.height * 0.65)
            }
        }
        
        let maxVal = points.max() ?? 0.0
        let minVal = points.min() ?? 0.0
        let range = maxVal - minVal
        let divisor = range == 0 ? 1.0 : range
        
        return points.enumerated().map { i, val in
            let x = startX + (endX - startX) * CGFloat(i) / 6.0
            
            // Map values to y-coordinates in the range [0.35 * height, 0.75 * height]
            let relativeY = (val - minVal) / divisor
            let y = size.height * 0.75 - (size.height * 0.4 * CGFloat(relativeY))
            return CGPoint(x: x, y: y)
        }
    }
}

// Custom Shape for the smooth curve
struct HorizonCurveShape: Shape {
    let points: [CGPoint]
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard points.count > 1 else { return path }
        
        path.move(to: points[0])
        
        for i in 0..<points.count - 1 {
            let p1 = points[i]
            let p2 = points[i + 1]
            
            // Control points for Catmull-Rom spline approximation
            let p0 = i > 0 ? points[i - 1] : p1
            let p3 = i < points.count - 2 ? points[i + 2] : p2
            
            let cp1 = CGPoint(
                x: p1.x + (p2.x - p0.x) / 6,
                y: p1.y + (p2.y - p0.y) / 6
            )
            let cp2 = CGPoint(
                x: p2.x - (p3.x - p1.x) / 6,
                y: p2.y - (p3.y - p1.y) / 6
            )
            
            path.addCurve(to: p2, control1: cp1, control2: cp2)
        }
        
        return path
    }
}

// Custom Shape for the fill under the curve
struct HorizonCurveFillShape: Shape {
    let points: [CGPoint]
    
    func path(in rect: CGRect) -> Path {
        var path = HorizonCurveShape(points: points).path(in: rect)
        guard let first = points.first, let last = points.last else { return path }
        
        path.addLine(to: CGPoint(x: last.x, y: rect.height))
        path.addLine(to: CGPoint(x: first.x, y: rect.height))
        path.closeSubpath()
        
        return path
    }
}
