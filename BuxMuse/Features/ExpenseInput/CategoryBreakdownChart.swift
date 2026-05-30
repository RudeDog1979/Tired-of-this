//
//  CategoryBreakdownChart.swift
//  BuxMuse
//

import SwiftUI
import Charts

struct CategoryBreakdownChart: View {
    let breakdown: [(String, Double)]
    @State private var isVisible = false

    private var categoryNames: [String] {
        breakdown.map(\.0)
    }

    private var categoryColors: [Color] {
        breakdown.enumerated().map { index, item in
            BuxChartColors.color(forCategoryName: item.0, fallbackIndex: index)
        }
    }

    var body: some View {
        Chart {
            ForEach(breakdown, id: \.0) { item in
                BarMark(
                    x: .value("Amount", isVisible ? item.1 : 0),
                    y: .value("Category", item.0)
                )
                .foregroundStyle(by: .value("Category", item.0))
            }
        }
        .chartLegend(.hidden)
        .chartXAxis(.hidden)
        .chartForegroundStyleScale(domain: categoryNames, range: categoryColors)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                isVisible = true
            }
        }
    }
}
