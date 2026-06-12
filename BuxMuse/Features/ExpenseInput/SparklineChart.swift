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
    var progress: Double = 1
    var useGPUReveal: Bool = true
    var rasterizesChart: Bool = true

    var body: some View {
        Group {
            if useGPUReveal {
                SparklineChartLayer(
                    points: points,
                    color: color,
                    showAreaFill: showAreaFill,
                    rasterizesChart: rasterizesChart
                )
                    .equatable()
                    .buxGPUChartReveal(progress: progress)
            } else {
                SparklineChartLayer(
                    points: points,
                    color: color,
                    showAreaFill: showAreaFill,
                    rasterizesChart: rasterizesChart
                )
                    .equatable()
            }
        }
    }
}

private struct SparklineChartLayer: View, Equatable {
    let points: [Double]
    let color: Color
    let showAreaFill: Bool
    var rasterizesChart: Bool = true

    private var yDomain: ClosedRange<Double> {
        BuxChartMotion.paddedYDomain(for: points)
    }

    static func == (lhs: SparklineChartLayer, rhs: SparklineChartLayer) -> Bool {
        lhs.points == rhs.points && lhs.color == rhs.color && lhs.showAreaFill == rhs.showAreaFill
    }

    var body: some View {
        Chart {
            ForEach(Array(points.enumerated()), id: \.offset) { index, point in
                if showAreaFill {
                    AreaMark(
                        x: .value("Day", index),
                        y: .value("Amount", point)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [color.opacity(0.26), color.opacity(0.04), color.opacity(0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }

                LineMark(
                    x: .value("Day", index),
                    y: .value("Amount", point)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(color)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(domain: yDomain)
        .chartPlotStyle { plotArea in
            plotArea.padding(.vertical, 4).padding(.horizontal, 2)
        }
        .modifier(ExpenseChartRasterizationModifier(enabled: rasterizesChart))
    }
}
