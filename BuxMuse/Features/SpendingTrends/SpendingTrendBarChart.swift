//
//  SpendingTrendBarChart.swift
//  BuxMuse
//

import SwiftUI
import Charts

struct SpendingTrendBarChart: View {
    let buckets: [SpendingTrendBarBucket]
    var progress: Double = 1
    var onSelectBucket: ((SpendingTrendBarBucket) -> Void)?

    var body: some View {
        SpendingTrendBarChartLayer(buckets: buckets, onSelectBucket: onSelectBucket)
            .equatable()
            .buxGPUChartReveal(progress: progress)
    }
}

private struct SpendingTrendBarChartLayer: View, Equatable {
    let buckets: [SpendingTrendBarBucket]
    let onSelectBucket: ((SpendingTrendBarBucket) -> Void)?

    static func == (lhs: SpendingTrendBarChartLayer, rhs: SpendingTrendBarChartLayer) -> Bool {
        lhs.buckets == rhs.buckets
    }

    var body: some View {
        Chart {
            ForEach(buckets) { bucket in
                BarMark(
                    x: .value("Period", bucket.shortLabel),
                    y: .value("Amount", bucket.amount)
                )
                .foregroundStyle(barGradient(for: bucket.gradientIndex))
                .cornerRadius(8)
                .opacity(bucket.amount > 0 ? 1 : 0.35)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                    .foregroundStyle(Color.primary.opacity(0.08))
                AxisValueLabel()
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .chartXAxis {
            AxisMarks { _ in
                AxisValueLabel()
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(height: 220)
        .overlay {
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    ForEach(buckets) { bucket in
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                onSelectBucket?(bucket)
                            }
                    }
                }
            }
        }
        .modifier(ExpenseChartRasterizationModifier(enabled: true))
    }

    private func barGradient(for index: Int) -> LinearGradient {
        let palette = BuxChartColors.categoryPalette
        let base = palette[abs(index) % palette.count]
        let accent = palette[(abs(index) + 2) % palette.count]
        return LinearGradient(
            colors: [base, accent.opacity(0.82)],
            startPoint: .bottom,
            endPoint: .top
        )
    }
}
