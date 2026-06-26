//
//  ExpensesTopCarousel.swift
//  BuxMuse
//
//  Swipable hero cards: equal-height Total Spend + Monthly Summary.
//

import SwiftUI
import Charts

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
    var onOpenSpendingTrends: (() -> Void)? = nil

    @State private var playedPages: Set<Int>
    @State private var pageProgress: [Int: Double]
    @State private var pageIndex: Int? = 0
    @State private var activeDetailSheet: HeroSheetType?
    @State private var cachedCustomCategories: [ExpenseCategoryRecord] = []
    @State private var cardReveal = false
    @State private var totalSpendMode: TotalSpendMode = .trend
    @State private var selectedTrendPointIndex: Int? = nil
    @Namespace private var spendModeNamespace

    private enum TotalSpendMode: String, CaseIterable, Identifiable {
        case trend
        case profile
        var id: String { rawValue }
        
        func localizedTitle(locale: Locale) -> String {
            switch self {
            case .trend:
                return BuxLocalizedString.string("Trend", locale: locale)
            case .profile:
                return BuxLocalizedString.string("Profile", locale: locale)
            }
        }
    }

    init(
        header: ExpensesHeaderDisplay,
        summary: ExpensesSummaryDisplay,
        formatAmount: @escaping (Decimal) -> String,
        playRequest: UUID,
        session: ExpenseCarouselSession? = nil,
        onOpenSpendingTrends: (() -> Void)? = nil
    ) {
        self.header = header
        self.summary = summary
        self.formatAmount = formatAmount
        self.playRequest = playRequest
        let resolvedSession = session ?? ExpenseCarouselSession.shared
        self.session = resolvedSession
        self.onOpenSpendingTrends = onOpenSpendingTrends
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
                                            if let onOpenSpendingTrends {
                                                onOpenSpendingTrends()
                                            } else {
                                                activeDetailSheet = .monthlySummary
                                            }
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
        VStack(alignment: .leading, spacing: 12) {
            // Header Row: Title & Amount on left, interactive Mode Switcher on right
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    BuxCatalogText.text("Total spend")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))

                    if let periodSubtitle = header.periodRangeSubtitle {
                        Text(periodSubtitle)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.gray)
                    }

                    Text(ExpenseDisplayL10n.signedOutflow(
                        amount: header.totalSpent,
                        currency: appSettingsManager.selectedCurrency
                    ))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                        .transaction { $0.animation = nil }

                    if header.totalIncome > 0 {
                        Text(ExpenseDisplayL10n.signedInflow(
                            amount: header.totalIncome,
                            currency: appSettingsManager.selectedCurrency
                        ))
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(BuxChartColors.comparisonDown)
                    }
                }

                Spacer(minLength: 8)

                // Premium Switcher Control
                HStack(spacing: 2) {
                    ForEach(TotalSpendMode.allCases) { mode in
                        Text(mode.localizedTitle(locale: appSettingsManager.interfaceLocale))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(totalSpendMode == mode ? themeManager.labelPrimary(for: colorScheme) : .gray.opacity(0.85))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background {
                                Capsule()
                                    .fill(themeManager.current.accentColor.opacity(colorScheme == .dark ? 0.22 : 0.12))
                                    .opacity(totalSpendMode == mode ? 1.0 : 0.0)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                let impact = UIImpactFeedbackGenerator(style: .light)
                                impact.impactOccurred()
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    totalSpendMode = mode
                                }
                            }
                    }
                }
                .padding(2)
                .background(
                    Capsule()
                        .fill(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.03))
                )
            }
            .heroCardReveal(isVisible: cardReveal, delay: 0)

            // Content Area based on mode (Using high-performance ZStack crossfade to prevent animation lag)
            ZStack(alignment: .top) {
                trendContent(progress: progress)
                    .opacity(totalSpendMode == .trend ? 1.0 : 0.0)
                    .allowsHitTesting(totalSpendMode == .trend)
                    .scaleEffect(totalSpendMode == .trend ? 1.0 : 0.98)
                
                profileContent(progress: progress)
                    .opacity(totalSpendMode == .profile ? 1.0 : 0.0)
                    .allowsHitTesting(totalSpendMode == .profile)
                    .scaleEffect(totalSpendMode == .profile ? 1.0 : 0.98)
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: totalSpendMode)
        }
        .expenseCardChrome(tier: heroChromeTier)
        .frame(maxWidth: .infinity, minHeight: slotHeight, maxHeight: slotHeight, alignment: .topLeading)
    }

    private func calendarWeekTrendSeries(progress: Double) -> [(day: String, amount: Double)] {
        let points = header.sparklinePoints
        guard points.count == 7 else {
            return points.enumerated().map { index, point in
                (rollingDayLabel(for: index), BuxChartMotion.scaled(point, progress: progress))
            }
        }

        var calendar = Calendar.current
        calendar.firstWeekday = SettingsStore.shared.weekStartDay.calendarWeekday
        let today = Date()
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start else {
            return points.enumerated().map { index, point in
                (rollingDayLabel(for: index), BuxChartMotion.scaled(point, progress: progress))
            }
        }

        var amountByDay: [Date: Double] = [:]
        for index in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: -6 + index, to: today) else { continue }
            amountByDay[calendar.startOfDay(for: date)] = points[index]
        }

        return (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: weekStart) else { return nil }
            let dayStart = calendar.startOfDay(for: date)
            let amount = BuxChartMotion.scaled(amountByDay[dayStart] ?? 0, progress: progress)
            return (BuxDisplayDate.shortWeekday(from: date, locale: appSettingsManager.interfaceLocale), amount)
        }
    }

    private func rollingDayLabel(for index: Int) -> String {
        let calendar = Calendar.current
        let today = Date()
        guard let date = calendar.date(byAdding: .day, value: -6 + index, to: today) else {
            return "D\(index + 1)"
        }
        return BuxDisplayDate.shortWeekday(from: date, locale: appSettingsManager.interfaceLocale)
    }

    private func trendContent(progress: Double) -> some View {
        let trendSeries = calendarWeekTrendSeries(progress: progress)

        return VStack(alignment: .leading, spacing: 8) {
            // Interactive header showing details of tap-selected point
            HStack {
                if let selectedIndex = selectedTrendPointIndex, selectedIndex < trendSeries.count {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(trendSeries[selectedIndex].day)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.gray)
                        Text(formatAmount(Decimal(trendSeries[selectedIndex].amount)))
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(themeManager.current.accentColor)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 1) {
                        BuxCatalogText.text("7-day trend")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.gray)
                        BuxCatalogText.text("Tap trend to inspect peaks")
                            .font(.system(size: 10))
                            .foregroundColor(.gray.opacity(0.8))
                    }
                }
                
                Spacer()
                
                // Show category breakdown donut on Trend mode top-right
                if !summary.categoryBreakdown.isEmpty {
                    MiniCategoryDonutChart(
                        breakdown: summary.categoryBreakdown,
                        customCategories: customCategories,
                        progress: progress
                    )
                    .frame(width: 28, height: 28)
                }
            }
            .padding(.horizontal, 2)

            // Large beautifully rendered Area + Line trend chart
            if !trendSeries.isEmpty {
                Chart {
                    ForEach(Array(trendSeries.enumerated()), id: \.offset) { index, item in
                        AreaMark(
                            x: .value("Day", item.day),
                            y: .value("Amount", item.amount)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    themeManager.current.accentColor.opacity(0.24),
                                    themeManager.current.accentColor.opacity(0.04),
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                        LineMark(
                            x: .value("Day", item.day),
                            y: .value("Amount", item.amount)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(themeManager.current.accentColor)
                        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))

                        if let selectedIndex = selectedTrendPointIndex, selectedIndex == index {
                            RuleMark(
                                x: .value("Day", item.day)
                            )
                            .foregroundStyle(themeManager.current.accentColor.opacity(0.35))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))

                            PointMark(
                                x: .value("Day", item.day),
                                y: .value("Amount", item.amount)
                            )
                            .foregroundStyle(themeManager.current.accentColor)
                            .symbolSize(70)
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
                            .foregroundStyle(Color.gray.opacity(0.2))
                        AxisValueLabel()
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(Color.gray)
                    }
                }
                .chartYAxis(.hidden)
                .chartPlotStyle { plotArea in
                    plotArea.padding(.vertical, 6).padding(.horizontal, 2)
                }
                .frame(height: 72)
                .overlay {
                    GeometryReader { geo in
                        HStack(spacing: 0) {
                            ForEach(0..<trendSeries.count, id: \.self) { index in
                                Color.clear
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        let impact = UIImpactFeedbackGenerator(style: .light)
                                        impact.impactOccurred()
                                        withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                                            if selectedTrendPointIndex == index {
                                                selectedTrendPointIndex = nil
                                            } else {
                                                selectedTrendPointIndex = index
                                            }
                                        }
                                    }
                            }
                        }
                    }
                }
            } else {
                Spacer()
                BuxCatalogText.text("No recent transaction trend data available.")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer()
            }

            // Bottom row containing micro insight and change badge
            HStack(alignment: .center, spacing: 8) {
                if let insight = header.microInsight {
                    InlineInsightView(text: insight)
                }
                Spacer(minLength: 4)
                monthChangeBadge
            }
        }
    }

    private func profileContent(progress: Double) -> some View {
        let dailyAverage = header.totalSpent / Double(max(1, header.periodElapsedDays))
        
        return HStack(spacing: 12) {
            // Stats column
            VStack(alignment: .leading, spacing: 12) {
                // Daily average card
                VStack(alignment: .leading, spacing: 4) {
                    BuxCatalogText.text("Daily average")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.gray)
                    
                    Text(formatAmount(Decimal(dailyAverage)))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                    
                    // Simple interactive bar indicator
                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(themeManager.current.accentColor.opacity(0.15))
                            .frame(width: geo.size.width)
                            .overlay(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(themeManager.current.accentColor)
                                    .frame(width: geo.size.width * CGFloat(progress))
                            }
                    }
                    .frame(height: 4)
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(colorScheme == .dark ? Color.white.opacity(0.03) : Color.black.opacity(0.015))
                )
                
                // Transactions logged card
                HStack(spacing: 8) {
                    Image(systemName: "creditcard.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(themeManager.current.accentColor)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        BuxCatalogText.text("Transactions")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.gray)
                        Text("\(header.monthlyTransactionCount)")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(colorScheme == .dark ? Color.white.opacity(0.03) : Color.black.opacity(0.015))
                )
            }
            .frame(maxWidth: .infinity)
            
            // Spotlight column
            VStack(alignment: .leading, spacing: 10) {
                BuxCatalogText.text("Top outflows")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.gray)
                
                VStack(spacing: 8) {
                    if let category = header.biggestCategory {
                        HStack(spacing: 8) {
                            Image(systemName: "tag.fill")
                                .font(.system(size: 10))
                                .foregroundColor(themeManager.current.accentColor)
                                .padding(6)
                                .background(themeManager.current.accentColor.opacity(0.12))
                                .clipShape(Circle())
                            
                            VStack(alignment: .leading, spacing: 2) {
                                BuxCatalogText.text("Top Category")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.gray)
                                Text(category)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                                    .lineLimit(1)
                            }
                            Spacer()
                        }
                    } else {
                        HStack(spacing: 8) {
                            Image(systemName: "tag")
                                .font(.system(size: 10))
                                .foregroundColor(.gray)
                                .padding(6)
                                .background(Color.gray.opacity(0.1))
                                .clipShape(Circle())
                            
                            VStack(alignment: .leading, spacing: 2) {
                                BuxCatalogText.text("Top Category")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.gray)
                                BuxCatalogText.text("None yet")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                        }
                    }
                    
                    if let merchant = header.biggestMerchant {
                        HStack(spacing: 8) {
                            Image(systemName: "storefront.fill")
                                .font(.system(size: 10))
                                .foregroundColor(themeManager.current.accentColor)
                                .padding(6)
                                .background(themeManager.current.accentColor.opacity(0.12))
                                .clipShape(Circle())
                            
                            VStack(alignment: .leading, spacing: 2) {
                                BuxCatalogText.text("Top Merchant")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.gray)
                                Text(merchant)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                                    .lineLimit(1)
                            }
                            Spacer()
                        }
                    } else {
                        HStack(spacing: 8) {
                            Image(systemName: "storefront")
                                .font(.system(size: 10))
                                .foregroundColor(.gray)
                                .padding(6)
                                .background(Color.gray.opacity(0.1))
                                .clipShape(Circle())
                            
                            VStack(alignment: .leading, spacing: 2) {
                                BuxCatalogText.text("Top Merchant")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.gray)
                                BuxCatalogText.text("None yet")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                        }
                    }
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(colorScheme == .dark ? Color.white.opacity(0.04) : Color.black.opacity(0.02))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            themeManager.current.accentColor.opacity(0.15),
                                            Color.clear
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 0.5
                                )
                        }
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 4)
    }

    private var monthChangeBadge: some View {
        let isUp = header.changeVsLastMonth > 0
        let isDown = header.changeVsLastMonth < 0
        let tint: Color = isUp
            ? BuxChartColors.comparisonUp
            : (isDown ? BuxChartColors.comparisonDown : .gray)

        return VStack(alignment: .trailing, spacing: 2) {
            BuxCatalogText.text("Vs last period")
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
    var onOpenSpendingTrends: (() -> Void)? = nil

    static func == (lhs: ExpensesHeroCarouselHost, rhs: ExpensesHeroCarouselHost) -> Bool {
        lhs.playRequest == rhs.playRequest &&
        lhs.header.totalSpent == rhs.header.totalSpent &&
        lhs.header.totalIncome == rhs.header.totalIncome &&
        lhs.header.changeVsLastMonth == rhs.header.changeVsLastMonth &&
        lhs.header.monthlyTransactionCount == rhs.header.monthlyTransactionCount &&
        lhs.header.biggestCategory == rhs.header.biggestCategory &&
        lhs.header.biggestMerchant == rhs.header.biggestMerchant &&
        lhs.header.sparklinePoints == rhs.header.sparklinePoints &&
        lhs.header.microInsight == rhs.header.microInsight &&
        lhs.header.periodRangeSubtitle == rhs.header.periodRangeSubtitle &&
        lhs.header.periodElapsedDays == rhs.header.periodElapsedDays &&
        lhs.summary.totalSpent == rhs.summary.totalSpent &&
        lhs.summary.changeVsLastMonth == rhs.summary.changeVsLastMonth &&
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
            session: session,
            onOpenSpendingTrends: onOpenSpendingTrends
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
