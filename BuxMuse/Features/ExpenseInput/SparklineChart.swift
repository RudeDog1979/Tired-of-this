//
//  SparklineChart.swift
//  BuxMuse
//

import SwiftUI
import Charts

struct SparklineChart: View {
    let points: [Double]
    let color: Color
    var showAreaFill: Bool = false
    @State private var isVisible = false
    
    var body: some View {
        Chart {
            ForEach(Array(points.enumerated()), id: \.offset) { index, point in
                if showAreaFill {
                    AreaMark(
                        x: .value("Day", index),
                        y: .value("Amount", isVisible ? point : 0)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [color.opacity(0.28), color.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }

                LineMark(
                    x: .value("Day", index),
                    y: .value("Amount", isVisible ? point : 0)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(color.gradient)
                .lineStyle(StrokeStyle(lineWidth: showAreaFill ? 2 : 1.5, lineCap: .round, lineJoin: .round))
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                isVisible = true
            }
        }
    }
}
