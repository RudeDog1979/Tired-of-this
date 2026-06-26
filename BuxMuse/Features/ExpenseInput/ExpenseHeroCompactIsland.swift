//
//  ExpenseHeroCompactIsland.swift
//  BuxMuse
//
//  iPhone — compact “dynamic island” pill when the expense hero collapses on scroll.
//

import SwiftUI

enum ExpenseHeroIslandLayout {
    static let collapseDistance: CGFloat = 120
    static let islandHeight: CGFloat = 52

    /// Extra air between hero inset and first list row.
    static let listBelowHeroSpacing: CGFloat = 8

    /// Pill nudge toward the nav title when fully collapsed.
    static let pillRaiseWhenCollapsed: CGFloat = -12

    /// Hero stops rendering above this progress — keeps charts off the GPU during collapse.
    static let heroCullProgress: CGFloat = 0.9

    /// Pinned top inset height — must match `iphoneExpenseHeroIsland` outer layout.
    static var expandedIslandSlotHeight: CGFloat {
        let carouselCore = BuxLayout.expenseHeroSummaryHeight + 16 + BuxLayout.expenseHeroShadowBleed
        let pageDotsBand: CGFloat = 28
        return BuxTokens.tight
            + BuxLayout.tight
            + carouselCore
            + pageDotsBand
            + BuxLayout.expenseHeroShadowBleed
            + 16
    }

    /// Reserved slot in the scroll so list position stays stable while the hero is overlaid.
    static var heroReservedHeight: CGFloat {
        expandedIslandSlotHeight
    }

    /// iPhone landscape — nav search drawer + expense scope chips sit above pinned hero.
    static let landscapePhoneSearchDrawerClearance: CGFloat = 88

    static func heroReservedHeight(landscapePhone: Bool) -> CGFloat {
        expandedIslandSlotHeight + (landscapePhone ? landscapePhoneSearchDrawerClearance : 0)
    }

    static func heroOverlayHeight(landscapePhone: Bool) -> CGFloat {
        heroReservedHeight(landscapePhone: landscapePhone)
    }
}

struct ExpenseHeroCompactIsland: View, Equatable {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    let header: ExpensesHeaderDisplay
    let summary: ExpensesSummaryDisplay
    let formatAmount: (Decimal) -> String
    let activePageIndex: Int
    let pageCount: Int
    let onTap: () -> Void

    static func == (lhs: ExpenseHeroCompactIsland, rhs: ExpenseHeroCompactIsland) -> Bool {
        lhs.header.totalSpent == rhs.header.totalSpent &&
        lhs.header.totalIncome == rhs.header.totalIncome &&
        lhs.header.changeVsLastMonth == rhs.header.changeVsLastMonth &&
        lhs.summary.totalSpent == rhs.summary.totalSpent &&
        lhs.summary.categoryBreakdown.map { $0.0 } == rhs.summary.categoryBreakdown.map { $0.0 } &&
        lhs.activePageIndex == rhs.activePageIndex &&
        lhs.pageCount == rhs.pageCount
    }

    private var isMonthlyPage: Bool {
        pageCount > 1 && activePageIndex == pageCount - 1
    }

    private var primaryAmount: String {
        if isMonthlyPage {
            return ExpenseDisplayL10n.signedOutflow(
                amount: summary.totalSpent,
                currency: appSettingsManager.selectedCurrency
            )
        }
        return ExpenseDisplayL10n.signedOutflow(
            amount: header.totalSpent,
            currency: appSettingsManager.selectedCurrency
        )
    }

    private var incomeCaption: String? {
        guard !isMonthlyPage, header.totalIncome > 0 else { return nil }
        return ExpenseDisplayL10n.signedInflow(
            amount: header.totalIncome,
            currency: appSettingsManager.selectedCurrency
        )
    }

    private var subtitle: String {
        if isMonthlyPage {
            if let top = summary.categoryBreakdown.first?.0 {
                return top
            }
            return BuxLocalizedString.string("Monthly summary", locale: appSettingsManager.interfaceLocale)
        }
        let change = header.changeVsLastMonth
        if change == 0 {
            return BuxLocalizedString.string("On track", locale: appSettingsManager.interfaceLocale)
        }
        let formatted = formatAmount(Decimal(abs(change)))
        return change > 0 ? "+\(formatted) vs last period" : "−\(formatted) vs last period"
    }

