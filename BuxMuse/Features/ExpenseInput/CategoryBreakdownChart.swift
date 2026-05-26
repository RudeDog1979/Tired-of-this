//
//  CategoryBreakdownChart.swift
//  BuxMuse
//

import SwiftUI
import Charts

struct CategoryBreakdownChart: View {
    let breakdown: [(String, Double)]
    @State private var isVisible = false
    
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
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                isVisible = true
            }
        }
    }
}
