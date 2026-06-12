//
//  MonthlyTrendChart.swift
//  BuxMuse
//

import SwiftUI
import Charts

struct MonthlyTrendChart: View {
    let points: [Double]
    let prediction: String?
    var progress: Double = 1
    var useGPUReveal: Bool = true
    var rasterizesChart: Bool = true

    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager

    private var chartHeight: CGFloat {
        prediction == nil ? 56 : 48
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let prediction {
                Text(prediction)
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                    .lineLimit(1)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background {
                        Capsule()
                            .fill(themeManager.current.accentColor.opacity(0.1))
                    }
            }

            Group {
                if useGPUReveal {
                    MonthlyTrendChartLayer(
                        points: points,
                        colorScheme: colorScheme,
                        chartHeight: chartHeight,
                        rasterizesChart: rasterizesChart
                    )
                        .equatable()
                        .buxGPUChartReveal(progress: progress)
                } else {
                    MonthlyTrendChartLayer(
                        points: points,
                        colorScheme: colorScheme,
                        chartHeight: chartHeight,
                        rasterizesChart: rasterizesChart
                    )
                        .equatable()
                }
            }
        }
    }
}

private struct MonthlyTrendChartLayer: View, Equatable {
    let points: [Double]
    let colorScheme: ColorScheme
    let chartHeight: CGFloat
    var rasterizesChart: Bool = true

    private var yDomain: ClosedRange<Double> {
        BuxChartMotion.paddedYDomain(for: points)
    }

    static func == (lhs: MonthlyTrendChartLayer, rhs: MonthlyTrendChartLayer) -> Bool {
        lhs.points == rhs.points && lhs.colorScheme == rhs.colorScheme && lhs.chartHeight == rhs.chartHeight
    }

    var body: some View {
        Chart {
            ForEach(Array(points.enumerated()), id: \.offset) { index, point in
                AreaMark(
                    x: .value("Day", index),
                    y: .value("Amount", point)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(BuxChartColors.spendTrendGradient(for: colorScheme))

                LineMark(
                    x: .value("Day", index),
                    y: .value("Amount", point)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(BuxChartColors.spendTrend(for: colorScheme))
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }
        }
        .frame(height: chartHeight)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(domain: yDomain)
        .chartPlotStyle { plotArea in
            plotArea.padding(.vertical, 6).padding(.horizontal, 3)
        }
        .modifier(ExpenseChartRasterizationModifier(enabled: rasterizesChart))
    }
}
