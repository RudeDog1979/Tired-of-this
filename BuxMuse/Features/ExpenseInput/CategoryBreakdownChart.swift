//
//  CategoryBreakdownChart.swift
//  BuxMuse
//

import SwiftUI
import Charts

struct CategoryBreakdownChart: View {
    let breakdown: [(String, Double)]
    var customCategories: [ExpenseCategoryRecord] = []
    var progress: Double = 1
    var useGPUReveal: Bool = true
    var rasterizesChart: Bool = true

    var body: some View {
        Group {
            if useGPUReveal {
                CategoryBreakdownChartLayer(
                    breakdown: breakdown,
                    customCategories: customCategories,
                    rasterizesChart: rasterizesChart
                )
                    .equatable()
                    .buxGPUChartReveal(progress: progress)
            } else {
                CategoryBreakdownChartLayer(
                    breakdown: breakdown,
                    customCategories: customCategories,
                    rasterizesChart: rasterizesChart
                )
                    .equatable()
            }
        }
    }
}

private struct CategoryBreakdownChartLayer: View, Equatable {
    let breakdown: [(String, Double)]
    let customCategories: [ExpenseCategoryRecord]
    var rasterizesChart: Bool = true

    private var categoryNames: [String] {
        breakdown.map(\.0)
    }

    private var categoryGradients: [LinearGradient] {
        breakdown.enumerated().map { index, item in
            BuxChartColors.categoryGradient(
                forCategoryName: item.0,
                customCategories: customCategories,
                fallbackIndex: index
            )
        }
    }

    static func == (lhs: CategoryBreakdownChartLayer, rhs: CategoryBreakdownChartLayer) -> Bool {
        lhs.breakdown.elementsEqual(rhs.breakdown) { $0.0 == $1.0 && $0.1 == $1.1 }
            && lhs.customCategories.map(\.id) == rhs.customCategories.map(\.id)
    }

    var body: some View {
        Chart {
            ForEach(breakdown, id: \.0) { item in
                BarMark(
                    x: .value("Amount", item.1),
                    y: .value("Category", item.0)
                )
                .foregroundStyle(by: .value("Category", item.0))
                .cornerRadius(6)
            }
        }
        .chartLegend(.hidden)
        .chartXAxis(.hidden)
        .chartForegroundStyleScale(domain: categoryNames, range: categoryGradients)
        .modifier(ExpenseChartRasterizationModifier(enabled: rasterizesChart))
    }
}

struct ExpenseChartRasterizationModifier: ViewModifier {
    let enabled: Bool

    func body(content: Content) -> some View {
        if enabled {
            content.drawingGroup(opaque: false, colorMode: .linear)
        } else {
            content
        }
    }
}

struct ExpenseChartCompositingModifier: ViewModifier {
    let enabled: Bool

    func body(content: Content) -> some View {
        if enabled {
            content.compositingGroup()
        } else {
            content
        }
    }
}
