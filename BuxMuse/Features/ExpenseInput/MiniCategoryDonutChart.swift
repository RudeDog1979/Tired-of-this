//
//  MiniCategoryDonutChart.swift
//  BuxMuse
//

import SwiftUI

struct MiniCategoryDonutChart: View {
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    let breakdown: [(String, Double)]
    var customCategories: [ExpenseCategoryRecord] = []
    var progress: Double = 1
    var useGPUReveal: Bool = true
    var rasterizesChart: Bool = true

    private var segments: [(name: String, amount: Double)] {
        Array(breakdown.prefix(4))
    }

    private var total: Double {
        max(segments.reduce(0) { $0 + $1.amount }, 0.01)
    }

    private var chartLayer: some View {
        DonutChartLayer(
            breakdown: breakdown,
            customCategories: customCategories,
            rasterizesChart: rasterizesChart
        )
        .equatable()
    }

    var body: some View {
        ZStack {
            if useGPUReveal {
                chartLayer
                    .modifier(ExpenseChartCompositingModifier(enabled: rasterizesChart))
                    .buxGPUChartReveal(progress: progress, axis: .radial)
            } else {
                chartLayer
            }

            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.14),
                            Color.white.opacity(0.04),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
                .padding(10)
                .allowsHitTesting(false)
        }
        .accessibilityLabel(BuxCatalogLabel.string("Category breakdown", locale: appSettingsManager.interfaceLocale))
        .accessibilityValue(
            segments.map { "\($0.name) \(Int(($0.amount / total) * 100)) percent" }.joined(separator: ", ")
        )
    }
}

// MARK: - Native ring (GPU bitmap once — no Swift Charts per frame)

private struct DonutChartLayer: View, Equatable {
    let breakdown: [(String, Double)]
    let customCategories: [ExpenseCategoryRecord]
    var rasterizesChart: Bool = true

    private static let innerRadiusRatio: CGFloat = 0.62
    private static let angularInsetDegrees: Double = 1.5

    private var segments: [(name: String, amount: Double)] {
        Array(breakdown.prefix(4))
    }

    private var segmentSlices: [DonutSlice] {
        let total = max(segments.reduce(0) { $0 + $1.amount }, 0.01)
        var slices: [DonutSlice] = []
        var cursor = -90.0

        for (index, item) in segments.enumerated() {
            let sweep = (item.amount / total) * 360
            let inset = min(Self.angularInsetDegrees, max(sweep * 0.12, 0))
            let start = cursor + inset * 0.5
            let end = cursor + sweep - inset * 0.5
            if end > start {
                slices.append(
                    DonutSlice(
                        id: index,
                        name: item.name,
                        startDegrees: start,
                        endDegrees: end
                    )
                )
            }
            cursor += sweep
        }
        return slices
    }

    static func == (lhs: DonutChartLayer, rhs: DonutChartLayer) -> Bool {
        lhs.breakdown.elementsEqual(rhs.breakdown) { $0.0 == $1.0 && $0.1 == $1.1 }
            && lhs.customCategories.map(\.id) == rhs.customCategories.map(\.id)
    }

    var body: some View {
        ZStack {
            ForEach(segmentSlices) { slice in
                DonutRingSegment(
                    startDegrees: slice.startDegrees,
                    endDegrees: slice.endDegrees,
                    innerRadiusRatio: Self.innerRadiusRatio
                )
                .fill(
                    BuxChartColors.donutSegmentGradient(
                        forCategoryName: slice.name,
                        customCategories: customCategories,
                        fallbackIndex: slice.id
                    )
                )
            }
        }
        .transaction { $0.animation = nil }
        .modifier(ExpenseChartRasterizationModifier(enabled: rasterizesChart))
    }
}

private struct DonutSlice: Identifiable {
    let id: Int
    let name: String
    let startDegrees: Double
    let endDegrees: Double
}

private struct DonutRingSegment: Shape {
    let startDegrees: Double
    let endDegrees: Double
    let innerRadiusRatio: CGFloat

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerRadius = min(rect.width, rect.height) * 0.5
        let innerRadius = outerRadius * innerRadiusRatio

        var path = Path()
        path.addArc(
            center: center,
            radius: outerRadius,
            startAngle: .degrees(startDegrees),
            endAngle: .degrees(endDegrees),
            clockwise: false
        )
        path.addArc(
            center: center,
            radius: innerRadius,
            startAngle: .degrees(endDegrees),
            endAngle: .degrees(startDegrees),
            clockwise: true
        )
        path.closeSubpath()
        return path
    }
}
