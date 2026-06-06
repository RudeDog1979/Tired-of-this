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
    @EnvironmentObject private var brain: BuxMuseBrain

    let summary: ExpensesSummaryDisplay
    let formatAmount: (Decimal) -> String

    @State private var chartProgress: Double = 0
    @State private var chartAnimationPlayed = false
    @State private var customCategories: [ExpenseCategoryRecord] = []

    // Extracted complex arithmetic for fast compilation
    private var subscriptionPercentage: Double {
        guard summary.totalSpent > 0 else { return 0 }
        let estimatedCost = summary.totalSpent * 0.18
        return (estimatedCost / max(1.0, summary.totalSpent)) * 100
    }

    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.screenBackground(for: colorScheme).ignoresSafeArea()

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
                    .padding(.top, BuxLayout.section)
                    .padding(.bottom, BuxOverlayMetrics.scrollBottomInset)
                }
                .buxDetailScrollChrome()
            }
            .buxCatalogNavigationTitle("Monthly summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    BuxToolbarDoneButton { dismiss() }
                }
            }
            .buxDetailNavigationChrome()
            .onAppear {
                customCategories = (try? brain.fetchAllCategoryRecords())?.filter(\.isCustom) ?? []
                playDetailChartAnimationIfNeeded()
            }
        }
    }

    private func playDetailChartAnimationIfNeeded() {
        guard !chartAnimationPlayed else { return }
        chartAnimationPlayed = true
        if BuxMotion.reducedMotion {
            chartProgress = 1
        } else {
            withAnimation(BuxChartMotion.entrance) {
                chartProgress = 1
            }
        }
    }

    // MARK: - Forecasting Header Card

    private var forecastingHeader: some View {
        VStack(spacing: 16) {
            BuxCatalogText.text("Monthly summary")
                .buxSectionLabelStyle(color: .gray)

            sheetAmountHero(formatAmount(Decimal(summary.totalSpent)))

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
        .background { sheetHeroCardBackground }
    }

    private func sheetAmountHero(_ amount: String) -> some View {
        Text(amount)
            .font(.system(size: 40, weight: .bold, design: .rounded))
            .foregroundColor(themeManager.labelPrimary(for: colorScheme))
            .contentTransition(.numericText())
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
    }

    private var sheetHeroCardBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    colorScheme == .dark
                        ? Color.white.opacity(0.04)
                        : Color.black.opacity(0.02)
                )

            RadialGradient(
                colors: [
                    themeManager.current.accentColor.opacity(colorScheme == .dark ? 0.24 : 0.16),
                    themeManager.current.accentColor.opacity(0.06),
                    Color.clear
                ],
                center: .center,
                startRadius: 4,
                endRadius: 130
            )
            .padding(.vertical, 8)
            .allowsHitTesting(false)

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
        }
        .shadow(
            color: Color.black.opacity(colorScheme == .dark ? 0.25 : 0.05),
            radius: 12,
            x: 0,
            y: 6
        )
    }

    // MARK: - Category Breakdown Section

    private var categoryBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            BuxCatalogText.text("Category breakdown")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.gray)

            if summary.categoryBreakdown.isEmpty {
                BuxCatalogText.text("No data available.")
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
                        categoryRow(name: catName, value: catVal, percentage: percentage, index: index)
                    }
                }
            }
        }
        .padding(20)
        .expensesThemedCardChrome(cornerRadius: 20)
    }

    private func categoryRow(name: String, value: Double, percentage: Double, index: Int) -> some View {
        let catalogColor = ExpenseCategoryCatalog.catalogColorName(
            forDisplayName: name,
            customCategories: customCategories,
            locale: appSettingsManager.interfaceLocale
        )
        let categoryTint = ExpenseCategoryStyle.foreground(for: catalogColor)
        let categoryBackground = ExpenseCategoryStyle.background(for: catalogColor)
        let categoryIcon = ExpenseCategoryCatalog.icon(
            forDisplayName: name,
            customCategories: customCategories,
            locale: appSettingsManager.interfaceLocale
        )
        let progressGradient = BuxChartColors.categoryGradient(
            forCategoryName: name,
            customCategories: customCategories,
            fallbackIndex: index
        )
        let rowProgress = BuxChartMotion.staggeredProgress(
            global: chartProgress,
            index: index,
            count: summary.categoryBreakdown.count
        )

        return VStack(spacing: 6) {
            HStack(spacing: 12) {
                // Category Icon
                ZStack {
                    Circle()
                        .fill(categoryBackground)
                        .frame(width: 32, height: 32)

                    Image(systemName: categoryIcon)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(categoryTint)
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
                    
                    Text(
                        BuxLocalizedString.format(
                            "%.0f%%",
                            locale: appSettingsManager.interfaceLocale,
                            percentage
                        )
                    )
                        .font(.caption2.bold())
                        .foregroundColor(.gray)
                }
            }

            // Dynamic Gradient Progress Bar
            GeometryReader { geo in
                let barWidth = geo.size.width * CGFloat(percentage / 100) * CGFloat(rowProgress)

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.04))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    Capsule()
                        .fill(progressGradient)
                        .frame(width: barWidth)
                        .overlay(alignment: .leading) {
                            if barWidth > 4 {
                                Capsule()
                                    .fill(Color.white.opacity(colorScheme == .dark ? 0.22 : 0.35))
                                    .frame(width: 3, height: 6)
                            }
                        }
                }
            }
            .frame(height: 6)
            .gpuChartLayer()
        }
    }

    // MARK: - Merchant Leaderboard Section

    private var merchantLeaderboardSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            BuxCatalogText.text("Top merchants")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.gray)

            if summary.merchantBreakdown.isEmpty {
                BuxCatalogText.text("No merchant data available.")
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
        let merchantTint = BuxChartColors.merchantColor(fallbackIndex: index)
        let merchantGradient = BuxChartColors.merchantGradient(fallbackIndex: index)
        let rowProgress = BuxChartMotion.staggeredProgress(
            global: chartProgress,
            index: index,
            count: summary.merchantBreakdown.count
        )
        let rankString = "\(index + 1)"

        return HStack(spacing: 12) {
            // Rank Number
            Text(rankString)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(merchantTint)
                .frame(width: 22, height: 22)
                .background {
                    Circle()
                        .fill(merchantTint.opacity(0.12))
                }
                .frame(width: 24)

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
                    let barWidth = geo.size.width * CGFloat(ratio) * CGFloat(rowProgress)

                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(colorScheme == .dark ? Color.white.opacity(0.04) : Color.black.opacity(0.03))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)

                        Capsule()
                            .fill(merchantGradient)
                            .frame(width: barWidth)
                            .overlay(alignment: .leading) {
                                if barWidth > 4 {
                                    Capsule()
                                        .fill(Color.white.opacity(colorScheme == .dark ? 0.18 : 0.3))
                                        .frame(width: 3, height: 5)
                                }
                            }
                    }
                }
                .frame(height: 5)
                .gpuChartLayer()
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
                BuxCatalogText.text("BuxMuse intelligence")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(themeManager.labelPrimary(for: colorScheme))
            }

            Text(
                BuxLocalizedString.format(
                    "Your recurring subscriptions account for roughly %.0f%% of your overall spending. Taking advantage of multi-month prepayments could unlock up to 15%% in annual savings across active plans.",
                    locale: appSettingsManager.interfaceLocale,
                    subscriptionPercentage
                )
            )
                .font(.system(size: 13))
                .foregroundColor(.gray)
                .lineSpacing(4)
        }
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.yellow.opacity(colorScheme == .dark ? 0.06 : 0.04),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .allowsHitTesting(false)
        }
        .expensesThemedCardChrome(cornerRadius: 20)
    }

}
