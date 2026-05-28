//
//  TotalSpendDetailSheet.swift
//  BuxMuse
//
//  Created for BuxMuse.
//  A beautiful, high-end interactive detail view for Total Spend.
//

import SwiftUI
import Charts
import SwiftData

struct TotalSpendDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var brain: BuxMuseBrain
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    let header: ExpensesHeaderDisplay
    let formatAmount: (Decimal) -> String

    @State private var selectedRange = TimeRange.days30
    @State private var animateCharts = false
    @State private var allRecords: [ExpenseRecord] = []

    private enum TimeRange: String, CaseIterable, Identifiable {
        case days7 = "7 Days"
        case days30 = "30 Days"
        case days90 = "90 Days"

        var id: String { rawValue }
        var dayCount: Int {
            switch self {
            case .days7: return 7
            case .days30: return 30
            case .days90: return 90
            }
        }
    }

    // Filter and calculate stats based on selected time range
    private var filteredRecords: [ExpenseRecord] {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -selectedRange.dayCount, to: Date()) ?? Date()
        return allRecords.filter { $0.date >= cutoffDate }
    }

    private var totalSpentInRange: Double {
        filteredRecords.reduce(0.0) { $0 + abs($1.amountDouble) }
    }

    private var dailyAverageInRange: Double {
        let days = Double(selectedRange.dayCount)
        return totalSpentInRange / max(1, days)
    }

    private var largestPurchases: [ExpenseRecord] {
        Array(filteredRecords.sorted(by: { abs($0.amountDouble) > abs($1.amountDouble) }).prefix(3))
    }

    // Dynamic trend points aggregated by day for the selected range
    private var trendDataPoints: [(Date, Double)] {
        let calendar = Calendar.current
        var pointsMap: [Date: Double] = [:]
        
        // Initialize map with all dates in range
        let now = Date()
        for i in 0..<selectedRange.dayCount {
            if let date = calendar.date(byAdding: .day, value: -i, to: now) {
                let dayStart = calendar.startOfDay(for: date)
                pointsMap[dayStart] = 0.0
            }
        }

        // Fill in transaction amounts
        for record in filteredRecords {
            let dayStart = calendar.startOfDay(for: record.date)
            if pointsMap[dayStart] != nil {
                pointsMap[dayStart, default: 0.0] += abs(record.amountDouble)
            }
        }

        return pointsMap.map { ($0.key, $0.value) }.sorted(by: { $0.0 < $1.0 })
    }

    private var heatZoneCounts: (critical: Int, warning: Int, normal: Int) {
        var crit = 0
        var warn = 0
        var norm = 0
        for r in filteredRecords {
            switch r.heatZoneBucket?.lowercased() {
            case "critical", "high":
                crit += 1
            case "warning", "medium":
                warn += 1
            default:
                norm += 1
            }
        }
        return (crit, warn, norm)
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    
                    // Glassmorphic Premium Header Card
                    glassHeaderSection
                    
                    // Picker for time ranges
                    pickerSection
                    
                    // Expanded Swift Charts Trend view
                    chartSection
                    
                    // Spending Heat Zones Analysis
                    heatZoneSection
                    
                    // Top / Largest Purchases
                    largestPurchasesSection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(themeManager.screenBackground(for: colorScheme).ignoresSafeArea())
            .navigationTitle("Spending Analysis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .tint(themeManager.current.accentColor)
                }
            }
            .onAppear {
                loadRecords()
                withAnimation(.easeOut(duration: 0.6)) {
                    animateCharts = true
                }
            }
            .onChange(of: selectedRange) { _, _ in
                animateCharts = false
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    animateCharts = true
                }
            }
        }
    }

    private func loadRecords() {
        if let records = try? brain.fetchAllExpenseRecords() {
            allRecords = records
        }
    }

    // MARK: - Premium Glassmorphic Header

    private var glassHeaderSection: some View {
        VStack(alignment: .center, spacing: 16) {
            Text("TOTAL SPENT (\(selectedRange.rawValue.uppercased()))")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.gray)
                .kerning(1.2)

            Text(formatAmount(Decimal(totalSpentInRange)))
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                .contentTransition(.numericText())

            HStack(spacing: 32) {
                VStack(spacing: 4) {
                    Text("Daily Average")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text(formatAmount(Decimal(dailyAverageInRange)))
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                }

                Divider()
                    .frame(height: 32)

                VStack(spacing: 4) {
                    Text("Transactions")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("\(filteredRecords.count)")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                }
            }
            .padding(.top, 4)
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    colorScheme == .dark
                        ? Color.white.opacity(0.04)
                        : Color.black.opacity(0.02)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    themeManager.current.accentColor.opacity(0.2),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(
                    color: Color.black.opacity(colorScheme == .dark ? 0.25 : 0.05),
                    radius: 12,
                    x: 0,
                    y: 6
                )
        }
    }

    // MARK: - Picker Section

    private var pickerSection: some View {
        Picker("Range", selection: $selectedRange) {
            ForEach(TimeRange.allCases) { range in
                Text(range.rawValue).tag(range)
            }
        }
        .pickerStyle(.segmented)
        .tint(themeManager.current.accentColor)
    }

    // MARK: - Chart Section

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Trend Over Time")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.gray)
                .kerning(0.5)

            Chart {
                ForEach(trendDataPoints.indices, id: \.self) { index in
                    let point = trendDataPoints[index]
                    
                    AreaMark(
                        x: .value("Date", point.0),
                        y: .value("Amount", animateCharts ? point.1 : 0)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                themeManager.current.accentColor.opacity(0.24),
                                themeManager.current.accentColor.opacity(0.01)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    LineMark(
                        x: .value("Date", point.0),
                        y: .value("Amount", animateCharts ? point.1 : 0)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(themeManager.current.accentColor.gradient)
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                }
            }
            .frame(height: 180)
            .chartXAxis {
                AxisMarks(values: .stride(by: selectedRange == .days7 ? .day : .day, count: selectedRange == .days7 ? 1 : (selectedRange == .days30 ? 7 : 21))) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                        .foregroundStyle(Color.gray.opacity(0.3))
                    AxisValueLabel(format: selectedRange == .days7 ? .dateTime.day() : .dateTime.month().day())
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color.gray.opacity(0.2))
                    AxisValueLabel {
                        if let doubleValue = value.as(Double.self) {
                            Text(formatAmount(Decimal(doubleValue)).replacingOccurrences(of: ".00", with: ""))
                                .font(.caption2)
                        }
                    }
                }
            }
        }
        .padding(20)
        .expensesThemedCardChrome(cornerRadius: 20)
    }

    // MARK: - Heat Zone Distribution Section

    private var heatZoneSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Spending Heat Zones")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.gray)
                .kerning(0.5)

            VStack(spacing: 12) {
                // Segmented bar
                let total = max(1, Double(heatZoneCounts.critical + heatZoneCounts.warning + heatZoneCounts.normal))
                let critWidth = Double(heatZoneCounts.critical) / total
                let warnWidth = Double(heatZoneCounts.warning) / total
                let normWidth = Double(heatZoneCounts.normal) / total

                GeometryReader { geo in
                    HStack(spacing: 3) {
                        if critWidth > 0 {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.orange)
                                .frame(width: max(8, geo.size.width * CGFloat(critWidth)))
                        }
                        if warnWidth > 0 {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.yellow)
                                .frame(width: max(8, geo.size.width * CGFloat(warnWidth)))
                        }
                        if normWidth > 0 {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.green)
                                .frame(width: max(8, geo.size.width * CGFloat(normWidth)))
                        }
                    }
                }
                .frame(height: 12)
                .padding(.bottom, 4)

                // Legend
                HStack(spacing: 16) {
                    legendItem(title: "High Risk", count: heatZoneCounts.critical, color: .orange)
                    Spacer()
                    legendItem(title: "Warning", count: heatZoneCounts.warning, color: .yellow)
                    Spacer()
                    legendItem(title: "Safe Zone", count: heatZoneCounts.normal, color: .green)
                }
            }
        }
        .padding(20)
        .expensesThemedCardChrome(cornerRadius: 20)
    }

    private func legendItem(title: String, count: Int, color: Color) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2.bold())
                    .foregroundColor(.gray)
                Text("\(count) items")
                    .font(.caption.bold())
                    .foregroundColor(themeManager.labelPrimary(for: colorScheme))
            }
        }
    }

    // MARK: - Largest Purchases Section

    private var largestPurchasesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Largest Purchases")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.gray)
                .kerning(0.5)

            if largestPurchases.isEmpty {
                Text("No transactions logged in this range.")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 12) {
                    ForEach(largestPurchases) { record in
                        HStack(spacing: 16) {
                            // Category Icon
                            ZStack {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(themeManager.current.accentColor.opacity(0.12))
                                    .frame(width: 44, height: 44)
                                
                                Image(systemName: record.transactionCategory.iconName)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(themeManager.current.accentColor)
                            }

                            // Merchant Details
                            VStack(alignment: .leading, spacing: 4) {
                                Text(record.name)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                                
                                Text(record.date.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }

                            Spacer()

                            // Amount
                            Text(formatAmount(Decimal(abs(record.amountDouble))))
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                        }
                        
                        if record != largestPurchases.last {
                            Divider()
                        }
                    }
                }
            }
        }
        .padding(20)
        .expensesThemedCardChrome(cornerRadius: 20)
    }
}

// Extension to map TransactionCategory to System Icons
private extension TransactionCategory {
    var iconName: String {
        switch self {
        case .groceries: return "cart.fill"
        case .restaurants: return "fork.knife"
        case .transport: return "car.fill"
        case .subscriptions: return "arrow.triangle.2.circlepath"
        case .housing: return "house.fill"
        case .income: return "banknote.fill"
        default: return "square.grid.2x2.fill"
        }
    }
}
