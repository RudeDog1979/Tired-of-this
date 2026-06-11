//
//  ExpensesTopCarousel.swift
//  BuxMuse
//
//  Swipable hero cards: equal-height Total Spend + Monthly Summary.
//

import SwiftUI

private struct ExpenseHeroMatchesListCardsKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// iPhone island layout — hero chrome matches `ExpandableExpenseCard` (16pt radius, list material).
    var expenseHeroMatchesListCards: Bool {
        get { self[ExpenseHeroMatchesListCardsKey.self] }
        set { self[ExpenseHeroMatchesListCardsKey.self] = newValue }
    }
}

struct ExpensesTopCarousel: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var brain: BuxMuseBrain
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @Environment(\.expenseHeroMatchesListCards) private var matchesListCards

    let header: ExpensesHeaderDisplay
    let summary: ExpensesSummaryDisplay
    let formatAmount: (Decimal) -> String
    let playRequest: UUID
    let session: ExpenseCarouselSession

    @State private var playedPages: Set<Int>
    @State private var pageProgress: [Int: Double]
    @State private var pageIndex: Int? = 0
    @State private var activeDetailSheet: HeroSheetType?
    @State private var cachedCustomCategories: [ExpenseCategoryRecord] = []
    @State private var cardReveal = false

    init(
        header: ExpensesHeaderDisplay,
        summary: ExpensesSummaryDisplay,
        formatAmount: @escaping (Decimal) -> String,
        playRequest: UUID,
        session: ExpenseCarouselSession? = nil
    ) {
        self.header = header
        self.summary = summary
        self.formatAmount = formatAmount
        self.playRequest = playRequest
        let resolvedSession = session ?? ExpenseCarouselSession.shared
        self.session = resolvedSession
        _playedPages = State(initialValue: resolvedSession.playedPages)
        _pageProgress = State(initialValue: resolvedSession.pageProgress)
    }

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
        cachedCustomCategories
    }

    private var slotHeight: CGFloat {
        pages.isEmpty ? 0 : BuxLayout.expenseHeroSummaryHeight
    }

    private var heroChromeTier: BuxCardChromeTier {
        if matchesListCards || pages.count > 1 {
            return .list
        }
        return .hero
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
                                        chromeTier: heroChromeTier,
                                        isVisible: cardReveal
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
                .buxPadViewAlignedHorizontalCarousel()
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
        .onAppear {
            if cachedCustomCategories.isEmpty {
                cachedCustomCategories = ((try? brain.fetchAllCategoryRecords()) ?? []).filter(\.isCustom)
            }
            if !playedPages.contains(activePageIndex) {
                animatePage(activePageIndex)
            }
            session.syncActivePage(activePageIndex)
            withAnimation(.spring(response: 0.55, dampingFraction: 0.84)) {
                cardReveal = true
            }
        }
        .onDisappear {
            if session.playRequest == playRequest {
                session.syncPlaybackState(playedPages: playedPages, pageProgress: pageProgress)
            }
        }
        .onChange(of: activePageIndex) { old, index in
            guard old != index else { return }
            session.syncActivePage(index)
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
        if playedPages.contains(index) {
            return pageProgress[index] ?? 1
        }
        return pageProgress[index] ?? 0
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
                    BuxCatalogText.text("Total spend")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))

                    Text(formatAmount(Decimal(header.totalSpent)))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                        .transaction { $0.animation = nil }
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
            .heroCardReveal(isVisible: cardReveal, delay: 0)

            if !summary.categoryBreakdown.isEmpty || !summary.merchantBreakdown.isEmpty {
                HStack(spacing: 16) {
                    if !summary.categoryBreakdown.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            BuxCatalogText.text("Top categories")
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
                            BuxCatalogText.text("Top merchants")
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
                .heroCardReveal(isVisible: cardReveal, delay: 0.06)
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
                .heroCardReveal(isVisible: cardReveal, delay: 0.12)
            }

            if let insight = header.microInsight {
                InlineInsightView(text: insight)
                    .heroCardReveal(isVisible: cardReveal, delay: 0.18)
            }
        }
        .expenseCardChrome(tier: heroChromeTier)
        .frame(maxWidth: .infinity, minHeight: slotHeight, alignment: .topLeading)
    }

    private var monthChangeBadge: some View {
        let isUp = header.changeVsLastMonth > 0
        let isDown = header.changeVsLastMonth < 0
        let tint: Color = isUp
            ? BuxChartColors.comparisonUp
            : (isDown ? BuxChartColors.comparisonDown : .gray)

        return VStack(alignment: .trailing, spacing: 2) {
            BuxCatalogText.text("Vs last mo")
                .font(.caption.weight(.medium))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.35) : Color(red: 140/255, green: 145/255, blue: 160/255))

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
    @Environment(\.expenseHeroMatchesListCards) private var matchesListCards
    @ObservedObject private var settings = SettingsStore.shared

    func body(content: Content) -> some View {
        let cornerRadius = matchesListCards
            ? BuxLayout.cornerCard
            : BuxLayout.expenseHeroCardCornerRadius
        let cardPadding: CGFloat = 20
        let useMesh = expensesEnhancedTint && settings.brandThemesEnabled
        let padded = content
            .padding(cardPadding)
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

/// Isolates carousel `playRequest` updates so the expense list does not re-render every animation frame.
struct ExpensesHeroCarouselHost: View, Equatable {
    @ObservedObject private var session = ExpenseCarouselSession.shared

    let header: ExpensesHeaderDisplay
    let summary: ExpensesSummaryDisplay
    let formatAmount: (Decimal) -> String
    let playRequest: UUID

    static func == (lhs: ExpensesHeroCarouselHost, rhs: ExpensesHeroCarouselHost) -> Bool {
        lhs.playRequest == rhs.playRequest &&
        lhs.header.totalSpent == rhs.header.totalSpent &&
        lhs.header.changeVsLastMonth == rhs.header.changeVsLastMonth &&
        lhs.header.monthlyTransactionCount == rhs.header.monthlyTransactionCount &&
        lhs.header.biggestCategory == rhs.header.biggestCategory &&
        lhs.header.biggestMerchant == rhs.header.biggestMerchant &&
        lhs.header.sparklinePoints == rhs.header.sparklinePoints &&
        lhs.header.microInsight == rhs.header.microInsight &&
        lhs.summary.totalSpent == rhs.summary.totalSpent &&
        lhs.summary.categoryBreakdown.map { $0.0 } == rhs.summary.categoryBreakdown.map { $0.0 } &&
        lhs.summary.categoryBreakdown.map { $0.1 } == rhs.summary.categoryBreakdown.map { $0.1 } &&
        lhs.summary.merchantBreakdown.map { $0.0 } == rhs.summary.merchantBreakdown.map { $0.0 } &&
        lhs.summary.merchantBreakdown.map { $0.1 } == rhs.summary.merchantBreakdown.map { $0.1 } &&
        lhs.summary.trendPoints == rhs.summary.trendPoints &&
        lhs.summary.prediction == rhs.summary.prediction
    }

    var body: some View {
        ExpensesTopCarousel(
            header: header,
            summary: summary,
            formatAmount: formatAmount,
            playRequest: playRequest,
            session: session
        )
        .id(playRequest)
    }
}

private struct HeroCardRevealModifier: ViewModifier {
    let isVisible: Bool
    let delay: Double

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 10)
            .animation(.spring(response: 0.5, dampingFraction: 0.84).delay(delay), value: isVisible)
    }
}

extension View {
    func heroCardReveal(isVisible: Bool, delay: Double) -> some View {
        modifier(HeroCardRevealModifier(isVisible: isVisible, delay: delay))
    }
}
