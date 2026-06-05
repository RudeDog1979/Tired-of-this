//
//  ExpensesTopCarousel.swift
//  BuxMuse
//
//  Swipable hero cards: equal-height Total Spend + Monthly Summary.
//

import SwiftUI

struct ExpensesTopCarousel: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var brain: BuxMuseBrain
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    let header: ExpensesHeaderDisplay
    let summary: ExpensesSummaryDisplay
    let formatAmount: (Decimal) -> String
    let playRequest: UUID
    @Binding var playedPages: Set<Int>
    @Binding var pageProgress: [Int: Double]

    @State private var pageIndex: Int? = 0
    @State private var activeDetailSheet: HeroSheetType?

    private enum HeroSheetType: String, Identifiable {
        case totalSpend
        case monthlySummary
        var id: String { rawValue }
    }

    private var pages: [CarouselPage] {
        var items: [CarouselPage] = []
        if header.totalSpent != 0 || !header.sparklinePoints.isEmpty {
            items.append(.totalSpend)
        }
        if !summary.categoryBreakdown.isEmpty || !summary.merchantBreakdown.isEmpty {
            items.append(.monthlySummary)
        }
        return items
    }

    private var activePageIndex: Int {
        min(pageIndex ?? 0, max(pages.count - 1, 0))
    }

    private var customCategories: [ExpenseCategoryRecord] {
        ((try? brain.fetchAllCategoryRecords()) ?? []).filter(\.isCustom)
    }

    private var slotHeight: CGFloat {
        pages.isEmpty ? 0 : BuxLayout.expenseHeroSummaryHeight
    }

    var body: some View {
        VStack(spacing: 10) {
            ZStack(alignment: .top) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 16) {
                        ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                            Group {
                                switch page {
                                case .totalSpend:
                                    totalSpendCard(progress: pageProgressValue(index))
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            let impact = UIImpactFeedbackGenerator(style: .medium)
                                            impact.impactOccurred()
                                            activeDetailSheet = .totalSpend
                                        }
                                case .monthlySummary:
                                    ExpensesSummaryCard(
                                        display: summary,
                                        customCategories: customCategories,
                                        chartProgress: pageProgressValue(index),
                                        chromeTier: pages.count > 1 ? .list : .hero
                                    )
                                        .environmentObject(themeManager)
                                        .environmentObject(appSettingsManager)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            let impact = UIImpactFeedbackGenerator(style: .medium)
                                            impact.impactOccurred()
                                            activeDetailSheet = .monthlySummary
                                        }
                                }
                            }
                            .frame(maxWidth: .infinity, minHeight: slotHeight, alignment: .top)
                            .containerRelativeFrame(.horizontal)
                            .id(index)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollClipDisabled()
                .scrollTargetBehavior(.viewAligned)
                .scrollPosition(id: $pageIndex)
                .safeAreaPadding(.vertical, 8)
            }
            .frame(minHeight: slotHeight + 16, alignment: .top)
            .padding(.bottom, BuxLayout.expenseHeroShadowBleed)

            if pages.count > 1 {
                HStack(spacing: 6) {
                    ForEach(pages.indices, id: \.self) { index in
                        Capsule()
                            .fill(
                                index == activePageIndex
                                    ? AnyShapeStyle(
                                        LinearGradient(
                                            colors: [
                                                themeManager.current.accentColor,
                                                themeManager.current.accentColor.opacity(0.72)
                                            ],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    : AnyShapeStyle(
                                        themeManager.pillInactiveLabelColor(for: colorScheme).opacity(0.35)
                                    )
                            )
                            .frame(width: index == activePageIndex ? 18 : 6, height: 6)
                            .animation(.spring(response: 0.35, dampingFraction: 0.82), value: activePageIndex)
                    }
                }
            }
        }
        .onChange(of: playRequest, initial: true) { _, _ in
            animatePage(activePageIndex)
        }
        .onChange(of: activePageIndex) { _, index in
            animatePage(index)
        }
        .sheet(item: $activeDetailSheet) { sheetType in
            Group {
                switch sheetType {
                case .totalSpend:
                    TotalSpendDetailSheet(header: header, formatAmount: formatAmount)
                        .environmentObject(themeManager)
                        .environmentObject(brain)
                        .environmentObject(appSettingsManager)
                        .environment(\.expensesEnhancedTint, true)
                        .presentationDetents([.fraction(0.88), .large])
                        .presentationDragIndicator(.visible)
                case .monthlySummary:
                    MonthlySummaryDetailSheet(summary: summary, formatAmount: formatAmount)
                        .environmentObject(themeManager)
                        .environmentObject(appSettingsManager)
                        .environmentObject(brain)
                        .environment(\.expensesEnhancedTint, true)
                        .presentationDetents([.fraction(0.88), .large])
                        .presentationDragIndicator(.visible)
                }
            }
            .buxThemedSheetContent()
            .buxMeshSheetPresentation()
        }
    }

    private func pageProgressValue(_ index: Int) -> Double {
        pageProgress[index] ?? 0
    }

    private func animatePage(_ index: Int) {
        guard pages.indices.contains(index) else { return }
        guard !playedPages.contains(index) else { return }

        playedPages.insert(index)
        pageProgress[index] = 0

        if BuxMotion.reducedMotion {
            pageProgress[index] = 1
        } else {
            withAnimation(BuxChartMotion.cardEntrance) {
                pageProgress[index] = 1
            }
        }
    }

    private func totalSpendCard(progress: Double) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    BuxCatalogText.text("Total Spend")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))

                    Text(formatAmount(Decimal(header.totalSpent)))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                        .contentTransition(.numericText())
                }

                Spacer(minLength: 8)

                if !summary.categoryBreakdown.isEmpty {
                    MiniCategoryDonutChart(
                        breakdown: summary.categoryBreakdown,
                        customCategories: customCategories,
                        progress: progress
                    )
                        .frame(width: 72, height: 72)
                }
            }

            if !summary.categoryBreakdown.isEmpty || !summary.merchantBreakdown.isEmpty {
                HStack(spacing: 16) {
                    if !summary.categoryBreakdown.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            BuxCatalogText.text("Top Categories")
                                .font(.caption.bold())
                                .foregroundColor(.gray)
                            CategoryBreakdownChart(
                                breakdown: summary.categoryBreakdown,
                                customCategories: customCategories,
                                progress: progress
                            )
                            .frame(height: 72)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if !summary.merchantBreakdown.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            BuxCatalogText.text("Top Merchants")
                                .font(.caption.bold())
                                .foregroundColor(.gray)
                            MerchantBreakdownChart(
                                breakdown: summary.merchantBreakdown,
                                maxItems: 3,
                                progress: progress
                            )
                            .frame(height: MerchantBreakdownChart.compactHeight(itemCount: min(3, summary.merchantBreakdown.count)))
                            if summary.merchantBreakdown.count > 3 {
                                Text(
                                    BuxLocalizedString.format(
                                        "+%lld more · tap for details",
                                        locale: appSettingsManager.interfaceLocale,
                                        Int64(summary.merchantBreakdown.count - 3)
                                    )
                                )
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundColor(.gray.opacity(0.9))
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }

            if !header.sparklinePoints.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    BuxCatalogText.text("7-day trend")
                        .font(.caption.bold())
                        .foregroundColor(.gray)

                    HStack(alignment: .center, spacing: 12) {
                        SparklineChart(
                            points: header.sparklinePoints,
                            color: BuxChartColors.spendTrend(for: colorScheme),
                            showAreaFill: true,
                            progress: progress
                        )
                        .frame(height: 52)
                        .padding(.vertical, 2)
                        .background {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            BuxChartColors.spendTrendGlow(for: colorScheme),
                                            BuxChartColors.spendTrend(for: colorScheme).opacity(0.02)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .allowsHitTesting(false)
                        }

                        monthChangeBadge
                    }
                }
            }

            if let insight = header.microInsight {
                InlineInsightView(text: insight)
            }
        }
        .expenseHeroCardChrome(themeManager: themeManager, colorScheme: colorScheme)
        .frame(maxWidth: .infinity, minHeight: slotHeight, alignment: .topLeading)
    }

    private var monthChangeBadge: some View {
        let isUp = header.changeVsLastMonth > 0
        let isDown = header.changeVsLastMonth < 0
        let tint: Color = isUp
            ? BuxChartColors.comparisonUp
            : (isDown ? BuxChartColors.comparisonDown : .gray)

        return VStack(alignment: .trailing, spacing: 2) {
            BuxCatalogText.text("vs last mo")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.35) : Color(red: 140/255, green: 145/255, blue: 160/255))
                .kerning(0.4)

            HStack(spacing: 3) {
                if isUp || isDown {
                    Image(systemName: isUp ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 10, weight: .bold))
                }
                Text(formatAmount(Decimal(abs(header.changeVsLastMonth))))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
            }
            .foregroundColor(tint)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [tint.opacity(0.16), tint.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(tint.opacity(0.2), lineWidth: 0.5)
                }
        }
        .frame(minWidth: 72, alignment: .trailing)
    }

    private enum CarouselPage: Hashable {
        case totalSpend
        case monthlySummary
    }
}

