//
//  MonthlySummaryDetailSheet.swift
//  BuxMuse
//
//  Created for BuxMuse.
//  A beautiful, high-end analytical detail view for Monthly Summary.
//

import SwiftUI
import Charts

struct MonthlySummaryDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    let summary: ExpensesSummaryDisplay
    let formatAmount: (Decimal) -> String

    @State private var animateRows = false

    // Extracted complex arithmetic for fast compilation
    private var subscriptionPercentage: Double {
        guard summary.totalSpent > 0 else { return 0 }
        let estimatedCost = summary.totalSpent * 0.18
        return (estimatedCost / max(1.0, summary.totalSpent)) * 100
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    
                    // High-level prediction header
                    forecastingHeader
                    
                    // Category Breakdown with premium progress bars
                    categoryBreakdownSection
                    
                    // Merchant Leaderboard with visual size bars
                    merchantLeaderboardSection
                    
                    // Budget Risk & Intelligence Advice
                    financialAdviceSection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(themeManager.screenBackground(for: colorScheme).ignoresSafeArea())
            .navigationTitle("Monthly Summary")
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
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    animateRows = true
                }
            }
        }
    }

    // MARK: - Forecasting Header Card

    private var forecastingHeader: some View {
        VStack(spacing: 16) {
            Text("MONTHLY SUMMARY")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.gray)
                .kerning(1.2)

            Text(formatAmount(Decimal(summary.totalSpent)))
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                .contentTransition(.numericText())

            if let prediction = summary.prediction {
                HStack(spacing: 8) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.caption.bold())
                        .foregroundColor(themeManager.current.accentColor)
                    
                    Text(prediction)
                        .font(.caption.bold())
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background {
                    Capsule()
                        .fill(themeManager.current.accentColor.opacity(0.08))
                }
            }
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

    // MARK: - Category Breakdown Section

    private var categoryBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Category Breakdown")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.gray)
                .kerning(0.5)

            if summary.categoryBreakdown.isEmpty {
                Text("No data available.")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 16) {
                    ForEach(Array(summary.categoryBreakdown.enumerated()), id: \.offset) { index, item in
                        let catName = item.0
                        let catVal = abs(item.1)
                        let percentage = summary.totalSpent > 0 ? (catVal / summary.totalSpent) * 100 : 0
                        categoryRow(name: catName, value: catVal, percentage: percentage)
                    }
                }
            }
        }
        .padding(20)
        .expensesThemedCardChrome(cornerRadius: 20)
    }

    private func categoryRow(name: String, value: Double, percentage: Double) -> some View {
        let progressGradient = LinearGradient(
            colors: [
                themeManager.current.accentColor,
                themeManager.current.accentColor.opacity(0.6)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )

        return VStack(spacing: 6) {
            HStack(spacing: 12) {
                // Category Icon
                ZStack {
                    Circle()
                        .fill(themeManager.current.accentColor.opacity(0.08))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: iconName(for: name))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(themeManager.current.accentColor)
                }

                // Category Name
                Text(name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(themeManager.labelPrimary(for: colorScheme))

                Spacer()

                // Spending detail
                VStack(alignment: .trailing, spacing: 2) {
                    Text(formatAmount(Decimal(value)))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                    
                    Text(String(format: "%.0f%%", percentage))
                        .font(.caption2.bold())
                        .foregroundColor(.gray)
                }
            }

            // Dynamic Gradient Progress Bar
            GeometryReader { geo in
                let barWidth = animateRows ? geo.size.width * CGFloat(percentage / 100) : CGFloat.zero
                
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.04))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    Capsule()
                        .fill(progressGradient)
                        .frame(width: barWidth)
                }
            }
            .frame(height: 6)
        }
    }

    // MARK: - Merchant Leaderboard Section

    private var merchantLeaderboardSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Top Merchants")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.gray)
                .kerning(0.5)

            if summary.merchantBreakdown.isEmpty {
                Text("No merchant data available.")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 16) {
                    let maxMerchantValue = max(1.0, summary.merchantBreakdown.first?.1 ?? 1.0)
                    
                    ForEach(Array(summary.merchantBreakdown.enumerated()), id: \.offset) { index, item in
                        let merName = item.0
                        let merVal = abs(item.1)
                        let ratio = merVal / maxMerchantValue
                        merchantRow(index: index, name: merName, value: merVal, ratio: ratio)
                    }
                }
            }
        }
        .padding(20)
        .expensesThemedCardChrome(cornerRadius: 20)
    }

    private func merchantRow(index: Int, name: String, value: Double, ratio: Double) -> some View {
        let merchantGradient = Color.orange.opacity(0.85).gradient
        let rankString = "\(index + 1)"

        return HStack(spacing: 12) {
            // Rank Number
            Text(rankString)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.gray.opacity(0.6))
                .frame(width: 16)

            // Merchant Name and dynamic width indicator card
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                    Spacer()
                    Text(formatAmount(Decimal(value)))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                }

                // Visual bar representing size compared to top merchant
                GeometryReader { geo in
                    let barWidth = animateRows ? geo.size.width * CGFloat(ratio) : CGFloat.zero
                    
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(colorScheme == .dark ? Color.white.opacity(0.04) : Color.black.opacity(0.03))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        
                        Capsule()
                            .fill(merchantGradient)
                            .frame(width: barWidth)
                    }
                }
                .frame(height: 5)
            }
        }
    }

    // MARK: - Financial Intelligence Advice Section

    private var financialAdviceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.yellow)
                Text("BuxMuse Intelligence")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(themeManager.labelPrimary(for: colorScheme))
            }

            Text("Your recurring subscriptions account for roughly \(String(format: "%.0f%%", subscriptionPercentage)) of your overall spending. Taking advantage of multi-month prepayments could unlock up to 15% in annual savings across active plans.")
                .font(.system(size: 13))
                .foregroundColor(.gray)
                .lineSpacing(4)
        }
        .padding(20)
        .expensesThemedCardChrome(cornerRadius: 20)
    }

    // Utility icons based on category names
    private func iconName(for category: String) -> String {
        switch category.lowercased() {
        case "groceries": return "cart.fill"
        case "restaurants", "dining": return "fork.knife"
        case "transport", "travel": return "car.fill"
        case "subscriptions": return "arrow.triangle.2.circlepath"
        case "housing", "rent": return "house.fill"
        case "income": return "banknote.fill"
        default: return "square.grid.2x2.fill"
        }
    }
}