    private var trendColor: Color {
        if isMonthlyPage {
            return themeManager.contrastAccentColor(for: colorScheme)
        }
        if header.changeVsLastMonth > 0 { return BuxChartColors.comparisonUp }
        if header.changeVsLastMonth < 0 { return BuxChartColors.comparisonDown }
        return themeManager.labelSecondary(for: colorScheme)
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(primaryAmount)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                        .minimumScaleFactor(0.85)

                    Text(subtitle)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(trendColor)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                ZStack {
                    if activePageIndex == 0 {
                        MiniSparklineView(points: header.sparklinePoints, lineColor: themeManager.current.accentColor)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    } else {
                        MiniCategoryBarView(breakdown: summary.categoryBreakdown)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    }
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.82), value: activePageIndex)
                .frame(width: 72, height: 22)
                .padding(.horizontal, 4)

                Spacer(minLength: 0)

                if pageCount > 1 {
                    HStack(spacing: 5) {
                        ForEach(0..<pageCount, id: \.self) { index in
                            Circle()
                                .fill(
                                    index == activePageIndex
                                        ? themeManager.current.accentColor
                                        : themeManager.pillInactiveLabelColor(for: colorScheme).opacity(0.35)
                                )
                                .frame(width: index == activePageIndex ? 6 : 5, height: index == activePageIndex ? 6 : 5)
                        }
                    }
                }

                Image(systemName: "chevron.up")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(themeManager.labelSecondary(for: colorScheme))
            }
            .padding(.horizontal, 16)
            .frame(height: ExpenseHeroIslandLayout.islandHeight)
            .frame(maxWidth: .infinity)
            .background {
                let shape = Capsule(style: .continuous)
                shape
                    .fill(.ultraThinMaterial)
                    .buxMaterialColorSchemeAdaptive(shape: shape, colorScheme: colorScheme)
                    .overlay {
                        Capsule(style: .continuous)
                            .strokeBorder(
                                themeManager.themedCardStroke(for: colorScheme).opacity(colorScheme == .dark ? 0.55 : 0.85),
                                lineWidth: 0.75
                            )
                    }
                    .overlay {
                        if SettingsStore.shared.showsLandingCardShine {
                            Capsule(style: .continuous)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [
                                            themeManager.current.accentColor.opacity(colorScheme == .dark ? 0.22 : 0.14),
                                            themeManager.current.accentColor.opacity(colorScheme == .dark ? 0.09 : 0.06),
                                            themeManager.current.accentColor.opacity(colorScheme == .dark ? 0.03 : 0.02),
                                            Color.clear
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 0.75
                                )
                        }
                    }
                    .shadow(
                        color: themeManager.current.accentColor.opacity(colorScheme == .dark ? 0.18 : 0.1),
                        radius: 10,
                        y: 4
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(BuxCatalogLabel.string("Expense summary", locale: appSettingsManager.interfaceLocale))
        .accessibilityHint("Shows expanded summary at top")
    }
}

// MARK: - iPhone pinned overlay (GPU-friendly collapse)

struct ExpenseHeroIslandOverlay: View {
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @ObservedObject private var expenseCarouselSession = ExpenseCarouselSession.shared

    let scrollOffset: CGFloat
    let header: ExpensesHeaderDisplay
    let summary: ExpensesSummaryDisplay
    let pageCount: Int
    let heroRowInsets: EdgeInsets
    let onExpand: () -> Void
    var onOpenSpendingTrends: (() -> Void)? = nil

    /// iPhone landscape — hero slot covers most of the viewport; overlay must not eat vertical scroll.
    private var isLandscapePhone: Bool {
        verticalSizeClass == .compact
    }

    private var isPillInteractive: Bool {
        progress > 0.55
    }

    private var overlayAcceptsHitTesting: Bool {
        isLandscapePhone ? isPillInteractive : true
    }

    private var heroAcceptsHitTesting: Bool {
        !isLandscapePhone && progress < 0.4
    }

    private var landscapeSearchClearance: CGFloat {
        isLandscapePhone ? ExpenseHeroIslandLayout.landscapePhoneSearchDrawerClearance : 0
    }

    private var progress: CGFloat {
        BuxScrollCollapseMath.progress(
            scrollOffset: scrollOffset,
            distance: ExpenseHeroIslandLayout.collapseDistance
        )
    }

    private var heroOpacity: CGFloat {
        min(1, max(0, 1 - progress / 0.85))
    }

    private var pillOpacity: CGFloat {
        let t = min(1, max(0, (progress - 0.12) / 0.88))
        return pow(t, 1.5)
    }

    private var pillLift: CGFloat {
        let baseLift = progress * ExpenseHeroIslandLayout.pillRaiseWhenCollapsed
        if progress > 0.12 {
            let pillProgress = (progress - 0.12) / 0.88
            let bounceFactor = cos(pillProgress * .pi * 1.2) * (1 - pillProgress)
            return baseLift + bounceFactor * 12.0
        }
        return baseLift + 12.0
    }

