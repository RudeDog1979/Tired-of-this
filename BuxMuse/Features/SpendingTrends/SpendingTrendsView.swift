//
//  SpendingTrendsView.swift
//  BuxMuse
//
//  Full-screen spending analytics — opened from Expenses hero.
//

import SwiftUI

struct SpendingTrendsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @EnvironmentObject private var brain: BuxMuseBrain

    var initialMonthStart: Date?

    @StateObject private var store = SpendingTrendsStore()
    @ObservedObject private var animationSession = SpendingTrendsAnimationSession.shared
    @State private var breakdownMode: SpendingTrendsBreakdownMode = .category
    @State private var customCategories: [ExpenseCategoryRecord] = []
    @State private var drillContext: SpendingTrendsDrillContext?
    @State private var pagerAnchorId: String?

    private var locale: Locale { appSettingsManager.interfaceLocale }
    private var calendar: Calendar {
        BuxBudgetPeriodCalculator.calendar(weekStartDay: SettingsStore.shared.weekStartDay)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                BuxLandingTintBackground()
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    periodPicker
                        .padding(.top, BuxTokens.tight)
                        .padding(.bottom, 12)
                        .buxPadExpenseDetailScrollLayout()

                    periodPager
                }
            }
            .buxCatalogNavigationTitle("Spending Analysis")
            .navigationBarTitleDisplayMode(.inline)
            .buxInterfaceLocale()
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    BuxToolbarCancelButton { dismiss() }
                }
            }
            .buxDetailNavigationChrome()
            .navigationDestination(item: $drillContext) { context in
                Group {
                    if context.isMerchantDrill {
                        SpendingTrendsMerchantDetailView(context: context)
                    } else {
                        SpendingTrendsDrillDownView(context: context)
                    }
                }
                .environmentObject(themeManager)
                .environmentObject(appSettingsManager)
                .environmentObject(brain)
            }
            .task {
                customCategories = ((try? brain.fetchAllCategoryRecords()) ?? []).filter(\.isCustom)
                await store.bootstrap(
                    brain: brain,
                    locale: locale,
                    initialMonthStart: initialMonthStart
                )
                pagerAnchorId = store.selectedAnchorId
                if let anchorId = store.selectedAnchorId {
                    playChartEntranceIfNeeded(for: anchorId)
                }
            }
            .onChange(of: brain.expenseDataRevision) { _, _ in
                store.scheduleDataRefresh(brain: brain, locale: locale)
            }
        }
    }

    private var periodPicker: some View {
        Picker("", selection: Binding(
            get: { store.period },
            set: { newPeriod in
                Task {
                    await store.setPeriod(newPeriod, brain: brain, locale: locale)
                    pagerAnchorId = store.selectedAnchorId
                    if let anchorId = store.selectedAnchorId {
                        playChartEntranceIfNeeded(for: anchorId)
                    }
                }
            }
        )) {
            ForEach(SpendingTrendsPeriod.allCases) { period in
                Text(period.catalogTitle(locale: locale)).tag(period)
            }
        }
        .pickerStyle(.segmented)
    }

    @ViewBuilder
    private var periodPager: some View {
        if store.anchors.count > 1 {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 0) {
                    ForEach(store.anchors) { anchor in
                        periodPage(for: anchor)
                            .containerRelativeFrame(.horizontal)
                            .id(anchor.id)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
            .defaultScrollAnchor(.trailing)
            .scrollPosition(id: $pagerAnchorId, anchor: .trailing)
            .scrollClipDisabled()
            .onChange(of: pagerAnchorId) { _, newId in
                guard let newId else { return }
                store.selectAnchor(newId, brain: brain, locale: locale)
                playChartEntranceIfNeeded(for: newId)
            }
        } else if let anchor = store.selectedAnchor {
            periodPage(for: anchor)
        }
    }

    private func periodPage(for anchor: SpendingTrendsAnchor) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                SpendingTrendsPeriodPage(
                    anchor: anchor,
                    display: store.displays[anchor.id] ?? SpendingTrendsDisplay.shell(
                        for: anchor,
                        locale: locale,
                        calendar: calendar
                    ),
                    breakdownMode: $breakdownMode,
                    customCategories: customCategories,
                    chartProgress: animationSession.progress(for: anchor.id),
                    formatAmount: { appSettingsManager.format($0) },
                    locale: locale,
                    onSelectBucket: { bucket in
                        drillContext = SpendingTrendsDrillContext(
                            id: bucket.id,
                            title: bucket.label,
                            start: bucket.start,
                            end: bucket.end,
                            period: anchor.period,
                            categoryName: nil,
                            merchantName: nil
                        )
                    },
                    onSelectRow: { row in
                        guard let display = store.displays[anchor.id] else { return }
                        drillContext = SpendingTrendsDrillContext(
                            id: "\(display.anchor.id)-\(breakdownMode.rawValue)-\(row.id)",
                            title: row.name,
                            start: display.anchor.start,
                            end: display.anchor.end,
                            period: display.anchor.period,
                            categoryName: breakdownMode == .category ? row.name : nil,
                            merchantName: breakdownMode == .merchant ? row.name : nil
                        )
                    }
                )
                .equatable()
            }
            .padding(.top, BuxTokens.tight)
            .padding(.bottom, BuxOverlayMetrics.scrollBottomInset)
            .buxPadExpenseDetailScrollLayout()
            .animation(nil, value: store.displays[anchor.id])
        }
        .scrollDismissesKeyboard(.interactively)
        .buxDetailScrollChrome()
        .buxPadExpenseDetailScrollSurface()
        .task(id: anchor.id) {
            await store.loadDisplay(for: anchor, brain: brain, locale: locale, force: false)
        }
    }

    private func playChartEntranceIfNeeded(for anchorId: String) {
        guard animationSession.shouldAnimate(anchorId) else { return }
        animationSession.requestEntrance(for: anchorId)
        if BuxMotion.reducedMotion {
            animationSession.finishEntrance(for: anchorId)
            return
        }
        withAnimation(BuxChartMotion.entrance) {
            animationSession.commitProgress(1, for: anchorId)
        }
    }
}