// MARK: - Shared hero card chrome

struct ExpenseCardChromeModifier: ViewModifier {
    let tier: BuxCardChromeTier
    @Environment(\.expensesEnhancedTint) private var expensesEnhancedTint
    @ObservedObject private var settings = SettingsStore.shared

    func body(content: Content) -> some View {
        let cornerRadius = BuxLayout.expenseHeroCardCornerRadius
        let useMesh = expensesEnhancedTint && settings.brandThemesEnabled
        let padded = content
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .topLeading)

        switch tier {
        case .hero:
            padded.buxHeroCardChrome(cornerRadius: cornerRadius, useMeshPlate: useMesh)
        case .list:
            padded.buxListCardChrome(cornerRadius: cornerRadius)
        }
    }
}

struct ExpenseHeroCardChrome: ViewModifier {
    func body(content: Content) -> some View {
        content.modifier(ExpenseCardChromeModifier(tier: .hero))
    }
}

extension View {
    func expenseHeroCardChrome(themeManager: ThemeManager, colorScheme: ColorScheme) -> some View {
        _ = (themeManager, colorScheme)
        return modifier(ExpenseHeroCardChrome())
    }

    func expenseCardChrome(tier: BuxCardChromeTier) -> some View {
        modifier(ExpenseCardChromeModifier(tier: tier))
    }
}
