//
//  MerchantBreakdownChart.swift
//  BuxMuse
//

import SwiftUI
import Charts

struct MerchantBreakdownChart: View {
    let breakdown: [(String, Double)]
    /// Caps rows in compact hero cards so bar labels don't overlap.
    var maxItems: Int? = nil

    @State private var isVisible = false

    private var displayItems: [(String, Double)] {
        guard let maxItems, breakdown.count > maxItems else { return breakdown }
        return Array(breakdown.prefix(maxItems))
    }

    private var merchantNames: [String] {
        displayItems.map(\.0)
    }

    private var merchantColors: [Color] {
        displayItems.indices.map { BuxChartColors.merchantColor(fallbackIndex: $0) }
    }

    /// ~22pt per row keeps y-axis labels readable in hero cards.
    static func compactHeight(itemCount: Int) -> CGFloat {
        max(44, CGFloat(max(itemCount, 1)) * 22)
    }

    var body: some View {
        Chart {
            ForEach(displayItems, id: \.0) { item in
                BarMark(
                    x: .value("Amount", isVisible ? item.1 : 0),
                    y: .value("Merchant", item.0)
                )
                .foregroundStyle(by: .value("Merchant", item.0))
            }
        }
        .chartLegend(.hidden)
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks { _ in
                AxisValueLabel()
                    .font(.system(size: 10, weight: .medium))
            }
        }
        .chartForegroundStyleScale(domain: merchantNames, range: merchantColors)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                isVisible = true
            }
        }
    }
}