// MARK: - Stable period page

private struct SpendingTrendsPeriodPage: View, Equatable {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager

    let anchor: SpendingTrendsAnchor
    let display: SpendingTrendsDisplay
    @Binding var breakdownMode: SpendingTrendsBreakdownMode
    let customCategories: [ExpenseCategoryRecord]
    let chartProgress: Double
    let formatAmount: (Decimal) -> String
    let locale: Locale
    let onSelectBucket: (SpendingTrendBarBucket) -> Void
    let onSelectRow: (SpendingTrendBreakdownRow) -> Void

    static func == (lhs: SpendingTrendsPeriodPage, rhs: SpendingTrendsPeriodPage) -> Bool {
        lhs.anchor == rhs.anchor &&
        lhs.display == rhs.display &&
        lhs.breakdownMode == rhs.breakdownMode &&
        lhs.chartProgress == rhs.chartProgress &&
        lhs.customCategories.map(\.id) == rhs.customCategories.map(\.id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            heroCard
            chartSection
            breakdownPicker
            breakdownSection
        }
    }

    private var breakdownPicker: some View {
        Picker("", selection: $breakdownMode) {
            ForEach(SpendingTrendsBreakdownMode.allCases) { mode in
                Text(mode.catalogTitle(locale: locale)).tag(mode)
            }
        }
        .pickerStyle(.segmented)
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(display.title)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(themeManager.labelPrimary(for: colorScheme))

            BuxCatalogDynamicText(key: "Total Spending")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(formatAmount(Decimal(display.totalSpent)))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(themeManager.labelPrimary(for: colorScheme))

                if display.changeAmount != 0 {
                    Image(systemName: display.changeAmount > 0 ? "arrow.up.right.circle.fill" : "arrow.down.right.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(display.changeAmount > 0 ? BuxChartColors.comparisonUp : BuxChartColors.comparisonDown)
                }
            }

            if !display.comparisonCopy.isEmpty || display.changeAmount != 0 {
                Text(comparisonDetail)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .expensesThemedCardChrome(cornerRadius: 24)
    }

    private var comparisonDetail: String {
        let formatted = formatAmount(Decimal(abs(display.changeAmount)))
        if abs(display.changeAmount) < 0.005 {
            return display.comparisonCopy
        }
        if display.changeAmount > 0 {
            return BuxLocalizedString.format(
                "You spent %@ more than the previous period.",
                locale: locale,
                formatted
            )
        }
        return BuxLocalizedString.format(
            "You spent %@ less than the previous period.",
            locale: locale,
            formatted
        )
    }

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SpendingTrendBarChart(
                buckets: display.barBuckets,
                progress: chartProgress,
                onSelectBucket: onSelectBucket
            )
        }
        .padding(16)
        .expensesThemedCardChrome(cornerRadius: 24)
    }

    @ViewBuilder
    private var breakdownSection: some View {
        let rows = breakdownMode == .category ? display.categoryRows : display.merchantRows
        if rows.isEmpty {
            if !display.isEmptyShell {
                BuxCatalogDynamicText(key: "No spending in this period.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            SpendingTrendsBreakdownList(
                mode: breakdownMode,
                rows: rows,
                customCategories: customCategories,
                formatAmount: formatAmount,
                onSelectRow: onSelectRow
            )
        }
    }
}
