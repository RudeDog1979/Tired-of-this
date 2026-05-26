//
//  MiniCategoryDonutChart.swift
//  BuxMuse
//
//  Compact category ring for the Total Spend hero card.
//

import SwiftUI
import Charts

struct MiniCategoryDonutChart: View {
    let breakdown: [(String, Double)]
    let accentColor: Color

    @State private var isVisible = false

    private var segments: [(name: String, amount: Double)] {
        Array(breakdown.prefix(4))
    }

    private var total: Double {
        max(segments.reduce(0) { $0 + $1.amount }, 0.01)
    }

    var body: some View {
        Chart {
            ForEach(Array(segments.enumerated()), id: \.offset) { index, item in
                SectorMark(
                    angle: .value("Amount", isVisible ? item.amount : 0),
                    innerRadius: .ratio(0.62),
                    angularInset: 1.5
                )
                .foregroundStyle(segmentColor(index))
            }
        }
        .chartLegend(.hidden)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.82)) {
                isVisible = true
            }
        }
        .accessibilityLabel("Category breakdown")
        .accessibilityValue(
            segments.map { "\($0.name) \(Int(($0.amount / total) * 100)) percent" }.joined(separator: ", ")
        )
    }

    private func segmentColor(_ index: Int) -> Color {
        let steps: [Double] = [1.0, 0.72, 0.48, 0.32]
        let step = steps[min(index, steps.count - 1)]
        return accentColor.opacity(step)
    }
}