    private var pillScaleX: CGFloat {
        if progress > 0.12 {
            let pillProgress = (progress - 0.12) / 0.88
            let bounceFactor = cos(pillProgress * .pi * 1.2) * (1 - pillProgress)
            return 1.0 - bounceFactor * 0.45
        }
        return 0.55
    }

    private var pillScaleY: CGFloat {
        if progress > 0.12 {
            let pillProgress = (progress - 0.12) / 0.88
            let bounceFactor = cos(pillProgress * .pi * 1.2) * (1 - pillProgress)
            return 1.0 + bounceFactor * 0.35
        }
        return 1.35
    }

    var body: some View {
        VStack(spacing: 0) {
            Color.clear
                .frame(height: landscapeSearchClearance)
                .allowsHitTesting(false)

            ZStack(alignment: .top) {
                ExpensesHeroCarouselHost(
                header: header,
                summary: summary,
                formatAmount: { appSettingsManager.format($0) },
                playRequest: expenseCarouselSession.playRequest,
                onOpenSpendingTrends: onOpenSpendingTrends
            )
            .equatable()
            .environmentObject(themeManager)
            .environmentObject(appSettingsManager)
            .environment(\.expenseHeroMatchesListCards, true)
            .scaleEffect(
                x: 1.0 - progress * 0.18,
                y: 1.0 - progress * 0.02 + sin(progress * .pi) * 0.08,
                anchor: .top
            )
            .opacity(heroOpacity)
            .allowsHitTesting(heroAcceptsHitTesting)

            ExpenseHeroCompactIsland(
                header: header,
                summary: summary,
                formatAmount: { appSettingsManager.format($0) },
                activePageIndex: expenseCarouselSession.activePageIndex,
                pageCount: pageCount,
                onTap: onExpand
            )
            .equatable()
            .environmentObject(themeManager)
            .environmentObject(appSettingsManager)
            .scaleEffect(x: pillScaleX, y: pillScaleY, anchor: .top)
            .offset(y: pillLift)
            .opacity(pillOpacity)
            .allowsHitTesting(isPillInteractive)
            }
            .padding(heroRowInsets)
            .padding(.bottom, 16)
            .buxPadExpenseCardRail()
            .padding(.horizontal, BuxLayout.marginHorizontal)
            .padding(.top, BuxTokens.tight)
        }
        .frame(height: ExpenseHeroIslandLayout.heroOverlayHeight(landscapePhone: isLandscapePhone), alignment: .top)
        .allowsHitTesting(overlayAcceptsHitTesting)
        .compositingGroup()
        .clipped()
    }
}

// MARK: - Private Helper Views for Dynamic Island

private struct MiniSparklineView: View {
    let points: [Double]
    let lineColor: Color

    var body: some View {
        if points.count < 2 {
            EmptyView()
        } else {
            GeometryReader { geo in
                let minVal = points.min() ?? 0
                let maxVal = points.max() ?? 1
                let delta = maxVal - minVal == 0 ? 1 : maxVal - minVal
                
                Path { path in
                    let stepX = geo.size.width / CGFloat(points.count - 1)
                    for (index, point) in points.enumerated() {
                        let x = CGFloat(index) * stepX
                        let y = geo.size.height - CGFloat((point - minVal) / delta) * geo.size.height
                        
                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(
                    LinearGradient(
                        colors: [lineColor.opacity(0.8), lineColor],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
                )
                .shadow(color: lineColor.opacity(0.4), radius: 2, y: 1)
            }
            .frame(width: 72, height: 16)
        }
    }
}

private struct MiniCategoryBarView: View {
    let breakdown: [(String, Double)]
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        let topThree = Array(breakdown.prefix(3))
        let total = topThree.map { $0.1 }.reduce(0, +)
        
        if total == 0 {
            EmptyView()
        } else {
            GeometryReader { geo in
                HStack(spacing: 1.5) {
                    ForEach(0..<topThree.count, id: \.self) { index in
                        let item = topThree[index]
                        let width = geo.size.width * CGFloat(item.1 / total)
                        let color = segmentColor(index: index)
                        
                        color
                            .frame(width: max(4, width - 1.5))
                    }
                }
            }
            .frame(width: 72, height: 5)
            .clipShape(Capsule(style: .continuous))
            .shadow(color: .black.opacity(0.08), radius: 1, y: 0.5)
        }
    }

    private func segmentColor(index: Int) -> Color {
        switch index {
        case 0: return themeManager.current.accentColor
        case 1: return Color.orange
        case 2: return Color.cyan
        default: return Color.secondary
        }
    }
}
