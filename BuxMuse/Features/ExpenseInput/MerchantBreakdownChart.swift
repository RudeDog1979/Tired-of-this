//
//  MerchantBreakdownChart.swift
//  BuxMuse
//

import SwiftUI
import Charts

struct MerchantBreakdownChart: View {
    let breakdown: [(String, Double)]
    var maxItems: Int? = nil
    var progress: Double = 1
    var useGPUReveal: Bool = true

    private var displayItems: [(String, Double)] {
        guard let maxItems, breakdown.count > maxItems else { return breakdown }
        return Array(breakdown.prefix(maxItems))
    }

    static func compactHeight(itemCount: Int) -> CGFloat {
        max(44, CGFloat(max(itemCount, 1)) * 22)
    }

    var body: some View {
        Group {
            if useGPUReveal {
                MerchantBreakdownChartLayer(items: displayItems)
                    .equatable()
                    .buxGPUChartReveal(progress: progress)
            } else {
                MerchantBreakdownChartLayer(items: displayItems)
                    .equatable()
            }
        }
    }
}

private struct MerchantBreakdownChartLayer: View, Equatable {
    let items: [(String, Double)]

    private var merchantNames: [String] {
        items.map(\.0)
    }

    private var merchantGradients: [LinearGradient] {
        items.indices.map { BuxChartColors.merchantGradient(fallbackIndex: $0) }
    }

    static func == (lhs: MerchantBreakdownChartLayer, rhs: MerchantBreakdownChartLayer) -> Bool {
        lhs.items.elementsEqual(rhs.items) { $0.0 == $1.0 && $0.1 == $1.1 }
    }

    var body: some View {
        Chart {
            ForEach(items, id: \.0) { item in
                BarMark(
                    x: .value("Amount", item.1),
                    y: .value("Merchant", item.0)
                )
                .foregroundStyle(by: .value("Merchant", item.0))
                .cornerRadius(5)
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
        .chartForegroundStyleScale(domain: merchantNames, range: merchantGradients)
        .drawingGroup(opaque: false, colorMode: .linear)
    }
}
