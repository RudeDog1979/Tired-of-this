//
//  MonthlyTrendChart.swift
//  BuxMuse
//

import SwiftUI
import Charts

struct MonthlyTrendChart: View {
    let points: [Double]
    let prediction: String?
    @State private var isVisible = false
    
    var body: some View {
        VStack(alignment: .leading) {
            if let prediction {
                Text(prediction)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Chart {
                ForEach(Array(points.enumerated()), id: \.offset) { index, point in
                    AreaMark(
                        x: .value("Day", index),
                        y: .value("Amount", isVisible ? point : 0)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(
                        LinearGradient(colors: [.blue.opacity(0.3), .clear], startPoint: .top, endPoint: .bottom)
                    )
                    
                    LineMark(
                        x: .value("Day", index),
                        y: .value("Amount", isVisible ? point : 0)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(.blue)
                }
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                isVisible = true
            }
        }
    }
}
